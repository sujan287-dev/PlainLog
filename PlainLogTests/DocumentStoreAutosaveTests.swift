import XCTest
@testable import PlainLog

/// Sprint 3 · Piece 3.3 — Autosave and pending-file policy tests.
/// @MainActor is REQUIRED: DocumentStore is @MainActor-isolated.
@MainActor
final class DocumentStoreAutosaveTests: XCTestCase {

    private var store: DocumentStore!
    private var fileIO: FileIOService!
    private var testFolder: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileIO = FileIOService()
        store = DocumentStore(fileIO: fileIO)
        testFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "PlainLogAutosaveTests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: testFolder,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let testFolder {
            try? FileManager.default.removeItem(at: testFolder)
        }
        store = nil
        fileIO = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return try XCTUnwrap(calendar.date(from: comps))
    }

    // MARK: - Autosave debounce

    func testAutosaveFiresAfter500msIdle() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText("initial", to: url)

        await store.load(date: date, in: testFolder)
        store.updateText("modified")

        // File should not exist yet (debounce hasn't fired).
        let contentsBefore = try FileManager.default.contentsOfDirectory(
            at: testFolder,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertEqual(contentsBefore.count, 1)
        XCTAssertEqual(try fileIO.readText(at: url), "initial")

        // Wait for debounce + save.
        try await Task.sleep(for: .milliseconds(1000))

        let contentsAfter = try FileManager.default.contentsOfDirectory(
            at: testFolder,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertEqual(contentsAfter.count, 1)
        XCTAssertEqual(try fileIO.readText(at: url), "modified")
        XCTAssertEqual(store.saveState, .saved)
        XCTAssertFalse(store.isDirty)
    }

    func testRapidTypingCancelsPreviousDebounce() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText("initial", to: url)

        await store.load(date: date, in: testFolder)

        // Type rapidly, each keystroke within 200ms of the previous.
        for i in 0..<5 {
            store.updateText("edit \(i)")
            try await Task.sleep(for: .milliseconds(200))
        }

        // After 5 rapid edits (1000ms total), the file should still be unchanged
        // because the debounce kept resetting.
        XCTAssertEqual(try fileIO.readText(at: url), "initial")

        // Now wait for the final debounce to fire.
        try await Task.sleep(for: .milliseconds(900))

        XCTAssertEqual(try fileIO.readText(at: url), "edit 4")
        XCTAssertEqual(store.saveState, .saved)
    }

    // MARK: - Pending-file policy (Feature 03)

    func testEmptyPendingFileIsNeverSaved() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)

        // Type only whitespace (not meaningful).
        store.updateText("   \n\t  ")
        XCTAssertTrue(store.isPendingNewFile)
        XCTAssertFalse(store.hasMeaningfulContent)

        // Wait for debounce.
        try await Task.sleep(for: .milliseconds(1000))

        // File should NOT be created (Feature 03 pending-file policy).
        let contents = try FileManager.default.contentsOfDirectory(
            at: testFolder,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertEqual(contents.count, 0)
        XCTAssertEqual(store.saveState, .idle)
    }

    func testMeaningfulPendingFileIsCreatedOnAutosave() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)

        // Type meaningful content.
        store.updateText("# Log\n- [ ] task")
        XCTAssertTrue(store.isPendingNewFile)
        XCTAssertTrue(store.hasMeaningfulContent)

        // Wait for debounce.
        try await Task.sleep(for: .milliseconds(1000))

        // File should be created (first meaningful save).
        let contents = try FileManager.default.contentsOfDirectory(
            at: testFolder,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertEqual(contents.count, 1)
        let url = DailyFilename(date: date).url(in: testFolder)
        XCTAssertEqual(try fileIO.readText(at: url), "# Log\n- [ ] task")
        XCTAssertFalse(store.isPendingNewFile)
        XCTAssertEqual(store.saveState, .saved)
    }

    // MARK: - saveNow

    func testSaveNowBypassesDebounce() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText("initial", to: url)

        await store.load(date: date, in: testFolder)
        store.updateText("modified")

        // saveNow should save immediately, not wait 500ms.
        await store.saveNow()

        XCTAssertEqual(try fileIO.readText(at: url), "modified")
        XCTAssertEqual(store.saveState, .saved)
        XCTAssertFalse(store.isDirty)
    }

    // MARK: - Dirty tracking

    func testDirtyTrackingResetsAfterSave() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText("initial", to: url)

        await store.load(date: date, in: testFolder)
        XCTAssertFalse(store.isDirty)

        store.updateText("modified")
        XCTAssertTrue(store.isDirty)

        try await Task.sleep(for: .milliseconds(1000))
        XCTAssertFalse(store.isDirty)
    }

    func testEditingBackToOriginalClearsDirty() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText("original", to: url)

        await store.load(date: date, in: testFolder)
        store.updateText("modified")
        XCTAssertTrue(store.isDirty)

        store.updateText("original")
        XCTAssertFalse(store.isDirty)
    }

    // MARK: - saveNow must never create a blank pending file (Feature 03/06)

    func testSaveNowOnEmptyPendingFileDoesNotCreateFile() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)

        await store.saveNow()

        let contents = try FileManager.default.contentsOfDirectory(
            at: testFolder,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertEqual(contents.count, 0)
        XCTAssertEqual(store.saveState, .idle)
    }

    func testSaveNowBeforeLoadCompletesDoesNotCreateBlankFile() async throws {
        // No load() at all: folderURL is nil, so this must fail safely
        // rather than write anywhere, and never crash.
        await store.saveNow()

        let contents = try FileManager.default.contentsOfDirectory(
            at: testFolder,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertEqual(contents.count, 0)
    }

    func testSaveNowOnPendingFileWithMeaningfulContentStillSaves() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)

        store.updateText("# Log\n- [ ] task")
        await store.saveNow()

        let url = DailyFilename(date: date).url(in: testFolder)
        XCTAssertEqual(try fileIO.readText(at: url), "# Log\n- [ ] task")
        XCTAssertFalse(store.isPendingNewFile)
        XCTAssertEqual(store.saveState, .saved)
    }

    /// Bugfix H4 (full-codebase audit): lastSuccessfulSaveTime must be set
    /// on a successful save — FolderHealthView's "Last successful save" row
    /// was a static "—" placeholder because nothing tracked this at all.
    func testSaveNowSetsLastSuccessfulSaveTime() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)
        XCTAssertNil(store.lastSuccessfulSaveTime)

        let beforeSave = Date()
        store.updateText("# Log")
        await store.saveNow()
        let afterSave = Date()

        let saveTime = try XCTUnwrap(store.lastSuccessfulSaveTime)
        XCTAssertGreaterThanOrEqual(saveTime, beforeSave)
        XCTAssertLessThanOrEqual(saveTime, afterSave)
    }

    /// Bugfix regression: a brand-new file's fileState must advance to
    /// .loaded on its first successful save, not stay .pending forever —
    /// EditorView's foreground external-change/conflict/deletion detection
    /// (Feature 08) is gated on `case .loaded = fileState` and was silently
    /// disabled for the common case (today's freshly-created file) before
    /// this fix.
    func testSaveNowOnPendingFileAdvancesFileStateToLoaded() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)
        XCTAssertEqual(store.fileState, .pending)

        store.updateText("# Log\n- [ ] task")
        await store.saveNow()

        guard case .loaded(let text, let snapshot) = store.fileState else {
            XCTFail("Expected fileState to advance to .loaded after the first save, got \(String(describing: store.fileState))")
            return
        }
        XCTAssertEqual(text, "# Log\n- [ ] task")
        XCTAssertNotNil(snapshot)
    }

    func testSaveNowOnExistingFileClearedToEmptyStillSaves() async throws {
        // The blank-file gate must only block creating a NEW file — clearing
        // an EXISTING file to empty is a deliberate user action and must
        // still be allowed to save.
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText("original", to: url)

        await store.load(date: date, in: testFolder)
        store.updateText("")
        await store.saveNow()

        XCTAssertEqual(try fileIO.readText(at: url), "")
        XCTAssertEqual(store.saveState, .saved)
    }

    // MARK: - load() cancels stale autosave (cross-document bleed, Feature 06)

    func testLoadCancelsPendingAutosave() async throws {
        let dateA = try makeDate(year: 2026, month: 8, day: 26)
        let dateB = try makeDate(year: 2026, month: 8, day: 27)

        await store.load(date: dateA, in: testFolder)
        store.updateText("day A text")

        // Switch immediately — no sleep — while the 500ms autosave debounce
        // from the "day A text" edit is still pending.
        await store.load(date: dateB, in: testFolder)

        try await Task.sleep(for: .milliseconds(1000))

        let urlA = DailyFilename(date: dateA).url(in: testFolder)
        let urlB = DailyFilename(date: dateB).url(in: testFolder)

        XCTAssertFalse(
            fileIO.fileExists(at: urlA),
            "Day A was never explicitly saved before switching away; it must not appear on disk."
        )
        XCTAssertFalse(
            fileIO.fileExists(at: urlB),
            "Day B is an empty pending file; the stale day-A autosave must not create it, let alone with day A's text."
        )
    }

    func testLoadAfterDebounceFiredStillConsistent() async throws {
        let dateA = try makeDate(year: 2026, month: 8, day: 26)
        let dateB = try makeDate(year: 2026, month: 8, day: 27)

        await store.load(date: dateA, in: testFolder)
        store.updateText("day A text")

        // Let the autosave actually complete before switching.
        try await Task.sleep(for: .milliseconds(1000))

        let urlA = DailyFilename(date: dateA).url(in: testFolder)
        XCTAssertEqual(try fileIO.readText(at: urlA), "day A text")

        await store.load(date: dateB, in: testFolder)

        let urlB = DailyFilename(date: dateB).url(in: testFolder)
        XCTAssertFalse(fileIO.fileExists(at: urlB))
    }

    // MARK: - performSave serialization (no overlapping writes)

    func testSequentialSaveNowCallsConverge() async throws {
        // Not a true concurrency test (each saveNow() awaits completion
        // before the next starts) — this guards that the isSaving/
        // saveRequestedWhileSaving bookkeeping doesn't regress normal,
        // sequential save usage.
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText("initial", to: url)

        await store.load(date: date, in: testFolder)

        store.updateText("first")
        await store.saveNow()
        store.updateText("second")
        await store.saveNow()

        XCTAssertEqual(try fileIO.readText(at: url), "second")
        XCTAssertEqual(store.saveState, .saved)
        XCTAssertFalse(store.isDirty)
    }
}
