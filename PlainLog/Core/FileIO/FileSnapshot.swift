import Foundation

/// A snapshot of a file's state at a point in time.
/// Used to detect external changes (Feature 08).
struct FileSnapshot: Equatable {
    let url: URL
    let modificationDate: Date?
    let fileSize: Int?

    /// Creates a snapshot by reading the file's attributes.
    /// Returns nil if the file does not exist or attributes cannot be read.
    static func capture(at url: URL, fileManager: FileManager = .default) -> FileSnapshot? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let modificationDate = attributes[.modificationDate] as? Date
            let fileSize = attributes[.size] as? Int
            return FileSnapshot(url: url, modificationDate: modificationDate, fileSize: fileSize)
        } catch {
            return nil
        }
    }
}
