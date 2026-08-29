import XCTest
@testable import PlainLog

/// Bugfix (entitlement revocation, BillingKit) — EntitlementDecision is a
/// pure decision model (no I/O, no StoreKit), so these are plain
/// input/output assertions. Runs on every CI configuration, unlike
/// BillingKitTests' StoreKit-dependent cases.
final class EntitlementDecisionTests: XCTestCase {

    // MARK: - verifiedFound always wins

    func testVerifiedFoundIsAlwaysEntitledRegardlessOfCurrentOrAllowDowngrade() {
        XCTAssertTrue(EntitlementDecision.evaluate(verifiedFound: true, current: false, allowDowngrade: false))
        XCTAssertTrue(EntitlementDecision.evaluate(verifiedFound: true, current: false, allowDowngrade: true))
        XCTAssertTrue(EntitlementDecision.evaluate(verifiedFound: true, current: true, allowDowngrade: false))
        XCTAssertTrue(EntitlementDecision.evaluate(verifiedFound: true, current: true, allowDowngrade: true))
    }

    // MARK: - Not found, downgrade disallowed: preserves current

    /// The core "no silent revocation" guarantee: a not-found result must
    /// never erase an existing entitlement unless downgrade is explicitly
    /// allowed.
    func testNotFoundWithoutAllowDowngradePreservesAnExistingEntitlement() {
        XCTAssertTrue(EntitlementDecision.evaluate(verifiedFound: false, current: true, allowDowngrade: false))
    }

    func testNotFoundWithoutAllowDowngradeStaysNotEntitledWhenAlreadyNotEntitled() {
        XCTAssertFalse(EntitlementDecision.evaluate(verifiedFound: false, current: false, allowDowngrade: false))
    }

    // MARK: - Not found, downgrade allowed: trusts the negative result

    func testNotFoundWithAllowDowngradeRevokesAnExistingEntitlement() {
        XCTAssertFalse(EntitlementDecision.evaluate(verifiedFound: false, current: true, allowDowngrade: true))
    }

    func testNotFoundWithAllowDowngradeStaysNotEntitledWhenAlreadyNotEntitled() {
        XCTAssertFalse(EntitlementDecision.evaluate(verifiedFound: false, current: false, allowDowngrade: true))
    }
}
