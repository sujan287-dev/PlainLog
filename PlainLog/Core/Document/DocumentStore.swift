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

        case .pending:
            // Feature 03: show the empty editor, do NOT create the file yet.
            currentText = ""
            loadedSnapshot = nil
            isPendingNewFile = true
            isDirty = false
            saveState = .idle

        case .downloading, .downloadFailed, .loadFailed:
            currentText = ""
            loadedSnapshot = nil
            isPendingNewFile = false
            isDirty = false
            saveState = .idle
        }
    }

    // MARK: - Editing

    /// Called by the editor whenever text changes. Marks the document dirty.
    /// Autosave debouncing is owned by the integration layer (Piece 3.3),
    /// not by this method.
    func updateText(_ newText: String) {
        guard newText != currentText else { return }
        currentText = newText
        isDirty = true
    }
}
