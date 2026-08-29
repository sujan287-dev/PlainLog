import XCTest
@testable import PlainLog

/// Bugfix H3 (full-codebase audit) — EditorModalQueue is a pure FIFO
/// presentation queue (no I/O), so these are plain input/output assertions.
final class EditorModalQueueTests: XCTestCase {

    func testEmptyQueueHasNoActiveModal() {
        let queue = EditorModalQueue()
        XCTAssertNil(queue.active)
    }

    func testPresentingSetsActiveModal() {
        var queue = EditorModalQueue()
        queue.present(.conflict)
        XCTAssertEqual(queue.active, .conflict)
    }

    /// The core "no silently dropped modal" guarantee: a second modal
    /// enqueued while one is already active does not replace or drop it —
    /// it waits its turn.
    func testSecondModalDoesNotReplaceTheActiveOne() {
        var queue = EditorModalQueue()
        queue.present(.saveError)
        queue.present(.conflict)

        XCTAssertEqual(queue.active, .saveError, "The first modal must stay active until dismissed.")
    }

    func testDismissingActivePromotesTheNextQueuedModal() {
        var queue = EditorModalQueue()
        queue.present(.saveError)
        queue.present(.conflict)

        queue.dismissActive()

        XCTAssertEqual(queue.active, .conflict, "Dismissing the first modal must promote the second, not drop it.")
    }

    func testDismissingWithNothingQueuedIsANoOp() {
        var queue = EditorModalQueue()
        queue.dismissActive()
        XCTAssertNil(queue.active)
    }

    /// Presenting the same modal twice while it's already queued must not
    /// duplicate it (e.g. two independent triggers both wanting to show the
    /// iCloud-download modal in the same event).
    func testPresentingAnAlreadyQueuedModalDoesNotDuplicateIt() {
        var queue = EditorModalQueue()
        queue.present(.iCloudDownload)
        queue.present(.iCloudDownload)

        queue.dismissActive()

        XCTAssertNil(queue.active, "The duplicate present() call must not have queued a second entry.")
    }

    /// Different associated-value cases of the same modal type (e.g. the
    /// deleted-file modal's two variants) are distinct queue entries.
    func testDeletedFileVariantsAreDistinctQueueEntries() {
        var queue = EditorModalQueue()
        queue.present(.deletedFile(.withUnsavedEdits))
        queue.present(.deletedFile(.withoutUnsavedEdits))

        XCTAssertEqual(queue.active, .deletedFile(.withUnsavedEdits))
        queue.dismissActive()
        XCTAssertEqual(queue.active, .deletedFile(.withoutUnsavedEdits))
    }

    /// Three colliding triggers in one event (the exact scenario the audit
    /// found) all eventually get shown, in FIFO order, none silently lost.
    func testThreeCollidingModalsAllSurfaceInOrder() {
        var queue = EditorModalQueue()
        queue.present(.saveError)
        queue.present(.conflict)
        queue.present(.offlineCopyWarning)

        XCTAssertEqual(queue.active, .saveError)
        queue.dismissActive()
        XCTAssertEqual(queue.active, .conflict)
        queue.dismissActive()
        XCTAssertEqual(queue.active, .offlineCopyWarning)
        queue.dismissActive()
        XCTAssertNil(queue.active)
    }
}
