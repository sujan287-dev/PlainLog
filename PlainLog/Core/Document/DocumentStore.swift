import Foundation
import Observation

/// DocumentStore — Sprint 3 (PLAN.md §12).
///
/// The editor's state model. Owns the selected date, the current document's
/// text and lifecycle states, and the pending-new-file policy (Feature 03).
///
/// Piece 3.1 scope: state model + load orchestration + text editing.
/// Autosave arrives in Piece 3.3. Date navigation arrives in Sprint 4.
///
/// Threading: @MainActor — all state mutations happen on the main actor.
/// File I/O runs off the main actor via Task.detached, honoring the
/// FileIOService threading contract, and results are applied back here.
@MainActor
@Observable
final class DocumentStore {

    private let fileIO: FileIOService

    // MARK: - Editor state

    /// The date currently being edited.
    private(set) var selectedDate: Date = Date()

    /// The folder the current document lives in (set on load).
    private(set) var folderURL: URL?

    /// Current document text (bound to TextEditor in Piece 3.2).
    private(set) var currentText: String = ""

    /// Result of the last load attempt. nil = no load performed yet.
    private(set) var fileState: DailyFileState?

    /// Save lifecycle (Piece 3.3 drives transitions beyond .idle/.saved).
    private(set) var saveState: SaveState = .idle

    /// True when currentText differs from the last loaded content.
    private(set) var isDirty: Bool = false

    /// True when the document is a pending new file (no file on disk yet).
    /// Feature 03: the file is created only after the first meaningful save.
    private(set) var isPendingNewFile: Bool = false

    /// Snapshot captured at load time (nil while pending or failed).
    /// Consumed by external-change checks in Piece 3.3.
    private(set) var loadedSnapshot: FileSnapshot?

    /// Debounced autosave task. Cancelled and restarted on every updateText call.
    private var autosaveTask: Task<Void, Never>?

    /// The text at the last successful save (used for dirty tracking).
    private var lastSavedText: String = ""

    init(fileIO: FileIOService = FileIOService()) {
        self.fileIO = fileIO
    }

    // MARK: - Derived state

    /// Where the current day's file lives (or will live) on disk.
    var targetFileURL: URL? {
        guard let folderURL else { return nil }
        return DailyFilename(date: selectedDate).url(in: folderURL)
    }

    /// Feature 03 empty-file policy: content is "meaningful" when it contains
    /// at least one character that is not whitespace or a newline.
    var hasMeaningfulContent: Bool {
        !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Large file detection (Feature 04)

    /// Threshold in bytes at or above which a file is considered "large".
    /// 250 KB per PLAN.md Feature 04. Large files show a non-blocking warning.
    static let largeFileThresholdBytes = 250 * 1024

    /// True when the loaded file is at or above the large-file threshold.
    /// Derived from the load-time snapshot. Pending files (no file on disk,
    /// no snapshot) are never large. This is a load-time heuristic; the
    /// warning does not live-update as the user types (v1).
    var isLargeFile: Bool {
        (loadedSnapshot?.fileSize ?? 0) >= Self.largeFileThresholdBytes
    }

    // MARK: - Load

    /// Loads the daily file for `date` in `folder` via FileIOService.
    /// File I/O runs off the main actor; state is applied on the main actor.
    func load(date: Date, in folder: URL) async {
        selectedDate = date
        folderURL = folder
        fileState = nil
        isDirty = false

        let io = fileIO
        let result = await Task.detached(priority: .userInitiated) {
            io.openDailyFile(for: date, in: folder)
        }.value

        applyLoadResult(result)
    }

    private func applyLoadResult(_ result: DailyFileState) {
        fileState = result

        switch result {
        case .loaded(let text, let snapshot):
            currentText = text
            loadedSnapshot = snapshot
            isPendingNewFile = false
            isDirty = false
            saveState = .saved
            lastSavedText = text

        case .pending:
            // Feature 03: show the empty editor, do NOT create the file yet.
            currentText = ""
            loadedSnapshot = nil
            isPendingNewFile = true
            isDirty = false
            saveState = .idle
            lastSavedText = ""

        case .downloading, .downloadFailed, .loadFailed:
            currentText = ""
            loadedSnapshot = nil
            isPendingNewFile = false
            isDirty = false
            saveState = .idle
        }
    }

    // MARK: - Editing

    /// Called by the editor whenever text changes. Marks the document dirty
    /// and restarts the 500ms autosave debounce (Feature 06).
    func updateText(_ newText: String) {
        guard newText != currentText else { return }
        currentText = newText
        isDirty = (currentText != lastSavedText)

        // Restart the autosave debounce.
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await self?.autosave()
        }
    }

