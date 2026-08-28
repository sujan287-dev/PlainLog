import XCTest
@testable import PlainLog

/// Sprint 5 · Piece 5.8 — Feature 06 (save error) / Feature 07 (iCloud
/// download) copy, verbatim (like Feature08ModalCopyTests / Feature02ModalCopyTests).
final class Feature0607ModalCopyTests: XCTestCase {

    func testSaveErrorCopy() {
        XCTAssertEqual(Feature0607ModalCopy.saveErrorTitle, "PlainLog could not save this file")
        XCTAssertEqual(
            Feature0607ModalCopy.saveErrorBody,
            "Your current edits are still in memory.\nTry saving again or copy your text."
        )
        XCTAssertEqual(Feature0607ModalCopy.saveErrorRetryButton, "Retry")
        XCTAssertEqual(Feature0607ModalCopy.saveErrorCopyTextButton, "Copy current text")
    }

    func testICloudDownloadCopy() {
        XCTAssertEqual(Feature0607ModalCopy.iCloudDownloadTitle, "Fetching today\u{2019}s file from iCloud")
        XCTAssertEqual(
            Feature0607ModalCopy.iCloudDownloadBody,
            "PlainLog is waiting for iCloud Drive to download today\u{2019}s file."
        )
        XCTAssertEqual(Feature0607ModalCopy.iCloudDownloadRetryButton, "Retry")
        XCTAssertEqual(Feature0607ModalCopy.iCloudDownloadCancelButton, "Cancel")
    }
}
