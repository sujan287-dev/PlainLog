import Foundation

/// The state of a daily file after an open attempt.
/// Matches PLAN.md §9 "File states" (subset relevant to open orchestration).
enum DailyFileState: Equatable {
    /// File exists and was loaded successfully.
    case loaded(text: String)

    /// File does not exist. Show empty editor as pending new file.
    /// Do NOT create the file yet (Feature 03 pending-new-file policy).
    case pending

    /// File is an evicted iCloud item. Download must be requested first.
    case downloading

    /// iCloud download failed.
    case downloadFailed(reason: String)

    /// File exists but could not be loaded (encoding error, I/O error, etc.).
    case loadFailed(reason: String)
}
