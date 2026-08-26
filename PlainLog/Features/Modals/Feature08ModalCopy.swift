import Foundation

/// Feature 08 conflict / deleted-file modal copy (verbatim, test-enforced).
/// Do not paraphrase. Do not edit without updating PLAN.md and the tests
/// together.
enum Feature08ModalCopy {

    // MARK: - Conflict modal

    static let conflictTitle = "This file changed outside PlainLog"

    /// PLAN.md presents this as two blank-line-separated lines ("You have
    /// unsaved edits." / "Reload the file, or save your edits as a copy."),
    /// the same paragraph-break convention already used for Feature 01's
    /// iCloud warning copy — rendered here as \n\n, matching that precedent.
    static let conflictMessage =
        "You have unsaved edits.\n\nReload the file, or save your edits as a copy."

    // MARK: - Deleted file modal — with unsaved edits

    static let deletedTitleWithEdits = "This file was deleted outside PlainLog"

    /// PLAN.md presents these two sentences as consecutive lines with no
    /// blank line between them — a single \n, not a paragraph break.
    static let deletedMessageWithEdits =
        "You have unsaved edits.\nYou can recreate the file with your current text, or discard your edits."

    // MARK: - Deleted file modal — without unsaved edits

    static let deletedTitleWithoutEdits = "This file was deleted outside PlainLog"

    /// No message body for this variant — title and an OK button only.
    static let deletedMessageWithoutEdits = ""
}
