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
}
