import XCTest
@testable import PlainLog

/// Follow-up to Sprint 5 — Supporter badge copy (PLAN.md Feature 12 "Pro
/// features" list names the badge but gives it no copy; these constants are
/// invented, kept short and on-brand, flagged in the piece's report).
final class SettingsProCopyTests: XCTestCase {

    func testSupporterBadgeLabel() {
        XCTAssertEqual(SettingsProCopy.supporterBadgeLabel, "Supporter")
    }

    func testSupporterBadgeCaption() {
        XCTAssertEqual(SettingsProCopy.supporterBadgeCaption, "Thank you for supporting PlainLog.")
    }
}
