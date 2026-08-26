import XCTest
@testable import PlainLog

/// Sprint 3 · Piece 3.1 — DocumentStore core tests.
/// @MainActor is REQUIRED: DocumentStore is @MainActor-isolated.
@MainActor
final class DocumentStoreTests: XCTestCase {

    private var store: DocumentStore!
    private var fileIO: FileIOService!
    private var testFolder: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileIO = FileIOService()
        store = DocumentStore(fileIO: fileIO)
        testFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "PlainLogDocStoreTests-\(UUID().uuidString)",
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

    /// Fixed date for deterministic tests. All file URLs are computed via
    /// DailyFilename so assertions never depend on the runner's timezone.
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

    // MARK: - Load: pending new file (Feature 03)

    func testLoadMissingFileEntersPendingState() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)

        await store.load(date: date, in: testFolder)

        XCTAssertEqual(store.fileState, .pending)
        XCTAssertTrue(store.isPendingNewFile)
        XCTAssertEqual(store.currentText, "")
        XCTAssertFalse(store.isDirty)
        XCTAssertNil(store.loadedSnapshot)

        // Feature 03: loading a missing file must NOT create it.
        let contents = try FileManager.default.contentsOfDirectory(
            at: testFolder,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertEqual(contents.count, 0)
    }

    func testEditingPendingFileStillCreatesNothingOnDisk() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)

        store.updateText("# Meaningful content\n- [ ] a task")

        XCTAssertTrue(store.hasMeaningfulContent)
        let contents = try FileManager.default.contentsOfDirectory(
            at: testFolder,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertEqual(contents.count, 0)
    }

    // MARK: - Load: existing files

    func testLoadExistingFileEntersLoadedState() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText("# Log\n- [ ] test", to: url)

        await store.load(date: date, in: testFolder)

        guard case .loaded(let text, let snapshot) = store.fileState else {
            XCTFail("Expected .loaded, got \(String(describing: store.fileState))")
            return
        }
        XCTAssertEqual(text, "# Log\n- [ ] test")
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(store.currentText, "# Log\n- [ ] test")
        XCTAssertNotNil(store.loadedSnapshot)
        XCTAssertFalse(store.isPendingNewFile)
        XCTAssertFalse(store.isDirty)
    }

    func testLoadExistingEmptyFileIsLoadedNotPending() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText("", to: url)

        await store.load(date: date, in: testFolder)

        // Feature 03: "File exists and is empty → Open it." NOT pending.
        guard case .loaded(let text, _) = store.fileState else {
            XCTFail("Expected .loaded, got \(String(describing: store.fileState))")
            return
        }
        XCTAssertEqual(text, "")
        XCTAssertFalse(store.isPendingNewFile)
    }

    func testLoadNonUTF8FileEntersLoadFailedState() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try Data([0xFF, 0xFE, 0x00, 0x01]).write(to: url)

        await store.load(date: date, in: testFolder)

        guard case .loadFailed = store.fileState else {
            XCTFail("Expected .loadFailed, got \(String(describing: store.fileState))")
            return
        }
        XCTAssertTrue(store.currentText.isEmpty)
        XCTAssertFalse(store.isPendingNewFile)
    }

    // MARK: - Editing

    func testUpdateTextMarksDirty() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)

        store.updateText("hello")

        XCTAssertEqual(store.currentText, "hello")
        XCTAssertTrue(store.isDirty)
    }

    func testUpdateTextWithIdenticalTextDoesNotMarkDirty() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText("same", to: url)

        await store.load(date: date, in: testFolder)
        store.updateText("same")

        XCTAssertFalse(store.isDirty)
    }

    // MARK: - Meaningful content policy (Feature 03)

    func testHasMeaningfulContentPolicy() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)

        store.updateText("")
        XCTAssertFalse(store.hasMeaningfulContent)

        store.updateText("   \n\t\n  ")
        XCTAssertFalse(store.hasMeaningfulContent)

        store.updateText("a")
        XCTAssertTrue(store.hasMeaningfulContent)
    }

    // MARK: - Derived state

    func testTargetFileURLMatchesDailyFilename() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)

        XCTAssertEqual(store.targetFileURL, DailyFilename(date: date).url(in: testFolder))
    }

    // MARK: - Large file detection (Feature 04)

    func testSmallFileIsNotLarge() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText("small content", to: url)

        await store.load(date: date, in: testFolder)

        XCTAssertFalse(store.isLargeFile)
    }

    func testLargeFileIsLarge() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        // ~300 KB, clearly above the 250 KB threshold.
        let largeContent = String(repeating: "a", count: 300 * 1024)
        try fileIO.writeText(largeContent, to: url)

        await store.load(date: date, in: testFolder)

        XCTAssertTrue(store.isLargeFile)
    }

    func testPendingFileIsNotLarge() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)

        XCTAssertFalse(store.isLargeFile)
    }

    // MARK: - Summary parsing (Feature 10)

    func testSummaryIsPopulatedOnLoad() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText(
            "- [x] Buy milk\n[tag:home]\n[expense: 12.50 snack]",
            to: url
        )

        await store.load(date: date, in: testFolder)

        let summary = try XCTUnwrap(store.summary)
        XCTAssertEqual(summary.taskTotalCount, 1)
        XCTAssertEqual(summary.taskCompletedCount, 1)
        XCTAssertEqual(summary.tags, ["home"])
        XCTAssertEqual(summary.expenseTotal, try XCTUnwrap(Decimal(string: "12.50")))
    }

    func testSummaryDebounceFiresAfterIdle() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText("- [ ] one task", to: url)

        await store.load(date: date, in: testFolder)
        XCTAssertEqual(store.summary?.taskTotalCount, 1)

        store.updateText("- [ ] one task\n- [x] two task")

        // Synchronous with updateText, no await in between: the 300ms parse
        // debounce has not fired yet, so the summary must still be stale.
        XCTAssertEqual(store.summary?.taskTotalCount, 1)

        try await Task.sleep(for: .milliseconds(650))

        XCTAssertEqual(store.summary?.taskTotalCount, 2)
        XCTAssertEqual(store.summary?.taskCompletedCount, 1)
    }

    func testSummaryDebounceResetsOnRapidTyping() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)
        XCTAssertEqual(store.summary?.taskTotalCount, 0)

        // Type rapidly, each keystroke within 200ms of the previous.
        for i in 0..<5 {
            store.updateText("- [ ] task \(i)")
            try await Task.sleep(for: .milliseconds(200))
        }

        // After 5 rapid edits (1000ms total), the summary should still be the
        // pre-typing baseline because the 300ms debounce kept resetting.
        XCTAssertEqual(store.summary?.taskTotalCount, 0)

        // Now wait for the final debounce to fire.
        try await Task.sleep(for: .milliseconds(650))

        XCTAssertEqual(store.summary?.taskTotalCount, 1)
    }

    func testSummaryForPendingFileIsZeroed() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)

        await store.load(date: date, in: testFolder)

        let summary = try XCTUnwrap(store.summary)
        XCTAssertEqual(summary.taskCompletedCount, 0)
        XCTAssertEqual(summary.taskTotalCount, 0)
        XCTAssertEqual(summary.tags, [])
        XCTAssertEqual(summary.expenseTotal, Decimal.zero)
    }

    // MARK: - Date navigation (Feature 09)

    /// Matches DocumentStore's private navigation calendar exactly (Gregorian
    /// + device local timezone) so day-movement assertions agree with the
    /// implementation regardless of the runner's configured timezone —
    /// deliberately NOT the UTC-fixed calendar makeDate uses, which exists
    /// only to make test *input* dates deterministic.
    private func localCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    func testGoToNextDayMovesForwardOneDay() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)

        let cal = localCalendar()
        let expectedNext = try XCTUnwrap(cal.date(byAdding: .day, value: 1, to: date))

        await store.goToNextDay()

        XCTAssertTrue(cal.isDate(store.selectedDate, inSameDayAs: expectedNext))
        XCTAssertNotEqual(
            DailyFilename(date: store.selectedDate).dateStamp,
            DailyFilename(date: date).dateStamp
        )
    }

    func testGoToPreviousDayMovesBackOneDay() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)

        let cal = localCalendar()
        let expectedPrevious = try XCTUnwrap(cal.date(byAdding: .day, value: -1, to: date))

        await store.goToPreviousDay()

        XCTAssertTrue(cal.isDate(store.selectedDate, inSameDayAs: expectedPrevious))
        XCTAssertNotEqual(
            DailyFilename(date: store.selectedDate).dateStamp,
            DailyFilename(date: date).dateStamp
        )
    }

    func testGoToTodayMovesToCurrentLocalDay() async throws {
        let date = try makeDate(year: 2020, month: 1, day: 1)
        await store.load(date: date, in: testFolder)

        await store.goToToday()

        let cal = localCalendar()
        XCTAssertTrue(cal.isDate(store.selectedDate, inSameDayAs: Date()))
    }

    func testDirtyDocumentIsSavedBeforeSwitchingDay() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        let url = DailyFilename(date: date).url(in: testFolder)
        try fileIO.writeText("original", to: url)

        await store.load(date: date, in: testFolder)
        store.updateText("modified")
        XCTAssertTrue(store.isDirty)

        await store.goToNextDay()

        XCTAssertEqual(try fileIO.readText(at: url), "modified")

        let cal = localCalendar()
        let expectedNext = try XCTUnwrap(cal.date(byAdding: .day, value: 1, to: date))
        XCTAssertTrue(cal.isDate(store.selectedDate, inSameDayAs: expectedNext))
    }

    func testEmptyPendingFileIsDiscardedOnNavigation() async throws {
        let date = try makeDate(year: 2026, month: 8, day: 26)
        await store.load(date: date, in: testFolder)

        store.updateText("   \n\t  ")
        XCTAssertTrue(store.isPendingNewFile)
        XCTAssertFalse(store.hasMeaningfulContent)

        await store.goToNextDay()

        let url = DailyFilename(date: date).url(in: testFolder)
        XCTAssertFalse(fileIO.fileExists(at: url))

        let cal = localCalendar()
        let expectedNext = try XCTUnwrap(cal.date(byAdding: .day, value: 1, to: date))
        XCTAssertTrue(cal.isDate(store.selectedDate, inSameDayAs: expectedNext))
    }

    func testGoToTodayIsNoOpWhenAlreadyToday() async throws {
        let today = Date()
        await store.load(date: today, in: testFolder)
        store.updateText("some text")
        XCTAssertTrue(store.isDirty)
        let originalSelectedDate = store.selectedDate

        await store.goToToday()

        XCTAssertEqual(store.selectedDate, originalSelectedDate)
        XCTAssertTrue(store.isDirty, "A reload would have reset isDirty; it must not have occurred.")
        XCTAssertEqual(store.currentText, "some text")
    }
}
