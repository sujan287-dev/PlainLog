import XCTest
@testable import PlainLog

/// Sprint 5 · Piece 5.7 — ReselectionGuard is a pure decision model (no I/O),
/// so these are plain input/output assertions. Orchestration
/// (ReselectionCoordinator/ReselectionFlowState) and SwiftUI presentation
/// are intentionally not covered here, per this piece's own test scope.
final class ReselectionGuardTests: XCTestCase {

    func testNotDirtyRequiresNoConfirmation() {
        let requirement = ReselectionGuard.evaluate(
            isDirty: false,
            folderNameMatchesHint: false,
            todayFileExistsInTarget: true
        )
        XCTAssertTrue(requirement.isEmpty)
    }

    func testDirtyWithMatchingNameAndNoExistingFileRequiresNoConfirmation() {
        let requirement = ReselectionGuard.evaluate(
            isDirty: true,
            folderNameMatchesHint: true,
            todayFileExistsInTarget: false
        )
        XCTAssertTrue(requirement.isEmpty)
    }

    func testDirtyWithNameMismatchRequiresReselectionWarning() {
        let requirement = ReselectionGuard.evaluate(
            isDirty: true,
            folderNameMatchesHint: false,
            todayFileExistsInTarget: false
        )
        XCTAssertEqual(requirement, .reselectionWarning)
    }

    func testExistingTargetFileRequiresExistingTargetFileWarning() {
        let requirement = ReselectionGuard.evaluate(
            isDirty: true,
            folderNameMatchesHint: true,
            todayFileExistsInTarget: true
        )
        XCTAssertEqual(requirement, .existingTargetFileWarning)
    }

    /// Multi-condition case: both apply. The documented ordering (see
    /// ReselectionGuard's doc comment — reselection warning resolves before
    /// existing-target-file warning) is enforced by callers checking
    /// .reselectionWarning first; this asserts both flags are actually
    /// present, which is what lets a caller enforce that order.
    func testNameMismatchAndExistingFileRequiresBothWarnings() {
        let requirement = ReselectionGuard.evaluate(
            isDirty: true,
            folderNameMatchesHint: false,
            todayFileExistsInTarget: true
        )
        XCTAssertTrue(requirement.contains(.reselectionWarning))
        XCTAssertTrue(requirement.contains(.existingTargetFileWarning))
        XCTAssertEqual(requirement, [.reselectionWarning, .existingTargetFileWarning])
    }
}
