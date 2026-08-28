import XCTest
@testable import PlainLog

/// Test double for NetworkPathObserving — drives ConnectivityMonitor's path
/// status without any real network, per this piece's own test scope.
final class MockPathObserver: NetworkPathObserving {
    private var handler: (@Sendable (Bool) -> Void)?

    func start(onUpdate: @escaping @Sendable (Bool) -> Void) {
        handler = onUpdate
    }

    func cancel() {
        handler = nil
    }

    func simulate(isSatisfied: Bool) {
        handler?(isSatisfied)
    }
}

/// Sprint 5 · Piece 5.9 — ConnectivityMonitor state tests using the injected
/// seam. isOffline updates via an internal Task { @MainActor in ... } hop
/// (mirroring how the real NWPathMonitor callback arrives off-thread), so
/// each assertion waits on that hop via a cooperative yield loop rather than
/// a fixed sleep.
@MainActor
final class ConnectivityMonitorTests: XCTestCase {

    func testDefaultsToOnlineBeforeFirstCallback() {
        let mock = MockPathObserver()
        let monitor = ConnectivityMonitor(observer: mock)
        XCTAssertFalse(monitor.isOffline)
    }

    func testBecomesOfflineWhenPathUnsatisfied() {
        let mock = MockPathObserver()
        let monitor = ConnectivityMonitor(observer: mock)

        mock.simulate(isSatisfied: false)

        let didGoOffline = expectation(description: "isOffline becomes true")
        Task { @MainActor in
            while !monitor.isOffline {
                await Task.yield()
            }
            didGoOffline.fulfill()
        }
        wait(for: [didGoOffline], timeout: 2.0)

        XCTAssertTrue(monitor.isOffline)
    }

    func testReturnsOnlineWhenPathSatisfiedAgain() {
        let mock = MockPathObserver()
        let monitor = ConnectivityMonitor(observer: mock)

        mock.simulate(isSatisfied: false)
        let didGoOffline = expectation(description: "isOffline becomes true")
        Task { @MainActor in
            while !monitor.isOffline { await Task.yield() }
            didGoOffline.fulfill()
        }
        wait(for: [didGoOffline], timeout: 2.0)

        mock.simulate(isSatisfied: true)
        let didGoOnline = expectation(description: "isOffline becomes false again")
        Task { @MainActor in
            while monitor.isOffline { await Task.yield() }
            didGoOnline.fulfill()
        }
        wait(for: [didGoOnline], timeout: 2.0)

        XCTAssertFalse(monitor.isOffline)
    }
}
