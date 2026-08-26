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

    /// Debounced parse task (Feature 10). Cancelled and restarted on every
    /// updateText call. Independent of autosaveTask — the two debounces never
    /// share a task variable, so editing never delays saving or vice versa.
    private var parseTask: Task<Void, Never>?

    /// The text at the last successful save (used for dirty tracking).
    private var lastSavedText: String = ""

    /// Live task/tag/expense summary for the Feature 10 summary bar.
    /// nil until the first parse runs (immediately on load, before any typing).
    /// While nil, the summary bar is simply not rendered.
    private(set) var summary: ParsedSummary?

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
        // Cancel both pending debounces from the previous document before
        // this one's state overwrites currentText/folderURL underneath them.
        // A stale autosave that fires after folderURL/selectedDate have
        // already moved on to the new document would capture the OLD text
        // but write to the NEW document's target URL — cross-document bleed.
        parseTask?.cancel()
        autosaveTask?.cancel()

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

        // Feature 10: parse immediately on load (no debounce) so the summary
        // bar is accurate the moment a document opens. currentText is defined
        // in every branch above, so this runs unconditionally.
        reparse()
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

        // Restart the parse debounce (Feature 10). Independent of the
        // autosave debounce above — never shares a task variable with it, so
        // editing never delays saving or vice versa.
        parseTask?.cancel()
        parseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Self.parseDebounceMilliseconds))
            guard !Task.isCancelled else { return }
            self?.reparse()
        }
    }

    // MARK: - Summary parsing (Feature 10)

    /// Debounce interval for re-parsing the summary while typing.
    /// 300ms per PLAN.md Feature 10 ("Parsing is debounced by 300ms").
    private static let parseDebounceMilliseconds = 300

    /// Synchronously re-parses the CURRENT text into `summary`.
    /// Reads `currentText` at call time (not a captured snapshot), so a
    /// debounced call always reflects the latest typing, even if more edits
    /// landed after the timer was scheduled (in which case that timer was
    /// cancelled and replaced before it could fire).
    /// Parsing is small, in-memory, O(n) string work — per the locked design
    /// it stays on the main actor and never hops to Task.detached.
    private func reparse() {
        summary = ParserKit.parseSummary(currentText)
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

    /// True while a save write is physically in flight. Guards against two
    /// overlapping writes to the same file (e.g. an autosave firing the same
    /// instant the app backgrounds and triggers saveNow()) — NSFileCoordinator
    /// wouldn't corrupt the file, but out-of-order completion could leave
    /// stale bookkeeping or, if the target document has since changed
    /// (folder/date switch), write into the wrong file.
    private var isSaving = false

    /// Set when a save is requested while one is already in flight. Drained
    /// by the in-flight save's completion so the request is never silently
    /// dropped — it's picked up with whatever currentText is by then.
    private var saveRequestedWhileSaving = false

    /// Core save logic. Coordinates with FileIOService, handles errors,
    /// updates SaveState. Called by autosave() and saveNow().
    private func performSave() async {
        guard !isSaving else {
            saveRequestedWhileSaving = true
            return
        }
        isSaving = true
        defer {
            isSaving = false
            if saveRequestedWhileSaving {
                saveRequestedWhileSaving = false
                Task { await self.performSave() }
            }
        }

        guard let folderURL, let targetFileURL else {
            saveState = .saveFailed(reason: "No folder connected")
            return
        }

        saveState = .saving

        let io = fileIO
        let text = currentText
        let url = targetFileURL
        let meaningful = hasMeaningfulContent

        // Explicit closure return type: `.success`/`.failure` shorthand can't
        // be inferred without it, since Task.detached's Success is otherwise
        // unbound at the point the closure body is type-checked. `nil` means
        // "correctly skipped, not an error" (see the Feature 03 gate below).
        let result = await Task.detached(priority: .userInitiated) { () -> Result<Void, FileIOError>? in
            // Feature 03: never create a blank file. Checked against the
            // disk here — not the isPendingNewFile flag, which is only
            // accurate once a load has finished applying — so this still
            // holds if saveNow() is called before the initial load
            // completes (folderURL is already set; currentText is still "").
            // Done off the main actor, honoring FileIOService's threading
            // contract, alongside the write itself.
            guard meaningful || io.fileExists(at: url) else {
                return nil
            }
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
        case nil:
            saveState = .idle

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

    // MARK: - Date navigation (Feature 09)

    /// Gregorian calendar bound to the device's local timezone, mirroring
    /// DailyFilename's own construction exactly (Calendar(identifier:
    /// .gregorian) + the local timezone, the same pair DailyFilename ends up
    /// with via its default `calendar: Calendar = .current` argument).
    /// Navigation math must agree with how DailyFilename computes the y/m/d
    /// that becomes the actual filename, or navigation could disagree with
    /// which file a given date represents.
    ///
    /// Computed fresh on every access, never cached: DailyFilename itself
    /// never caches this either, and caching a stale timezone would
    /// misclassify "same day" if the device's timezone changes mid-session
    /// (e.g. travel).
    private static var navigationCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// Navigate to the day before the currently selected date.
    func goToPreviousDay() async {
        guard let target = Self.navigationCalendar.date(byAdding: .day, value: -1, to: selectedDate) else {
            return
        }
        await navigate(to: target)
    }

    /// Navigate to the day after the currently selected date.
    func goToNextDay() async {
        guard let target = Self.navigationCalendar.date(byAdding: .day, value: 1, to: selectedDate) else {
            return
        }
        await navigate(to: target)
    }

    /// Navigate to the start of the current local day.
    func goToToday() async {
        let target = Self.navigationCalendar.startOfDay(for: Date())
        await navigate(to: target)
    }

    /// Navigate to an arbitrary date (used by the history browser).
    /// Reuses all of navigate(to:)'s save-before-switch, pending-file discard,
    /// and dual-task-cancellation machinery.
    func goTo(date target: Date) async {
        await navigate(to: target)
    }

    /// Core save-before-switch logic (Feature 09) shared by all navigation
    /// entry points above.
    private func navigate(to target: Date) async {
        // 1. No-op if already on this local day — do not disturb any
        // in-flight debounce or reload anything.
        if Self.navigationCalendar.isDate(target, inSameDayAs: selectedDate) {
            return
        }

        // 2. Cancel both debounces FIRST: neither must fire against the
        // wrong file once we start moving away from the current document —
        // including during the save-before-switch step below, which can
        // take a moment (async file I/O).
        autosaveTask?.cancel()
        parseTask?.cancel()

        // 3. A folder must be connected to navigate anywhere.
        guard folderURL != nil else { return }

        // 4/5/6. Save-before-switch. Pending-and-empty is checked BEFORE
        // isDirty, matching autosave()'s own gate ordering: a pending file
        // that only ever received whitespace is never worth saving even if
        // isDirty happens to be true.
        if isPendingNewFile && !hasMeaningfulContent {
            // Feature 09: discard silently — do not save, do not create a
            // file — then fall through to load the target date below.
        } else if isDirty {
            await saveNow()
            guard saveState == .saved else {
                // Save failed (or got blocked by the in-flight-save guard);
                // leave the editor on the current date rather than navigate
                // away from unsaved content.
                return
            }
        }
        // else: already clean/saved — nothing to do before switching.

        // 7. Load the target date. folderURL was confirmed non-nil above;
        // load() also re-derives it, so re-read it fresh rather than force-
        // unwrap a captured optional.
        guard let folderURL else { return }
        await load(date: target, in: folderURL)
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
