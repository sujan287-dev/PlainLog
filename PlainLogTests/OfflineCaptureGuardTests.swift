import XCTest
@testable import PlainLog

/// Sprint 5 · Piece 5.9 — OfflineCaptureGuard is a pure decision model (no
/// I/O), so this is the full 2x2x2 truth table.
final class OfflineCaptureGuardTests: XCTestCase {

    func testAllThreeConditionsRequiresWarning() {
        XCTAssertTrue(OfflineCaptureGuard.isWarningRequired(
            folderIsICloud: true, isOffline: true, isCreatingNewFile: true
        ))
    }

    func testLocalFolderNeverRequiresWarning() {
        XCTAssertFalse(OfflineCaptureGuard.isWarningRequired(
            folderIsICloud: false, isOffline: true, isCreatingNewFile: true
        ))
    }

    func testOnlineNeverRequiresWarning() {
        XCTAssertFalse(OfflineCaptureGuard.isWarningRequired(
            folderIsICloud: true, isOffline: false, isCreatingNewFile: true
        ))
    }

    func testEditingExistingFileNeverRequiresWarning() {
        XCTAssertFalse(OfflineCaptureGuard.isWarningRequired(
            folderIsICloud: true, isOffline: true, isCreatingNewFile: false
        ))
    }

    func testLocalFolderOfflineExistingFileDoesNotRequireWarning() {
        XCTAssertFalse(OfflineCaptureGuard.isWarningRequired(
            folderIsICloud: false, isOffline: true, isCreatingNewFile: false
        ))
    }

    func testICloudFolderOnlineExistingFileDoesNotRequireWarning() {
        XCTAssertFalse(OfflineCaptureGuard.isWarningRequired(
            folderIsICloud: true, isOffline: false, isCreatingNewFile: false
        ))
    }

    func testLocalFolderOnlineNewFileDoesNotRequireWarning() {
        XCTAssertFalse(OfflineCaptureGuard.isWarningRequired(
            folderIsICloud: false, isOffline: false, isCreatingNewFile: true
        ))
    }

    func testLocalFolderOnlineExistingFileDoesNotRequireWarning() {
        XCTAssertFalse(OfflineCaptureGuard.isWarningRequired(
            folderIsICloud: false, isOffline: false, isCreatingNewFile: false
        ))
    }
}
