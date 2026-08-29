import Foundation
import StoreKit
import Observation

/// BillingKit — Sprint 5 (PLAN.md §12).
/// StoreKit 2 product loading, purchase, restore, and local entitlement for
/// the single PlainLog Pro non-consumable (Feature 12).
///
/// Design (PLAN.md §4 / Feature 12):
/// - No third-party billing SDK, no server-side purchase profile.
/// - Entitlement is stored locally (UserDefaults) — never inferred from a
///   backend PlainLog doesn't have.
/// - StoreKit loading errors NEVER block free features: loadProducts() never
///   throws, and a failure just leaves isProEnabled at whatever the
///   locally-persisted entitlement already says.
@MainActor
@Observable
final class BillingKit {

    /// Single non-consumable product ID (Feature 12: one-time purchase).
    static let productID = "com.plainlog.ios.pro"

    /// UserDefaults key for the locally-stored entitlement (Feature 12:
    /// "store entitlement locally", no server-side purchase profile).
    static let entitlementKey = "plainlog.pro.entitlement"

    private let userDefaults: UserDefaults

    // MARK: - State

    private(set) var products: [Product] = []
    private(set) var isProEnabled: Bool
    private(set) var purchaseState: PurchaseState = .idle
    private(set) var restoreState: RestoreState = .idle
    private(set) var productsLoadError: String?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        // Read the local entitlement immediately, before any StoreKit call —
        // free-vs-Pro must be known synchronously at launch, not only after
        // a network round trip.
        self.isProEnabled = userDefaults.bool(forKey: Self.entitlementKey)

        // Fire-and-forget: a started Task keeps running without needing its
        // handle retained (matches the drain-task pattern in
        // DocumentStore.performSave()). No stored handle means no deinit
        // cleanup is needed at all — sidesteps the actor-isolation
        // constraint FolderAccessService's empty deinit documents (deinit is
        // always non-isolated, even on a @MainActor class, so it can't read
        // a MainActor-isolated stored property to cancel it). In practice
        // BillingKit is a long-lived, app-lifetime service; the OS reclaims
        // everything on termination.
        Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    // MARK: - Product loading

    /// Loads the Pro product from the App Store. Never throws: any failure
    /// is captured in productsLoadError, leaving products empty and
    /// isProEnabled untouched — free features are never blocked (Feature 12).
    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: [Self.productID])
            products = loaded
            productsLoadError = nil
        } catch {
            products = []
            productsLoadError = error.localizedDescription
        }
    }

    // MARK: - Purchase

    /// Purchases the single Pro product. Requires loadProducts() to have
    /// already populated exactly the one product.
    func purchase() async {
        guard products.count == 1, let product = products.first else {
            purchaseState = .failed(reason: "Product not loaded")
            return
        }

        purchaseState = .purchasing

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    // Bugfix (entitlement revocation): a just-verified
                    // transaction is definitive proof of entitlement —
                    // apply it directly rather than re-deriving it from a
                    // fresh Transaction.currentEntitlements enumeration,
                    // which could theoretically lag behind this exact
                    // transaction by a moment. Never lets a purchase that
                    // just succeeded fail to unlock immediately.
                    applyEntitlement(EntitlementDecision.evaluate(
                        verifiedFound: true,
                        current: isProEnabled,
                        allowDowngrade: false
                    ))
                    purchaseState = .purchased
                case .unverified(_, let error):
                    purchaseState = .failed(reason: error.localizedDescription)
                }
            case .userCancelled:
                purchaseState = .cancelled
            case .pending:
                purchaseState = .pending
            @unknown default:
                purchaseState = .failed(reason: "Unknown purchase result")
            }
        } catch {
            purchaseState = .failed(reason: error.localizedDescription)
        }
    }

    // MARK: - Restore

    /// Restores prior purchases (Feature 12). Never throws: a sync failure
    /// is captured in restoreState, and the existing local entitlement is
    /// left untouched.
    func restorePurchases() async {
        restoreState = .restoring
        do {
            try await AppStore.sync()
            // Bugfix (entitlement revocation): explicit, user-initiated
            // restore is the one authoritative context where a genuine
            // refund/revocation should actually take effect.
            await updateEntitlement(allowDowngrade: true)
            restoreState = .restored
        } catch {
            restoreState = .failed(reason: error.localizedDescription)
        }
    }

    // MARK: - Entitlement

    /// Applies a decided entitlement value: updates isProEnabled and
    /// persists it. The one place that writes the persisted key, shared by
    /// every entitlement-determining path.
    private func applyEntitlement(_ entitled: Bool) {
        isProEnabled = entitled
        userDefaults.set(entitled, forKey: Self.entitlementKey)
    }

    /// Checks Transaction.currentEntitlements for our product ID and applies
    /// the resulting EntitlementDecision. allowDowngrade controls whether a
    /// NOT-found result is trusted enough to revoke an existing entitlement
    /// — see EntitlementDecision's doc comment.
    private func updateEntitlement(allowDowngrade: Bool) async {
        var verifiedFound = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.productID {
                verifiedFound = true
                break
            }
        }
        applyEntitlement(EntitlementDecision.evaluate(
            verifiedFound: verifiedFound,
            current: isProEnabled,
            allowDowngrade: allowDowngrade
        ))
    }

    // MARK: - Transaction listener

    /// Long-running task observing Transaction.updates (server-to-server
    /// notifications, Family Sharing, renewals initiated on other devices,
    /// etc.) so the local entitlement stays in sync outside the purchase/
    /// restore flows.
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID else {
                continue
            }
            await transaction.finish()
            // Bugfix (entitlement revocation): a passive background
            // trigger — don't let a possibly transient/incomplete
            // currentEntitlements enumeration silently revoke a paying
            // customer's access with no user action to notice or correct
            // it. A genuine revocation still gets reflected the next time
            // the user (or a fresh restore) re-checks.
            await updateEntitlement(allowDowngrade: false)
        }
    }
}

// MARK: - Purchase state

enum PurchaseState: Equatable {
    case idle
    case loading
    case purchasing
    case purchased
    case failed(reason: String)
    case cancelled
    case pending
}

// MARK: - Restore state

enum RestoreState: Equatable {
    case idle
    case restoring
    case restored
    case failed(reason: String)
}
