import XCTest
@testable import PlainLog

/// Sprint 5 · Piece 5.10 — asserts the privacy policy states its required
/// commitments (PLAN.md §15 "Data Not Collected" stance). Matched against
/// the actual substrings written in PrivacyPolicyCopy.text.
final class PrivacyPolicyCopyTests: XCTestCase {

    func testStatesNoDataCollection() {
        XCTAssertTrue(PrivacyPolicyCopy.text.contains("PlainLog does not collect user data."))
    }

    func testStatesNoAccountAnalyticsOrTracking() {
        XCTAssertTrue(PrivacyPolicyCopy.text.contains("no accounts, no analytics, no tracking"))
    }

    func testStatesPlainMarkdownFiles() {
        XCTAssertTrue(PrivacyPolicyCopy.text.contains("plain .md text files"))
    }

    func testStatesNoServerUpload() {
        XCTAssertTrue(PrivacyPolicyCopy.text.contains("PlainLog never uploads your notes to any server"))
    }

    func testStatesICloudSyncIsTheUsersOwnAppleAccount() {
        XCTAssertTrue(PrivacyPolicyCopy.text.contains("your files sync through your own iCloud account, provided by Apple"))
    }

    func testStatesPurchasesAreProcessedByApple() {
        XCTAssertTrue(PrivacyPolicyCopy.text.contains("processed entirely by Apple through the App Store"))
        XCTAssertTrue(PrivacyPolicyCopy.text.contains("PlainLog does not receive or store your payment information"))
    }

    /// Component B's explicit exclusion: no support contact anywhere in the
    /// policy (the founder supplies one separately, out of scope here).
    func testDoesNotIncludeASupportContact() {
        let lowercased = PrivacyPolicyCopy.text.lowercased()
        XCTAssertFalse(lowercased.contains("@"))
        XCTAssertFalse(lowercased.contains("http"))
        XCTAssertFalse(lowercased.contains("contact us"))
    }
}
