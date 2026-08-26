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
        try await Task.sleep(for: .milliseconds(700))

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
        try await Task.sleep(for: .milliseconds(600))

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
        try await Task.sleep(for: .milliseconds(700))

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
        try await Task.sleep(for: .milliseconds(700))

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

        try await Task.sleep(for: .milliseconds(700))
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
}
