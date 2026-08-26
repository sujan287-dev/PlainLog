import Foundation

/// Represents the global state of the user's folder access.
/// Matches PLAN.md §9.
enum FolderAccessState: Equatable {
    case noFolderSelected
    case resolvingBookmark
    case folderReady(url: URL)
    case bookmarkStale
    case accessLost(reason: String)
    case folderUnwritable(reason: String)

    // URL and String both conform to Equatable, so synthesized conformance is sufficient.
}
