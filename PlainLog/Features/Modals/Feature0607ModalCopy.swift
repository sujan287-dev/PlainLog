import Foundation

/// Feature 06 (save error) / Feature 07 (iCloud download) modal copy
/// (verbatim, test-enforced). Do not paraphrase. Do not edit without
/// updating PLAN.md and the tests together.
enum Feature0607ModalCopy {

    // MARK: - Save error (Feature 06)

    static let saveErrorTitle = "PlainLog could not save this file"

    static let saveErrorBody =
        "Your current edits are still in memory.\nTry saving again or copy your text."

    static let saveErrorRetryButton = "Retry"
    static let saveErrorCopyTextButton = "Copy current text"

    // MARK: - iCloud download (Feature 07)

    /// Curly apostrophe (U+2019), matching PLAN.md's raw text exactly —
    /// written as an explicit escape so it can't be silently swapped for a
    /// straight quote.
    static let iCloudDownloadTitle = "Fetching today\u{2019}s file from iCloud"

    static let iCloudDownloadBody =
        "PlainLog is waiting for iCloud Drive to download today\u{2019}s file."

    static let iCloudDownloadRetryButton = "Retry"
    static let iCloudDownloadCancelButton = "Cancel"

    // MARK: - Offline copy warning (Feature 07)

    /// PLAN.md separates these two sentences with a blank line, matching the
    /// same title/message split pattern as Feature02ModalCopy's reselection
    /// and existing-target-file warnings — Title + "\n" + Message reproduces
    /// the full block exactly.
    static let offlineCopyWarningTitle = "You are offline."

    /// Curly apostrophe (U+2019), matching PLAN.md's raw bytes exactly
    /// (hex-checked, per the Piece 5.8 convention).
    static let offlineCopyWarningMessage =
        "Creating a new file now may cause a conflict later if iCloud already contains today\u{2019}s file."

    static let offlineCopyWarningCreateButton = "Create offline file"
    static let offlineCopyWarningCancelButton = "Cancel"

    /// Bugfix (H1, full-codebase audit): not from PLAN.md — an invented,
    /// short banner label. When the offline-copy-warning is Cancelled, the
    /// pending-creation block correctly stays engaged (no shadow draft is
    /// ever written), but nothing was re-showing the warning afterward,
    /// leaving the document permanently unsaveable with zero visible
    /// explanation. This banner (EditorView, shown while
    /// DocumentStore.isPendingCreationBlocked is true) makes that state
    /// visible and gives the user a way back to the confirmation, instead of
    /// a silent dead end.
    static let offlineCaptureBlockedBanner = "Waiting for offline-capture confirmation."
    static let offlineCaptureBlockedReviewButton = "Review"
}