    // MARK: - Autosave & Save

    /// Debounced autosave (Feature 06). Called after 500ms of idle typing.
    /// Enforces the pending-file policy (Feature 03): empty pending files
    /// are never created on disk.
    private func autosave() async {
        // Feature 03 pending-file gate: don't save empty pending files.
        if isPendingNewFile && !hasMeaningfulContent {
            saveState = .idle
            return
        }

        // Don't save if nothing changed since last save.
        if currentText == lastSavedText {
            saveState = .saved
            return
        }

        await performSave()
    }

    /// Immediate save, bypassing the debounce. Called on app background,
    /// date switch (Sprint 4), or explicit user action.
    func saveNow() async {
        autosaveTask?.cancel()
        await performSave()
    }

    /// Core save logic. Coordinates with FileIOService, handles errors,
    /// updates SaveState. Called by autosave() and saveNow().
    private func performSave() async {
        guard let folderURL, let targetFileURL else {
            saveState = .saveFailed(reason: "No folder connected")
            return
        }

        saveState = .saving

        let io = fileIO
        let text = currentText
        let url = targetFileURL

        // Explicit closure return type: `.success`/`.failure` shorthand can't
        // be inferred without it, since Task.detached's Success is otherwise
        // unbound at the point the closure body is type-checked.
        let result = await Task.detached(priority: .userInitiated) { () -> Result<Void, FileIOError> in
            do {
                try io.writeText(text, to: url)
                return .success(())
            } catch let error as FileIOError {
                return .failure(error)
            } catch {
                return .failure(.underlying(error.localizedDescription))
            }
        }.value

        switch result {
        case .success:
            // Use `text` (what was actually written), not the live `currentText`
            // property — the user may have kept typing during the write above,
            // so `currentText` can already be newer than what's on disk. Using
            // it here would wrongly mark the newer edit as saved and cause the
            // next debounce cycle to skip saving it, silently losing it.
            lastSavedText = text
            isDirty = (currentText != lastSavedText)
            isPendingNewFile = false
            saveState = .saved
            // Capture a fresh snapshot for external-change detection.
            loadedSnapshot = await Task.detached { io.takeSnapshot(at: url) }.value

        case .failure(let error):
            handleError(error)
        }
    }

    private func handleError(_ error: FileIOError) {
        switch error {
        case .cloudOnlyFileNotDownloaded:
            saveState = .saveFailed(reason: "File is in iCloud and not downloaded")
        case .coordinationFailed(let message):
            saveState = .saveFailed(reason: "Could not access file: \(message)")
        case .underlying(let message):
            saveState = .saveFailed(reason: "File system error: \(message)")
        case .fileNotFound:
            // Edge case: file was deleted between our check and the write.
            saveState = .saveFailed(reason: "File was deleted")
        case .encodingFailed:
            saveState = .saveFailed(reason: "Encoding error")
        case .coordinationDidNotRun:
            saveState = .saveFailed(reason: "File access coordination failed")
        case .downloadRequestFailed(let message):
            saveState = .saveFailed(reason: "iCloud download failed: \(message)")
        }
    }
}
