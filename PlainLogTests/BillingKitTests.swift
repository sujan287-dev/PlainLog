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
///
/// Every StoreKit-calling method is wrapped in runBounded(): a first CI run
/// (run 33013584600) hung indefinitely partway through restorePurchases()'s
/// AppStore.sync() call, with no completion after 30+ minutes — this is a
/// hard timeout so a repeat of that class of hang fails ONE test cleanly
/// instead of blocking the whole CI job again (build.yml also now has a
/// step-level timeout-minutes as a second, independent backstop).
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

    /// Bounds a StoreKit async call with a hard timeout. Normal StoreKitTest
    /// calls resolve in well under a second; 15s is generous headroom, not
    /// an expected real duration — this exists purely as a safety net.
    private func runBounded(
        timeout: TimeInterval = 15,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: @escaping () async -> Void
    ) {
        let didComplete = expectation(description: "StoreKit call completes")
        Task {
            await operation()
            didComplete.fulfill()
        }
        let result = XCTWaiter().wait(for: [didComplete], timeout: timeout)
        if result != .completed {
            XCTFail("StoreKit call did not complete within \(timeout)s — likely hung", file: file, line: line)
        }
    }

    // MARK: - Product loading

    func testLoadProductsSucceeds() throws {
        session = try makeSession()
        let billing = BillingKit(userDefaults: userDefaults)

        runBounded { await billing.loadProducts() }

        XCTAssertEqual(billing.products.count, 1)
        XCTAssertEqual(billing.products.first?.id, "com.plainlog.ios.pro")
        XCTAssertNil(billing.productsLoadError)
    }

    // MARK: - Purchase

    func testPurchaseSucceeds() throws {
        session = try makeSession()
        let billing = BillingKit(userDefaults: userDefaults)

        runBounded { await billing.loadProducts() }
        runBounded { await billing.purchase() }

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

    func testRestorePurchases() throws {
        session = try makeSession()

        let first = BillingKit(userDefaults: userDefaults)
        runBounded { await first.loadProducts() }
        runBounded { await first.purchase() }
        XCTAssertTrue(first.isProEnabled)

        // Simulate a fresh launch: a second instance over the SAME
        // UserDefaults suite, but StoreKit's own entitlement (not our local
        // one) is what restorePurchases() must recover from.
        let second = BillingKit(userDefaults: userDefaults)

        runBounded { await second.restorePurchases() }

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
    func testFreeFeaturesNotBlockedByLoadFailure() throws {
        let billing = BillingKit(userDefaults: userDefaults)

        runBounded { await billing.loadProducts() }

        XCTAssertTrue(billing.productsLoadError != nil || billing.products.isEmpty)
        XCTAssertFalse(billing.isProEnabled)
    }

    // MARK: - Entitlement persistence across instances

    func testEntitlementPersistsAcrossInstances() throws {
        session = try makeSession()

        let first = BillingKit(userDefaults: userDefaults)
        runBounded { await first.loadProducts() }
        runBounded { await first.purchase() }
        XCTAssertTrue(first.isProEnabled)

        // Second instance reads the LOCAL entitlement synchronously on init,
        // before any StoreKit call — this is what's under test here, not
        // restorePurchases()'s own network-backed recovery path.
        let second = BillingKit(userDefaults: userDefaults)

        XCTAssertTrue(second.isProEnabled)
    }
}
