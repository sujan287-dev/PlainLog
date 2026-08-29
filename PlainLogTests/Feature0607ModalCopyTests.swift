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

    /// Sprint 5 · Piece 5.9. Title + "\n" + Message reproduces the full
    /// block exactly (PLAN.md separates the two sentences with a blank
    /// line — same split pattern as Feature02ModalCopy's warnings).
    func testOfflineCopyWarningCopy() {
        let combined = Feature0607ModalCopy.offlineCopyWarningTitle + "\n" + Feature0607ModalCopy.offlineCopyWarningMessage
        XCTAssertEqual(
            combined,
            "You are offline.\nCreating a new file now may cause a conflict later if iCloud already contains today\u{2019}s file."
        )
        XCTAssertEqual(Feature0607ModalCopy.offlineCopyWarningCreateButton, "Create offline file")
        XCTAssertEqual(Feature0607ModalCopy.offlineCopyWarningCancelButton, "Cancel")
    }

    /// Bugfix H1 (full-codebase audit) — invented, not from PLAN.md.
    func testOfflineCaptureBlockedBannerCopy() {
        XCTAssertEqual(Feature0607ModalCopy.offlineCaptureBlockedBanner, "Waiting for offline-capture confirmation.")
        XCTAssertEqual(Feature0607ModalCopy.offlineCaptureBlockedReviewButton, "Review")
    }
}
