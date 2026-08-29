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
                // Re-check the iCloud gate on the coordinated URL, right
                // before the read. The pre-check above can race with iCloud
                // eviction in the gap before this block runs; NSFileCoordinator
                // serializes against iCloud's own coordination, so re-asserting
                // here on the coordinated URL closes that gap rather than
                // just narrowing it.
                try refuseCloudOnlyFile(at: coordinatedURL)
                text = try String(contentsOf: coordinatedURL, encoding: .utf8)
            } catch let error as FileIOError {
                blockError = error
            } catch let error as CocoaError where error.code == .fileReadCorruptFile
                || error.code == .fileReadInapplicableStringEncoding {
                // The file is readable but its bytes aren't valid UTF-8.
                // Foundation has been observed to throw .fileReadCorruptFile
                // for this specific failure via String(contentsOf:encoding:);
                // .fileReadInapplicableStringEncoding is kept as a fallback
                // since this isn't documented, verifiable behavior.
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
                // Re-check the iCloud gate on the coordinated URL, right
                // before the write. See the matching comment in readText(at:)
                // — same reasoning, write side.
                try refuseCloudOnlyFile(at: coordinatedURL)
                // .atomic writes to a transient temp file and renames it into
                // place. The temp file exists for microseconds and never lingers
                // in the user folder (PLAN.md §11 temporary file policy).
                try data.write(to: coordinatedURL, options: [.atomic])
            } catch let error as FileIOError {
                blockError = error
            } catch let error as CocoaError where error.code == .fileWriteNoPermission
                || error.code == .fileWriteVolumeReadOnly {
                // Bugfix (L1): distinguish "this destination isn't
                // writable" from a generic I/O failure, so callers can
                // route it to the folder-reconnection recovery flow
                // (FolderAccessService.reportUnwritableFolder) instead of a
                // plain retry-worthy save error.
                blockError = .permissionDenied(error.localizedDescription)
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

    // MARK: - Open Orchestration

    /// Opens a daily file for the given date in the specified folder.
    /// Returns the file state without creating any files.
    ///
    /// Orchestrates the Feature 03 flow:
    /// 1. Build filename: YYYY-MM-DD.md (local timezone)
    /// 2. Check iCloud state via iCloudState(at:) (MUST happen before the
    ///    existence check: an evicted iCloud item reports fileExists == false
    ///    at its real path, so checking existence first would misreport a
    ///    cloud-only file as .pending — "doesn't exist yet, safe to create"
    ///    — instead of .downloading, exactly the blind iCloud duplicate
    ///    creation PLAN.md §4/Feature 07 forbid. Same class of bug fixed in
    ///    readText(at:) in Piece 2.1.)
    /// 3. If cloud-only or actively downloading: return .downloading
    /// 4. Check if file exists locally
    ///    - If exists: load via readText(at:)
    ///    - If not exists: return .pending (no file creation)
    ///
    /// This method is synchronous. Callers must invoke it off the main thread.
    func openDailyFile(for date: Date, in folder: URL) -> DailyFileState {
        let dailyFilename = DailyFilename(date: date)
        let fileURL = dailyFilename.url(in: folder)

        // iCloud gate FIRST. Evicted files report fileExists == false, so this
        // must run before any existence-based branching (Pieces 2.1/2.2 fix).
        switch iCloudState(at: fileURL) {
        case .cloudOnly, .downloading:
            return .downloading
        case .notICloud, .localReady, .downloadFailed:
            break
        }

        // File does not exist locally. Per Feature 03 pending-new-file
        // policy: show empty editor but do NOT create the file yet.
        guard fileExists(at: fileURL) else {
            return .pending
        }

        // File exists and is locally available. Attempt to load.
        do {
            let text = try readText(at: fileURL)
            let snapshot = takeSnapshot(at: fileURL)
            return .loaded(text: text, snapshot: snapshot)
        } catch FileIOError.cloudOnlyFileNotDownloaded {
            // Edge case: the iCloudState check above missed it, but
            // readText's own gate caught it.
            return .downloading
        } catch FileIOError.fileNotFound {
            // Edge case: file existed at check time but was deleted before read.
            // Treat as pending (file no longer exists).
            return .pending
        } catch FileIOError.encodingFailed {
            return .loadFailed(reason: "File is not valid UTF-8")
        } catch FileIOError.coordinationFailed(let message) {
            return .loadFailed(reason: "Could not access file: \(message)")
        } catch FileIOError.coordinationDidNotRun {
            return .loadFailed(reason: "File access coordination failed")
        } catch FileIOError.underlying(let message) {
            return .loadFailed(reason: "File system error: \(message)")
        } catch {
            return .loadFailed(reason: "Unexpected error: \(error.localizedDescription)")
        }
    }

    // MARK: - Save as Copy (Feature 08)

    /// Saves the given text as a conflict copy in the folder (Feature 08).
    /// Generates a non-colliding copy name, then writes via the same coordinated,
    /// atomic, cloud-gated writeText path. Returns the new file URL.
    ///
    /// `calendar` is injectable for deterministic tests; production passes nil
    /// to use Gregorian + device local timezone (consistent with DailyFilename).
    func saveAsCopy(
        text: String,
        forSaveAt saveMoment: Date,
        in folder: URL,
        calendar: Calendar? = nil
    ) throws -> URL {
        let cal = calendar ?? Self.gregorianLocalCalendar()
        let existingNames = listFilenames(in: folder, reservingICloudPlaceholders: true)
        let copyName = ConflictCopyNamer.nextCopyName(
            forSaveAt: saveMoment,
            existingNames: existingNames,
            calendar: cal
        )
        let copyURL = folder.appendingPathComponent(copyName)
        try writeText(text, to: copyURL)
        return copyURL
    }

    /// Lists filenames in the folder. When `reservingICloudPlaceholders` is true,
    /// an evicted iCloud placeholder also reserves its base name, so we never
    /// collide with a cloud-only file's real name.
    ///
    /// A placeholder's real-world filename is `.<original>.icloud` — a leading
    /// dot AND the trailing suffix — not just the trailing suffix, so both are
    /// stripped when computing the reserved base name.
    private func listFilenames(in folder: URL, reservingICloudPlaceholders: Bool) -> Set<String> {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: []
        ) else {
            return []
        }
        var names = Set<String>()
        for url in contents {
            let name = url.lastPathComponent
            names.insert(name)
            if reservingICloudPlaceholders, name.hasSuffix(".icloud") {
                var base = String(name.dropLast(".icloud".count))
                if base.hasPrefix(".") {
                    base.removeFirst()
                }
                names.insert(base)
            }
        }
        return names
    }

    private static func gregorianLocalCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }

    // MARK: - External Change Detection (Feature 08)

    /// Captures a snapshot of the file's current state.
    /// Returns nil if the file does not exist.
    func takeSnapshot(at url: URL) -> FileSnapshot? {
        FileSnapshot.capture(at: url, fileManager: fileManager)
    }

    /// Checks if the file has changed externally since the snapshot was taken.
    ///
    /// Important: An evicted iCloud file (cloud-only, not downloaded) reports
    /// fileExists == false locally, but it is NOT deleted — it still exists in
    /// iCloud. We must check ubiquitous state before declaring deletion.
    ///
    /// - Returns: .unchanged, .modified, or .deleted
    func checkExternalChange(at url: URL, against snapshot: FileSnapshot) -> ExternalChangeResult {
        // Check if file still exists locally
        let existsLocally = fileExists(at: url)

        if !existsLocally {
            // File does not exist locally. But is it truly deleted, or just
            // evicted from iCloud? An evicted iCloud file still exists in the
            // cloud but not locally.
            if isUbiquitousItem(at: url) {
                // It's an iCloud item that's not downloaded. This is NOT deletion —
                // the file still exists in iCloud. Treat as unchanged for now;
                // the caller should trigger the iCloud download flow.
                // We return .unchanged because the file hasn't been deleted,
                // just evicted. The caller will handle the download flow separately.
                return .unchanged
            } else {
                // Not an iCloud item, and file doesn't exist. Truly deleted.
                return .deleted
            }
        }

        // File exists locally. Compare modification date and size.
        let currentSnapshot = takeSnapshot(at: url)

        guard let current = currentSnapshot else {
            // Could not read current attributes. Treat as modified to be safe.
            return .modified
        }

        // Compare modification dates
        if let snapshotDate = snapshot.modificationDate,
           let currentDate = current.modificationDate {
            if snapshotDate != currentDate {
                return .modified
            }
        } else if snapshot.modificationDate != current.modificationDate {
            // One is nil, the other is not
            return .modified
        }

        // Compare file sizes
        if snapshot.fileSize != current.fileSize {
            return .modified
        }

        return .unchanged
    }

    // MARK: - iCloud State & Download (Feature 07)

    /// Reads the current iCloud state of the item at this URL.
    /// Fail-open for ordinary local files: any resource-value read failure on a
    /// non-ubiquitous item yields .notICloud so local folders are never blocked.
    func iCloudState(at url: URL) -> ICloudFileState {
        let isUbiquitous = isUbiquitousItem(at: url)
        let status = downloadStatus(at: url)
        return ICloudFileState.mapping(isUbiquitous: isUbiquitous, downloadStatus: status)
    }

    /// Requests that iCloud download the item to local storage.
    /// - Throws: FileIOError.downloadRequestFailed if the item is not a
    ///   ubiquitous item or the system refuses the request. Callers must only
    ///   invoke this for items whose iCloudState is .cloudOnly.
    func requestCloudDownload(at url: URL) throws {
        do {
            try fileManager.startDownloadingUbiquitousItem(at: url)
        } catch {
            throw FileIOError.downloadRequestFailed(error.localizedDescription)
        }
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

// MARK: - Concurrency

/// FileIOService carries no mutable state; NSFileCoordinator and FileManager
/// are both safe to use from any thread. @unchecked Sendable lets
/// DocumentStore dispatch file I/O to background tasks (Sprint 3 threading
/// contract, CLAUDE.md) without concurrency warnings.
extension FileIOService: @unchecked Sendable {}
