import Foundation

/// The result of checking a file against a previous snapshot.
enum ExternalChangeResult: Equatable {
    /// File has not changed since the snapshot.
    case unchanged

    /// File was modified externally (different modification date or size).
    case modified

    /// File was deleted externally.
    case deleted
}
