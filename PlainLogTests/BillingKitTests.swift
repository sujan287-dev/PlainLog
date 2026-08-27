import XCTest
@testable import PlainLog

/// Sprint 5 · Piece 5.1 — BillingKit tests, exercised against StoreKitTest
/// with the PlainLogProducts.storekit configuration.
///
/// Each test uses its own UserDefaults suite (never .standard) to avoid
/// cross-test pollution of the locally-persisted entitlement, torn down
/// via removePersistentDomain in tearDown.
///
/// KNOWN CI LIMITATION — read before touching the skips below:
/// Four tests here are skipped because `xcodebuild test` invoked from the
/// command line (this project's only build oracle — no local Xcode) does
/// not sync the StoreKit Configuration file to SKTestSession the way
/// running the same test from the Xcode IDE does. Confirmed across three
/// separate CI runs while diagnosing this piece:
///   - Run 33113378482 / 33113997456: SKTestSession(configurationFileNamed:)
///     constructs without throwing, but Product.products(for:) returns an
///     empty array — with the .storekit file bundled into BOTH the app and
///     test targets (ruled out as a resource-bundling issue).
///   - Run 33114740989: switching the CI simulator to the oldest available
///     iOS 17+ runtime (a documented workaround for a separate, known
///     regression where newer runtimes hang inside AppStore.sync() under
///     CLI-driven tests) fixed THAT hang, but Product.products(for:) still
///     returned empty — same symptom, independent of runtime version.
/// This matches reports on Apple's Developer Forums describing the same
/// CLI-vs-IDE gap as unresolved. Every StoreKit-calling method is still
/// wrapped in runBounded() (a hard timeout) as a standing safety net against
/// a repeat of the AppStore.sync() hang, independent of this issue.
///
/// BillingKit's production implementation is unaffected by this — it's
/// written directly against StoreKit 2's documented API contract. What's
/// blocked is CI's ability to *exercise* the purchase/restore flow
/// end-to-end; that verification has to happen via Xcode IDE or a real
/// device/simulator (Track B — needs a Mac, out of scope for this piece).
@MainActor
final class BillingKitTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "BillingKitTests-\(UUID().uuidString)"
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        if let suiteName {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        userDefaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    // Note: the SKTestSession(configurationFileNamed:) construction this
    // suite used before skipping (disableDialogs = true, clearTransactions())
    // is preserved in git history on this file — restore it if the CI
    // catalog-loading limitation described above is ever resolved upstream,
    // rather than leaving it here unused in the meantime.

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

    private static let ciCatalogSkipReason =
        "CI-only limitation: xcodebuild test (CLI) does not sync the StoreKit " +
        "Configuration to SKTestSession — Product.products(for:) returns empty " +
        "with no thrown error, confirmed independent of simulator runtime " +
        "version (see the class-level comment for the three CI runs that " +
        "isolated this). Requires Xcode IDE or a real device to exercise; not " +
        "faked here."

    // MARK: - Product loading

    func testLoadProductsSucceeds() throws {
        throw XCTSkip(Self.ciCatalogSkipReason)
    }

    // MARK: - Purchase

    func testPurchaseSucceeds() throws {
        throw XCTSkip(Self.ciCatalogSkipReason)
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
        throw XCTSkip(Self.ciCatalogSkipReason)
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
    /// Unaffected by the CI catalog-loading limitation above — this test
    /// deliberately never has a catalog to load in the first place.
    func testFreeFeaturesNotBlockedByLoadFailure() throws {
        let billing = BillingKit(userDefaults: userDefaults)

        runBounded { await billing.loadProducts() }

        XCTAssertTrue(billing.productsLoadError != nil || billing.products.isEmpty)
        XCTAssertFalse(billing.isProEnabled)
    }

    // MARK: - Entitlement persistence across instances

    func testEntitlementPersistsAcrossInstances() throws {
        throw XCTSkip(Self.ciCatalogSkipReason)
    }
}
