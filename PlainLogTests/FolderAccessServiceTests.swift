import XCTest
@testable import PlainLog

@MainActor
final class FolderAccessServiceTests: XCTestCase {

    func testInitialStateIsNoFolderSelectedWhenStoreEmpty() {
        let mockStore = MockBookmarkStore()
        let service = FolderAccessService(store: mockStore)

        service.start()

        XCTAssertEqual(service.state, .noFolderSelected)
    }

    func testRegisterFolderAccessUpdatesState() {
        let mockStore = MockBookmarkStore()
        let service = FolderAccessService(store: mockStore)

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
}

// Mock Store for Testing
final class MockBookmarkStore: BookmarkStore {
    var savedData: Data?

    func loadBookmarkData() -> Data? { savedData }
    func saveBookmarkData(_ data: Data) { savedData = data }
    func clearBookmarkData() { savedData = nil }
}
