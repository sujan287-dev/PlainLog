import Foundation

/// The iCloud download state of a file (PLAN.md Feature 07, headless core).
///
/// `.downloading` and `.downloadFailed` are produced by the download-request/
/// observation path (Sprint 3), never by a plain state read: `mapping` only
/// has access to `URLUbiquitousItemDownloadingStatus`, which has no
/// "in progress" value of its own — only `.notDownloaded`, `.downloaded`, and
/// `.current` exist on that type (it's a String-RawRepresentable struct
/// bridged from Objective-C constants, not a true enum). An active download
/// is exposed separately, via `ubiquitousItemIsDownloadingKey`.
enum ICloudFileState: Equatable {
    /// Not an iCloud item (local folder). All normal local files.
    case notICloud

    /// iCloud item with a complete local copy, safe to read/write.
    case localReady

    /// Evicted: exists only in iCloud. MUST be downloaded before any read or
    /// write — never touch it blindly (PLAN.md §4).
    case cloudOnly

    /// Download from iCloud is in progress. Not safe to read yet.
    case downloading

    /// A download attempt failed (set by the download path, not by state reads).
    case downloadFailed(reason: String)

    /// Pure mapping from URL resource values to state.
    /// Kept pure so the full state table is unit-testable without iCloud.
    ///
    /// Safety rule: a ubiquitous item whose download status cannot be read is
    /// treated as cloudOnly. We never assume an iCloud item is local unless
    /// the system explicitly says so (PLAN.md §4: no blind iCloud file creation).
    static func mapping(
        isUbiquitous: Bool,
        downloadStatus: URLUbiquitousItemDownloadingStatus?
    ) -> ICloudFileState {
        guard isUbiquitous else {
            return .notICloud
        }
        switch downloadStatus {
        case .current, .downloaded:
            return .localReady
        default:
            // .notDownloaded, nil (status unreadable), or anything else:
            // refuse to assume local.
            return .cloudOnly
        }
    }
}
