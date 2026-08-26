import XCTest
@testable import PlainLog

/// Sprint 4 · Piece 4.5 — Feature 08 modal copy, verbatim from PLAN.md.
/// If these fail, the copy drifted — fix the copy, never weaken the tests.
final class Feature08ModalCopyTests: XCTestCase {

    func testConflictModalCopy() {
        XCTAssertEqual(
            Feature08ModalCopy.conflictTitle,
            "This file changed outside PlainLog"
        )
        XCTAssertEqual(
            Feature08ModalCopy.conflictMessage,
            "You have unsaved edits.\nReload the file, or save your edits as a copy."
        )
    }

    func testDeletedFileModalCopyWithEdits() {
        XCTAssertEqual(
            Feature08ModalCopy.deletedTitleWithEdits,
            "This file was deleted outside PlainLog"
        )
        XCTAssertEqual(
            Feature08ModalCopy.deletedMessageWithEdits,
            "You have unsaved edits.\nYou can recreate the file with your current text, or discard your edits."
        )
    }

    func testDeletedFileModalCopyWithoutEdits() {
        XCTAssertEqual(
            Feature08ModalCopy.deletedTitleWithoutEdits,
            "This file was deleted outside PlainLog"
        )
        XCTAssertEqual(Feature08ModalCopy.deletedMessageWithoutEdits, "")
    }
}
