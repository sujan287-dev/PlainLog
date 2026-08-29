import Foundation

/// EntitlementDecision — bugfix (entitlement revocation, BillingKit).
/// Pure decision: no I/O, no StoreKit dependency, fully testable.
///
/// BillingKit.updateEntitlement() used to unconditionally overwrite
/// isProEnabled with whatever Transaction.currentEntitlements reported at
/// that instant, from three call sites: purchase(), restorePurchases(), and
/// the passive background listenForTransactions(). If that enumeration ever
/// returned an incomplete result at the wrong moment (a transient StoreKit
/// sync gap, app-launch timing, a network blip) — not a genuine refund —
/// this would silently persist a false negative, revoking a paying
/// customer's Pro access with no user action and no way to notice, since
/// Restore Purchases is the only recovery path.
///
/// This function makes entitlement monotonic by default: a NOT-found result
/// only downgrades an existing entitlement when explicitly trusted to
/// (`allowDowngrade: true`) — appropriate only for restorePurchases(), the
/// one explicit, user-initiated, authoritative full sync where a genuine
/// revocation/refund should actually take effect. purchase() and the
/// passive listener pass `allowDowngrade: false`: a transient gap there
/// just preserves the existing entitlement instead of silently erasing it;
/// a genuine revocation still gets reflected the next time the user (or a
/// fresh restore) re-checks.
enum EntitlementDecision {
    static func evaluate(verifiedFound: Bool, current: Bool, allowDowngrade: Bool) -> Bool {
        if verifiedFound {
            return true
        }
        return allowDowngrade ? false : current
    }
}
