import Foundation

/// Feature 02 folder-reselection copy (verbatim, test-enforced).
/// Do not paraphrase. Do not edit without updating PLAN.md and the tests
/// together.
///
/// Note on paragraph spacing (corrected, M3 — full-codebase audit): PLAN.md
/// separates several of these sentences with blank lines (e.g. "You have
/// unsaved edits." / blank line / "PlainLog cannot verify..."). Piece 5.7
/// deliberately collapsed those internal blank lines to single "\n"s in
/// recoveryWithEditsBody and reselectionWarningMessage, following the exact
/// literal string given in that piece's own prompt rather than PLAN.md's raw
/// formatting — a disclosed choice at the time, not an oversight. Character
/// content is correct; only the paragraph spacing differs from PLAN.md's raw
/// text for those two constants specifically.
/// existingTargetFileWarningTitle/Message have no internal blank line in
/// PLAN.md to begin with, so — unlike the two above — Title + "\n" + Message
/// there does reproduce PLAN.md's spacing exactly.
///
/// The reselection-warning and existing-target-file blocks have no separate
/// title line the way the recovery/conflict modals do, so each is split at
/// its own first paragraph break into a Title + Message pair for display
/// (SwiftUI .alert(title:message:), matching ConflictModal's own pattern).
enum Feature02ModalCopy {

    // MARK: - Recovery screen, with unsaved edits

    static let recoveryWithEditsTitle = "Folder access lost"

    static let recoveryWithEditsBody =
        "PlainLog cannot save to your folder right now.\nPlease reconnect to save your changes safely.\nYour current edits are only in memory.\nDo not force-close the app if you want to keep them."

    static let recoveryWithEditsChooseFolderButton = "Choose folder"
    static let recoveryWithEditsCopyTextButton = "Copy current text"

    // MARK: - Reselection warning, with unsaved edits

    static let reselectionWarningTitle = "You have unsaved edits."

    static let reselectionWarningMessage =
        "PlainLog cannot verify that this is the original folder.\nSaving will write your current text to the selected folder.\nIf you are unsure, copy your text instead."

    static let reselectionWarningSaveButton = "Save to selected folder"
    static let reselectionWarningCopyButton = "Copy text"
    static let reselectionWarningCancelButton = "Cancel"

    // MARK: - Existing target file warning

    static let existingTargetFileWarningTitle = "A file for today already exists in this folder."

    static let existingTargetFileWarningMessage =
        "Saving may overwrite it.\nIf you are unsure, save as a copy instead."

    static let existingTargetFileSaveAsCopyButton = "Save as copy"
    static let existingTargetFileReplaceButton = "Replace existing file"
    static let existingTargetFileCancelButton = "Cancel"
}
