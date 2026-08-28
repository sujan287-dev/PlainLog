import XCTest
@testable import PlainLog

/// Sprint 5 · Piece 5.2 — pure string assertions against PLAN.md Feature 12.
/// No StoreKit/StoreKitTest dependency: these test PaywallCopy's constants
/// directly, so they run and pass on every CI configuration with no skips.
final class PaywallCopyTests: XCTestCase {

    func testPaywallTitleAndSubtitle() {
        XCTAssertEqual(PaywallCopy.title, "PlainLog Pro")
        XCTAssertEqual(PaywallCopy.subtitle, "Unlock power features and support development.")
    }

    func testPaywallTrustLines() {
        XCTAssertEqual(PaywallCopy.trustOneTime, "One-time purchase.")
        XCTAssertEqual(PaywallCopy.trustNoSubscription, "No subscription.")
        XCTAssertEqual(PaywallCopy.trustNoAccount, "No account.")
        XCTAssertEqual(PaywallCopy.trustNoData, "No data collection.")
    }

    func testPaywallFeatureList() {
        XCTAssertEqual(PaywallCopy.featureExport, "Weekly summary exports")
        XCTAssertEqual(PaywallCopy.featureThemes, "Custom themes")
        XCTAssertEqual(PaywallCopy.featureFonts, "Font options")
        XCTAssertEqual(PaywallCopy.featureFuture, "Future Pro updates")
    }

    func testPaywallButtonTitles() {
        XCTAssertEqual(PaywallCopy.buyButton, "Buy PlainLog Pro")
        XCTAssertEqual(PaywallCopy.restoreButton, "Restore purchase")
    }
}
