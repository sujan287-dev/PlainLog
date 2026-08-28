import Foundation
import Network
import Observation

/// Abstraction over NWPathMonitor's path-status callback, so
/// ConnectivityMonitor's logic is testable without a real network.
protocol NetworkPathObserving {
    /// Starts observing. Calls `onUpdate` whenever the path status changes
    /// (true == satisfied / online), from any thread — callers hop back to
    /// the main actor themselves.
    func start(onUpdate: @escaping @Sendable (Bool) -> Void)
    func cancel()
}

/// Wraps a real NWPathMonitor, translating its path.status into a plain Bool.
final class NWPathMonitorObserver: NetworkPathObserving {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.plainlog.ios.connectivity")

    func start(onUpdate: @escaping @Sendable (Bool) -> Void) {
        monitor.pathUpdateHandler = { path in
            onUpdate(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
    }
}

/// ConnectivityMonitor — Sprint 5 · Piece 5.9 (PLAN.md Feature 07 requirement
/// 8 / Risk 2). App-level offline detection backing the offline-copy-warning
/// confirmation. Wraps NWPathMonitor (Apple's Network framework — first-
/// party, not a third-party SDK) behind the NetworkPathObserving seam so
/// tests can drive path status without a real network.
///
/// Safe default: isOffline starts false (assume online) until the first
/// callback arrives. The only consumer (OfflineCaptureGuard) uses isOffline
/// to decide whether to BLOCK new-file creation with a warning — a false
/// negative (briefly treating an offline device as online, in the narrow
/// window before the first callback) just means that one save attempt
/// proceeds normally, exactly like today's un-warned behavior. A false
/// positive (defaulting to "offline") would incorrectly gate ordinary file
/// creation for every user on every cold launch until the first real
/// callback lands — a regression, not a safety improvement.
@MainActor
@Observable
final class ConnectivityMonitor {

    private(set) var isOffline: Bool = false

    private let observer: NetworkPathObserving

    init(observer: NetworkPathObserving = NWPathMonitorObserver()) {
        self.observer = observer
        observer.start { [weak self] isSatisfied in
            Task { @MainActor in
                self?.isOffline = !isSatisfied
            }
        }
    }

    // No deinit: matches BillingKit's precedent (deinit on a @MainActor
    // service can't touch MainActor-isolated state, since deinit is always
    // non-isolated). ConnectivityMonitor is a long-lived, app-lifetime
    // service created once in PlainLogApp; the OS reclaims everything on
    // termination.
}
