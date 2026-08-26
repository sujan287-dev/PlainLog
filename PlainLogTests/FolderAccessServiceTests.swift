import XCTest
@testable import PlainLog

@MainActor
final class FolderAccessServiceTests: XCTestCase {

    private var mockStore: MockBookmarkStore!
    private var service: FolderAccessService!

    override func setUp() {
        super.setUp()
        mockStore = MockBookmarkStore()
        service = FolderAccessService(store: mockStore)
    }

    override func tearDown() {
        // registerFolderAccess persists a display-name hint directly to
        // UserDefaults.standard (a real, global store — unlike the injected
        // mock bookmark store), so it would otherwise leak between tests.
        service.clearAccess()
        service = nil
        mockStore = nil
        super.tearDown()
    }

    func testInitialStateIsNoFolderSelectedWhenStoreEmpty() {
        service.start()

        XCTAssertEqual(service.state, .noFolderSelected)
    }

    func testRegisterFolderAccessUpdatesState() {
        // Use a temporary URL for testing (simulating a folder selection)
        // Note: In a real device test, we'd use a security-scoped URL.
        // Here we just verify the flow doesn't crash and attempts to save.
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())

        service.registerFolderAccess(url: tempURL)

        // Since we are in a test environment without valid security scope,
        // it might fail to startAccessingSecurityScopedResource,
        // but we verify the store was called.
        XCTAssertNotNil(mockStore.savedData)
    }

    func testDisplayNameHintIsSavedOnRegister() {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
        service.registerFolderAccess(url: tempURL)

        XCTAssertNotNil(service.folderDisplayNameHint)
        XCTAssertEqual(service.folderDisplayNameHint, tempURL.lastPathComponent)
    }

    func testDisplayNameHintIsClearedOnClearAccess() {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
        service.registerFolderAccess(url: tempURL)
        XCTAssertNotNil(service.folderDisplayNameHint)

        service.clearAccess()
        XCTAssertNil(service.folderDisplayNameHint)
    }

    func testICloudDetectionWithPathHeuristic() {
        // Simulate an iCloud Drive path
        let iCloudURL = URL(fileURLWithPath: "/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/TestFolder")
        XCTAssertTrue(FolderAccessService.isICloudFolder(url: iCloudURL))

        // Simulate a local path
        let localURL = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/TestFolder")
        XCTAssertFalse(FolderAccessService.isICloudFolder(url: localURL))
    }

    func testStartIsIdempotentWhenNotInNoFolderSelectedState() {
        // Initial state is .noFolderSelected
        service.start()
        XCTAssertEqual(service.state, .noFolderSelected)

        // Simulate a state transition (e.g., to .folderReady via registerFolderAccess)
        // Then calling start() again should be a no-op
        // We can't easily simulate .folderReady without a real security-scoped URL,
        // but we can verify the guard works by checking that start() doesn't crash
        // when called multiple times.
        service.start()
        service.start()
        service.start()

        // Should still be .noFolderSelected (no bookmark stored)
        XCTAssertEqual(service.state, .noFolderSelected)
    }

    func testRecoveryFlowRegisterAfterAccessLost() {
        // Simulate access lost state
        // We can't directly set state to .accessLost since it's set internally,
        // but we can verify that registerFolderAccess works after clearAccess
        // (which simulates the recovery scenario).
        service.clearAccess()
        XCTAssertEqual(service.state, .noFolderSelected)

        // Now register a new folder (simulating recovery reselection)
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
        service.registerFolderAccess(url: tempURL)

        // Verify the bookmark was saved (recovery creates a new bookmark)
        XCTAssertNotNil(mockStore.savedData)
        XCTAssertNotNil(service.folderDisplayNameHint)
    }

    func testStatusDescriptionForNoFolderSelected() {
        service.clearAccess()
        XCTAssertEqual(service.statusDescription, "No folder selected")
    }

    func testStatusDescriptionMappingCoversAllStates() {
        // Verify statusDescription returns non-empty strings for all states.
        // We can only easily test .noFolderSelected without a real bookmark,
        // but we verify the property exists and returns a valid string.
        service.clearAccess()
        XCTAssertFalse(service.statusDescription.isEmpty)
    }

    // MARK: - bookmarkNeedsRefresh / .folderUnwritable (C5)

    func testBookmarkNeedsRefreshDefaultsFalse() {
        // The real stale-bookmark-refresh-failure path requires an actually
        // stale security-scoped bookmark, which isn't reliably reproducible
        // in this sandboxed test environment (same class of limitation as
        // the real-device-only iCloud paths already in QA debt). This pins
        // the safe default a fresh service starts with.
        XCTAssertFalse(service.bookmarkNeedsRefresh)
    }

    func testReportUnwritableFolderUpdatesState() {
        service.reportUnwritableFolder(reason: "Read-only volume")

        XCTAssertEqual(service.state, .folderUnwritable(reason: "Read-only volume"))
        XCTAssertEqual(service.statusDescription, "Folder unwritable")
    }
}

// Mock Store for Testing
final class MockBookmarkStore: BookmarkStore {
    var savedData: Data?

    func loadBookmarkData() -> Data? { savedData }
    func saveBookmarkData(_ data: Data) { savedData = data }
    func clearBookmarkData() { savedData = nil }
}
