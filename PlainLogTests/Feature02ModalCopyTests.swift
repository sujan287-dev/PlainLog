import XCTest
@testable import PlainLog

/// Sprint 5 · Piece 5.7 — Feature 02 copy, verbatim (like Feature08ModalCopyTests).
/// The reselection-warning and existing-target-file blocks each have no
/// separate title line in PLAN.md, so Title + "\n" + Message is asserted to
/// reproduce the full block exactly, in addition to each constant on its own.
final class Feature02ModalCopyTests: XCTestCase {

    func testRecoveryWithEditsCopy() {
        XCTAssertEqual(Feature02ModalCopy.recoveryWithEditsTitle, "Folder access lost")
        XCTAssertEqual(
            Feature02ModalCopy.recoveryWithEditsBody,
            "PlainLog cannot save to your folder right now.\nPlease reconnect to save your changes safely.\nYour current edits are only in memory.\nDo not force-close the app if you want to keep them."
        )
        XCTAssertEqual(Feature02ModalCopy.recoveryWithEditsChooseFolderButton, "Choose folder")
        XCTAssertEqual(Feature02ModalCopy.recoveryWithEditsCopyTextButton, "Copy current text")
    }

    func testReselectionWarningCopy() {
        let combined = Feature02ModalCopy.reselectionWarningTitle + "\n" + Feature02ModalCopy.reselectionWarningMessage
        XCTAssertEqual(
            combined,
            "You have unsaved edits.\nPlainLog cannot verify that this is the original folder.\nSaving will write your current text to the selected folder.\nIf you are unsure, copy your text instead."
        )
        XCTAssertEqual(Feature02ModalCopy.reselectionWarningSaveButton, "Save to selected folder")
        XCTAssertEqual(Feature02ModalCopy.reselectionWarningCopyButton, "Copy text")
        XCTAssertEqual(Feature02ModalCopy.reselectionWarningCancelButton, "Cancel")
    }

    func testExistingTargetFileWarningCopy() {
        let combined = Feature02ModalCopy.existingTargetFileWarningTitle + "\n" + Feature02ModalCopy.existingTargetFileWarningMessage
        XCTAssertEqual(
            combined,
            "A file for today already exists in this folder.\nSaving may overwrite it.\nIf you are unsure, save as a copy instead."
        )
        XCTAssertEqual(Feature02ModalCopy.existingTargetFileSaveAsCopyButton, "Save as copy")
        XCTAssertEqual(Feature02ModalCopy.existingTargetFileReplaceButton, "Replace existing file")
        XCTAssertEqual(Feature02ModalCopy.existingTargetFileCancelButton, "Cancel")
    }
}
