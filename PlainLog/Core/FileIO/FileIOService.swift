import Foundation

/// FileIOService — Sprint 2 (PLAN.md §12).
///
/// Coordinated, atomic, iCloud-aware reads and writes for daily Markdown files.
///
/// Design rules (PLAN.md §4, §11):
/// - All reads/writes go through NSFileCoordinator.
/// - Writes are atomic (transient temp file + rename) — no remove-then-move
///   data-loss window, and no leftover temp files in the user folder.
/// - No shadow drafts. No hidden marker files. Ever.
/// - Cloud-only (evicted) iCloud items are NEVER read or overwritten:
///   the service throws .cloudOnlyFileNotDownloaded instead (Feature 07).
/// - UTF-8 only.
///
/// Threading contract: methods are synchronous. Callers MUST invoke them off
/// the main thread (Sprint 3's DocumentStore wraps calls in background Tasks).
/// Files are small and the eviction guard prevents network-blocking reads.
final class FileIOService {

    private let coordinator: NSFileCoordinator
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.coordinator = NSFileCoordinator(filePresenter: nil)
    }

    // MARK: - Read

    /// Reads a Markdown file as UTF-8 text via a coordinated read.
    /// - Throws: FileIOError.cloudOnlyFileNotDownloaded if the file is an
    ///   evicted iCloud item (callers must request download first — Feature 07).
    ///   This check MUST run before the existence check below: an evicted
    ///   iCloud item reports fileExists == false at its original path (it only
    ///   exists locally as a `.icloud` placeholder), so checking existence
    ///   first would misreport it as .fileNotFound and let a caller treat a
    ///   cloud-only file as "doesn't exist yet" — exactly the blind iCloud
    ///   file creation PLAN.md §4 forbids.
    /// - Throws: FileIOError.fileNotFound if the file does not exist.
    /// - Throws: FileIOError.encodingFailed if the content is not valid UTF-8.
    func readText(at url: URL) throws -> String {
        try refuseCloudOnlyFile(at: url)
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileIOError.fileNotFound
        }

        var coordinationError: NSError?
        var blockDidRun = false
        var text: String?
        var blockError: FileIOError?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            blockDidRun = true
            do {
                text = try String(contentsOf: coordinatedURL, encoding: .utf8)
            } catch let error as CocoaError where error.code == .fileReadInapplicableStringEncoding {
                // The file is readable but its bytes aren't valid UTF-8.
                blockError = .encodingFailed
            } catch {
                // Any other failure (permissions, disk error, etc.) is a
                // genuine I/O problem, not an encoding problem — don't
                // mislabel it as .encodingFailed.
                blockError = .underlying(error.localizedDescription)
            }
        }

        if let coordinationError {
            throw FileIOError.coordinationFailed(coordinationError.localizedDescription)
        }
        guard blockDidRun else {
            throw FileIOError.coordinationDidNotRun
        }
        if let blockError {
            throw blockError
        }
        guard let text else {
            throw FileIOError.encodingFailed
        }
        return text
    }

    // MARK: - Write

    /// Writes UTF-8 text via a coordinated, atomic write.
    /// Creates the file if it does not exist (the pending-new-file policy —
    /// "never create blank files" — is enforced by callers in Piece 2.2).
    /// - Throws: FileIOError.cloudOnlyFileNotDownloaded if the target is an
    ///   evicted iCloud item. Defense in depth: even if a caller forgets the
    ///   iCloud download check, this gate prevents blind cloud-file creation
    ///   (PLAN.md §4: "No blind iCloud file creation").
    func writeText(_ text: String, to url: URL) throws {
        try refuseCloudOnlyFile(at: url)

        let data = Data(text.utf8)

        var coordinationError: NSError?
        var blockDidRun = false
        var blockError: FileIOError?

        coordinator.coordinate(writingItemAt: url, options: [.forReplacing], error: &coordinationError) { coordinatedURL in
            blockDidRun = true
            do {
                // .atomic writes to a transient temp file and renames it into
                // place. The temp file exists for microseconds and never lingers
                // in the user folder (PLAN.md §11 temporary file policy).
                try data.write(to: coordinatedURL, options: [.atomic])
            } catch {
                blockError = .underlying(error.localizedDescription)
            }
        }

        if let coordinationError {
            throw FileIOError.coordinationFailed(coordinationError.localizedDescription)
        }
        guard blockDidRun else {
            throw FileIOError.coordinationDidNotRun
        }
        if let blockError {
            throw blockError
        }
    }

    // MARK: - Queries

    /// True if a file exists locally at this URL.
    /// Note: evicted iCloud items report false here — use ubiquitous state
    /// checks (Piece 2.4) when the folder may live in iCloud Drive.
    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    // MARK: - iCloud Safety Gate

    /// Refuses to touch evicted (cloud-only) iCloud items.
    /// Evicted files report fileExists == false, so this must be checked
    /// BEFORE existence-based branching in both read and write paths.
    private func refuseCloudOnlyFile(at url: URL) throws {
        guard isUbiquitousItem(at: url) else { return }
        if downloadStatus(at: url) == .notDownloaded {
            throw FileIOError.cloudOnlyFileNotDownloaded
        }
    }

    private func isUbiquitousItem(at url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem ?? false
    }

    private func downloadStatus(at url: URL) -> URLUbiquitousItemDownloadingStatus? {
        (try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?
            .ubiquitousItemDownloadingStatus
    }
}
