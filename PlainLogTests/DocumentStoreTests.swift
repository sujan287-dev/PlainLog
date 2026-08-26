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
}
