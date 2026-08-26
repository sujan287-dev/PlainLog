import XCTest
import StoreKit
import StoreKitTest
@testable import PlainLog

/// Sprint 5 · Piece 5.1 — BillingKit tests, exercised against StoreKitTest
/// with the PlainLogProducts.storekit configuration.
///
/// Each test uses its own UserDefaults suite (never .standard) to avoid
/// cross-test pollution of the locally-persisted entitlement, torn down
/// via removePersistentDomain in tearDown.
@MainActor
final class BillingKitTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var session: SKTestSession!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "BillingKitTests-\(UUID().uuidString)"
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        session = nil
        if let suiteName {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        userDefaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    /// Starts an SKTestSession against PlainLogProducts.storekit with
    /// interactive confirmation dialogs disabled (required in a headless CI
    /// simulator run — without this, StoreKitTest can present a dialog that
    /// would hang the test).
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "PlainLogProducts")
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    // MARK: - Product loading

    func testLoadProductsSucceeds() async throws {
        session = try makeSession()
        let billing = BillingKit(userDefaults: userDefaults)

        await billing.loadProducts()

        XCTAssertEqual(billing.products.count, 1)
        XCTAssertEqual(billing.products.first?.id, "com.plainlog.ios.pro")
        XCTAssertNil(billing.productsLoadError)
    }

    // MARK: - Purchase

    func testPurchaseSucceeds() async throws {
        session = try makeSession()
        let billing = BillingKit(userDefaults: userDefaults)

        await billing.loadProducts()
        await billing.purchase()

        XCTAssertTrue(billing.isProEnabled)
        XCTAssertEqual(billing.purchaseState, .purchased)
        XCTAssertTrue(userDefaults.bool(forKey: BillingKit.entitlementKey))
    }

    // MARK: - Purchase cancellation

    /// SKTestSession has no public API to force a Product.purchase() call to
    /// resolve as .userCancelled — failTransactionsEnabled simulates a
    /// transaction FAILURE, not a user-initiated cancellation, and there is
    /// no documented equivalent toggle for cancellation. Per the piece
    /// instructions, this is skipped rather than faked: PurchaseState.cancelled
    /// is exercised by code inspection (the .userCancelled case in
    /// BillingKit.purchase()'s switch), not by an automated test.
    func testPurchaseUserCancelled() throws {
        throw XCTSkip(
            "SKTestSession cannot simulate .userCancelled — no public API " +
            "forces this outcome (failTransactionsEnabled simulates a " +
            "transaction failure, not a user cancellation). Not faked."
        )
    }

    // MARK: - Restore

    func testRestorePurchases() async throws {
        session = try makeSession()

        let first = BillingKit(userDefaults: userDefaults)
        await first.loadProducts()
        await first.purchase()
        XCTAssertTrue(first.isProEnabled)

        // Simulate a fresh launch: a second instance over the SAME
        // UserDefaults suite, but StoreKit's own entitlement (not our local
        // one) is what restorePurchases() must recover from.
        let second = BillingKit(userDefaults: userDefaults)

        await second.restorePurchases()

        XCTAssertTrue(second.isProEnabled)
        XCTAssertEqual(second.restoreState, .restored)
    }

    // MARK: - Free features not blocked by load failure

    /// SKTestSession's failTransactionsEnabled simulates a PURCHASE/transaction
    /// failure, not a product-catalog-loading failure — Product.products(for:)
    /// does not throw for a request it can't fully resolve, so there's no
    /// documented SKTestSession API that forces loadProducts() itself to fail.
    /// Per the piece's own fallback instruction, this uses no SKTestSession at
    /// all (so the App Store connection BillingKit depends on isn't backed by
    /// any test product catalog); the acceptance criterion (Feature 12: "free
    /// features remain usable" / "StoreKit errors do not block free features")
    /// is what's actually under test, not a specific StoreKit error shape.
    func testFreeFeaturesNotBlockedByLoadFailure() async {
        let billing = BillingKit(userDefaults: userDefaults)

        await billing.loadProducts()

        XCTAssertTrue(billing.productsLoadError != nil || billing.products.isEmpty)
        XCTAssertFalse(billing.isProEnabled)
    }

    // MARK: - Entitlement persistence across instances

    func testEntitlementPersistsAcrossInstances() async throws {
        session = try makeSession()

        let first = BillingKit(userDefaults: userDefaults)
        await first.loadProducts()
        await first.purchase()
        XCTAssertTrue(first.isProEnabled)

        // Second instance reads the LOCAL entitlement synchronously on init,
        // before any StoreKit call — this is what's under test here, not
        // restorePurchases()'s own network-backed recovery path.
        let second = BillingKit(userDefaults: userDefaults)

        XCTAssertTrue(second.isProEnabled)
    }
}
