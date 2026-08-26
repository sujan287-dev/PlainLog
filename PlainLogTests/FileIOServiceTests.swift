import XCTest
@testable import PlainLog

/// Engine-level tests for FileIOService. These use a throwaway folder in the
/// system temp directory (never a user folder) and clean up after themselves.
final class FileIOServiceTests: XCTestCase {

    private var service: FileIOService!
    private var testFolder: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        service = FileIOService()
        testFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlainLogTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: testFolder,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let testFolder {
            try? FileManager.default.removeItem(at: testFolder)
        }
        service = nil
        try super.tearDownWithError()
    }

    // MARK: - Round-trip

    func testWriteThenReadRoundTrip() throws {
        let url = testFolder.appendingPathComponent("2026-08-26.md")
        let text = "# Log\n- [ ] ship sprint 2\n[tag:work]\nEmoji: 📝 café"

        try service.writeText(text, to: url)
        let read = try service.readText(at: url)

        XCTAssertEqual(read, text)
    }

    func testEmptyTextRoundTrip() throws {
        let url = testFolder.appendingPathComponent("2026-08-26.md")
        try service.writeText("", to: url)
        XCTAssertEqual(try service.readText(at: url), "")
    }

    func testOverwriteExistingFile() throws {
        let url = testFolder.appendingPathComponent("2026-08-26.md")
        try service.writeText("first", to: url)
        try service.writeText("second", to: url)
        XCTAssertEqual(try service.readText(at: url), "second")
    }

    // MARK: - Folder hygiene (PLAN.md §11)

    func testWriteCreatesFileAndLeavesNoTempOrHiddenFiles() throws {
        let url = testFolder.appendingPathComponent("2026-08-26.md")
        try service.writeText("hello", to: url)

        // options: [] includes hidden files — we must see ONLY the target.
        let contents = try FileManager.default.contentsOfDirectory(
            at: testFolder,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertEqual(contents.map(\.lastPathComponent), ["2026-08-26.md"])
    }

    // MARK: - Error mapping

    func testReadNonexistentFileThrowsFileNotFound() {
        let url = testFolder.appendingPathComponent("missing.md")
        XCTAssertThrowsError(try service.readText(at: url)) { error in
            XCTAssertEqual(error as? FileIOError, .fileNotFound)
        }
    }

    func testReadNonUTF8FileThrowsEncodingFailed() throws {
        let url = testFolder.appendingPathComponent("bad.md")
        // 0xFF 0xFE is a UTF-16 LE BOM — invalid UTF-8.
        try Data([0xFF, 0xFE, 0x00, 0x01]).write(to: url)

        XCTAssertThrowsError(try service.readText(at: url)) { error in
            XCTAssertEqual(error as? FileIOError, .encodingFailed)
        }
    }

    func testFileExistsReflectsState() throws {
        let url = testFolder.appendingPathComponent("2026-08-26.md")
        XCTAssertFalse(service.fileExists(at: url))
        try service.writeText("hello", to: url)
        XCTAssertTrue(service.fileExists(at: url))
    }

    // MARK: - Daily Filename

    func testDailyFilenameFormat() {
        let date = Date(timeIntervalSince1970: 1724630400) // 2024-08-26 00:00:00 UTC
        let calendar = Calendar(identifier: .gregorian)
        let dailyFilename = DailyFilename(date: date, calendar: calendar)

        // The filename should be YYYY-MM-DD.md in the calendar's timezone.
        // Since we're using UTC epoch, the date is 2024-08-26 in UTC.
        // The actual timezone depends on the test runner's locale, but the format is fixed.
        XCTAssertTrue(dailyFilename.filename.hasSuffix(".md"))
        XCTAssertEqual(dailyFilename.filename.count, 13) // "2024-08-26.md" is 13 chars
    }

    func testDailyFilenameURLInFolder() {
        let date = Date()
        let dailyFilename = DailyFilename(date: date)
        let url = dailyFilename.url(in: testFolder)

        XCTAssertTrue(url.path.hasSuffix(".md"))
        XCTAssertEqual(url.deletingLastPathComponent(), testFolder)
    }

    // MARK: - Open Orchestration

    func testOpenNonexistentFileReturnsPending() {
        let date = Date()
        let state = service.openDailyFile(for: date, in: testFolder)

        XCTAssertEqual(state, .pending)

        // Verify no file was created (pending-new-file policy)
        let dailyFilename = DailyFilename(date: date)
        XCTAssertFalse(service.fileExists(at: dailyFilename.url(in: testFolder)))
    }

    func testOpenExistingFileReturnsLoaded() throws {
        let date = Date()
        let dailyFilename = DailyFilename(date: date)
        let url = dailyFilename.url(in: testFolder)
        let text = "# Log\n- [ ] test"

        try service.writeText(text, to: url)
        let state = service.openDailyFile(for: date, in: testFolder)

        if case .loaded(let loadedText, _) = state {
            XCTAssertEqual(loadedText, text)
        } else {
            XCTFail("Expected .loaded, got \(state)")
        }
    }

    func testOpenEmptyExistingFileReturnsLoadedWithEmptyText() throws {
        let date = Date()
        let dailyFilename = DailyFilename(date: date)
        let url = dailyFilename.url(in: testFolder)

        try service.writeText("", to: url)
        let state = service.openDailyFile(for: date, in: testFolder)

        if case .loaded(let loadedText, _) = state {
            XCTAssertEqual(loadedText, "")
        } else {
            XCTFail("Expected .loaded with empty text, got \(state)")
        }
    }

    func testOpenFileWithDifferentDatesLoadsCorrectFiles() throws {
        let date1 = Date(timeIntervalSince1970: 1724630400) // 2024-08-26
        let date2 = Date(timeIntervalSince1970: 1724716800) // 2024-08-27

        let dailyFilename1 = DailyFilename(date: date1)
        let dailyFilename2 = DailyFilename(date: date2)

        try service.writeText("day 1", to: dailyFilename1.url(in: testFolder))
        try service.writeText("day 2", to: dailyFilename2.url(in: testFolder))

        let state1 = service.openDailyFile(for: date1, in: testFolder)
        let state2 = service.openDailyFile(for: date2, in: testFolder)

        if case .loaded(let text1, _) = state1 {
            XCTAssertEqual(text1, "day 1")
        } else {
            XCTFail("Expected .loaded for date1")
        }

        if case .loaded(let text2, _) = state2 {
            XCTAssertEqual(text2, "day 2")
        } else {
            XCTFail("Expected .loaded for date2")
        }
    }

    // MARK: - External Change Detection

    func testTakeSnapshotReturnsNilForNonexistentFile() {
        let url = testFolder.appendingPathComponent("missing.md")
        let snapshot = service.takeSnapshot(at: url)
        XCTAssertNil(snapshot)
    }

    func testTakeSnapshotCapturesExistingFile() throws {
        let url = testFolder.appendingPathComponent("2026-08-26.md")
        try service.writeText("hello", to: url)

        let snapshot = service.takeSnapshot(at: url)
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.url, url)
        XCTAssertNotNil(snapshot?.modificationDate)
        XCTAssertNotNil(snapshot?.fileSize)
    }

    func testCheckExternalChangeUnchanged() throws {
        let url = testFolder.appendingPathComponent("2026-08-26.md")
        try service.writeText("hello", to: url)

        guard let snapshot = service.takeSnapshot(at: url) else {
            XCTFail("Snapshot should not be nil")
            return
        }

        let result = service.checkExternalChange(at: url, against: snapshot)
        XCTAssertEqual(result, .unchanged)
    }

    func testCheckExternalChangeModified() throws {
        let url = testFolder.appendingPathComponent("2026-08-26.md")
        try service.writeText("hello", to: url)

        guard let snapshot = service.takeSnapshot(at: url) else {
            XCTFail("Snapshot should not be nil")
            return
        }

        // Modify the file externally
        try service.writeText("hello world", to: url)

        let result = service.checkExternalChange(at: url, against: snapshot)
        XCTAssertEqual(result, .modified)
    }

    func testCheckExternalChangeDeleted() throws {
        let url = testFolder.appendingPathComponent("2026-08-26.md")
        try service.writeText("hello", to: url)

        guard let snapshot = service.takeSnapshot(at: url) else {
            XCTFail("Snapshot should not be nil")
            return
        }

        // Delete the file externally
        try FileManager.default.removeItem(at: url)

        let result = service.checkExternalChange(at: url, against: snapshot)
        XCTAssertEqual(result, .deleted)
    }

    func testOpenDailyFileReturnsSnapshotWithLoadedText() throws {
        let date = Date()
        let dailyFilename = DailyFilename(date: date)
        let url = dailyFilename.url(in: testFolder)
        let text = "# Log\n- [ ] test"

        try service.writeText(text, to: url)
        let state = service.openDailyFile(for: date, in: testFolder)

        if case .loaded(let loadedText, let snapshot) = state {
            XCTAssertEqual(loadedText, text)
            XCTAssertNotNil(snapshot)
            XCTAssertEqual(snapshot?.url, url)
        } else {
            XCTFail("Expected .loaded with snapshot, got \(state)")
        }
    }

    func testOpenPendingFileReturnsNilSnapshot() {
        let date = Date()
        let state = service.openDailyFile(for: date, in: testFolder)

        if case .pending = state {
            // Pending files have no snapshot (file doesn't exist)
        } else {
            XCTFail("Expected .pending, got \(state)")
        }
    }

    // MARK: - iCloud State Mapping (pure, fully CI-testable)

    func testMappingNonUbiquitousIsNotICloud() {
        XCTAssertEqual(
            ICloudFileState.mapping(isUbiquitous: false, downloadStatus: nil),
            .notICloud
        )
        // Even if a bogus status is present, non-ubiquitous wins.
        XCTAssertEqual(
            ICloudFileState.mapping(isUbiquitous: false, downloadStatus: .notDownloaded),
            .notICloud
        )
    }

    func testMappingUbiquitousStates() {
        XCTAssertEqual(
            ICloudFileState.mapping(isUbiquitous: true, downloadStatus: .current),
            .localReady
        )
        XCTAssertEqual(
            ICloudFileState.mapping(isUbiquitous: true, downloadStatus: .downloaded),
            .localReady
        )
        XCTAssertEqual(
            ICloudFileState.mapping(isUbiquitous: true, downloadStatus: .notDownloaded),
            .cloudOnly
        )
    }

    func testMappingUbiquitousWithUnreadableStatusIsCloudOnly() {
        // Safety rule: never assume an iCloud item is local unless the system
        // explicitly says so.
        XCTAssertEqual(
            ICloudFileState.mapping(isUbiquitous: true, downloadStatus: nil),
            .cloudOnly
        )
    }

    // MARK: - iCloud State via Service (local-file paths, CI-safe)

    func testICloudStateForLocalFileIsNotICloud() throws {
        let url = testFolder.appendingPathComponent("2026-08-26.md")
        try service.writeText("hello", to: url)
        XCTAssertEqual(service.iCloudState(at: url), .notICloud)
    }

    func testICloudStateForNonexistentLocalFileIsNotICloud() {
        let url = testFolder.appendingPathComponent("missing.md")
        // Fail-open: local folders must never be blocked by state reads.
        XCTAssertEqual(service.iCloudState(at: url), .notICloud)
    }

    func testRequestCloudDownloadOnNonUbiquitousFileThrows() {
        let url = testFolder.appendingPathComponent("missing.md")
        XCTAssertThrowsError(try service.requestCloudDownload(at: url)) { error in
            guard case FileIOError.downloadRequestFailed = error else {
                XCTFail("Expected downloadRequestFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - openDailyFile regression guard

    func testOpenDailyFileStillReturnsPendingForMissingLocalFile() {
        // Guards the Piece 2.4 refactor: local missing files must still be
        // .pending, not .downloading.
        let state = service.openDailyFile(for: Date(), in: testFolder)
        XCTAssertEqual(state, .pending)
    }

    // MARK: - Conflict Copy Naming (pure, fully CI-testable)

    private func utcGregorianCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) throws -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return try XCTUnwrap(utcGregorianCalendar().date(from: comps))
    }

    // MARK: - DailyFilename.dateStamp (Piece 3.2)

    func testDailyFilenameDateStampIsFilenameWithoutExtension() throws {
        let date = try makeDate(year: 2026, month: 8, day: 26, hour: 12, minute: 0)
        let dailyFilename = DailyFilename(date: date)

        // Timezone-independent: dateStamp always equals filename minus ".md".
        XCTAssertTrue(dailyFilename.filename.hasSuffix(".md"))
        XCTAssertEqual(
            dailyFilename.dateStamp,
            String(dailyFilename.filename.dropLast(".md".count))
        )

        // Format guard: YYYY-MM-DD.
        let parts = dailyFilename.dateStamp.split(separator: "-")
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[0].count, 4)
        XCTAssertEqual(parts[1].count, 2)
        XCTAssertEqual(parts[2].count, 2)
    }

    func testCopyNameNoCollision() throws {
        let moment = try makeDate(year: 2026, month: 8, day: 26, hour: 15, minute: 30)
        let name = ConflictCopyNamer.nextCopyName(
            forSaveAt: moment,
            existingNames: [],
            calendar: utcGregorianCalendar()
        )
        XCTAssertEqual(name, "2026-08-26-copy-1530.md")
    }

    func testCopyNameCollisionAppendsCounter() throws {
        let moment = try makeDate(year: 2026, month: 8, day: 26, hour: 15, minute: 30)
        let name = ConflictCopyNamer.nextCopyName(
            forSaveAt: moment,
            existingNames: ["2026-08-26-copy-1530.md"],
            calendar: utcGregorianCalendar()
        )
        XCTAssertEqual(name, "2026-08-26-copy-1530-2.md")
    }

    func testCopyNameMultipleCollisions() throws {
        let moment = try makeDate(year: 2026, month: 8, day: 26, hour: 15, minute: 30)
        let name = ConflictCopyNamer.nextCopyName(
            forSaveAt: moment,
            existingNames: [
                "2026-08-26-copy-1530.md",
                "2026-08-26-copy-1530-2.md",
                "2026-08-26-copy-1530-3.md"
            ],
            calendar: utcGregorianCalendar()
        )
        XCTAssertEqual(name, "2026-08-26-copy-1530-4.md")
    }

    func testCopyNameZeroPadsTime() throws {
        let moment = try makeDate(year: 2026, month: 8, day: 26, hour: 9, minute: 5)
        let name = ConflictCopyNamer.nextCopyName(
            forSaveAt: moment,
            existingNames: [],
            calendar: utcGregorianCalendar()
        )
        XCTAssertEqual(name, "2026-08-26-copy-0905.md")
    }

    // MARK: - saveAsCopy (service-level)

    func testSaveAsCopyCreatesFileAndReturnsURL() throws {
        let moment = try makeDate(year: 2026, month: 8, day: 26, hour: 15, minute: 30)
        let text = "copied content"
        let url = try service.saveAsCopy(
            text: text,
            forSaveAt: moment,
            in: testFolder,
            calendar: utcGregorianCalendar()
        )
        XCTAssertEqual(url.lastPathComponent, "2026-08-26-copy-1530.md")
        XCTAssertEqual(try service.readText(at: url), text)
    }

    func testSaveAsCopyAvoidsExistingCopy() throws {
        let moment = try makeDate(year: 2026, month: 8, day: 26, hour: 15, minute: 30)
        // Pre-create the primary copy name so the namer must pick -2.
        let primary = testFolder.appendingPathComponent("2026-08-26-copy-1530.md")
        try service.writeText("existing", to: primary)

        let url = try service.saveAsCopy(
            text: "new copy",
            forSaveAt: moment,
            in: testFolder,
            calendar: utcGregorianCalendar()
        )
        XCTAssertEqual(url.lastPathComponent, "2026-08-26-copy-1530-2.md")
        // Original untouched.
        XCTAssertEqual(try service.readText(at: primary), "existing")
    }

    func testSaveAsCopyReservesICloudPlaceholderNames() throws {
        let moment = try makeDate(year: 2026, month: 8, day: 26, hour: 15, minute: 30)
        // Simulate an evicted iCloud copy placeholder.
        let placeholder = testFolder.appendingPathComponent("2026-08-26-copy-1530.md.icloud")
        try Data("placeholder".utf8).write(to: placeholder)

        let url = try service.saveAsCopy(
            text: "new copy",
            forSaveAt: moment,
            in: testFolder,
            calendar: utcGregorianCalendar()
        )
        // Base name is reserved by the placeholder, so namer picks -2.
        XCTAssertEqual(url.lastPathComponent, "2026-08-26-copy-1530-2.md")
    }

    func testSaveAsCopyLeavesNoTempFiles() throws {
        let moment = try makeDate(year: 2026, month: 8, day: 26, hour: 15, minute: 30)
        _ = try service.saveAsCopy(
            text: "x",
            forSaveAt: moment,
            in: testFolder,
            calendar: utcGregorianCalendar()
        )
        let contents = try FileManager.default.contentsOfDirectory(
            at: testFolder,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertEqual(contents.map(\.lastPathComponent).sorted(), ["2026-08-26-copy-1530.md"])
    }
}
