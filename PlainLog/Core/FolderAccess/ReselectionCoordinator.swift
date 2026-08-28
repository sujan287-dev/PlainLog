import Foundation

/// ReselectionCoordinator — Sprint 5 · Piece 5.7 (PLAN.md Feature 02).
/// Orchestrates a folder reselection once the user has picked a new folder
/// and (if ReselectionGuard required it) confirmed past any warning.
/// Composed entirely from FolderAccessService's and DocumentStore's EXISTING
/// public API — neither file is modified by this piece.
@MainActor
enum ReselectionCoordinator {

    /// Checks whether today's daily file already exists in `folder`, without
    /// establishing any lasting access — brackets the check in a matched
    /// start/stop of security-scoped access on the freshly-picked (not yet
    /// bookmarked) URL, mirroring FolderAccessService.registerFolderAccess's
    /// own handling of a fileImporter result.
    static func todayFileExists(in folder: URL, calendar: Calendar = .current) -> Bool {
        let didAccess = folder.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                folder.stopAccessingSecurityScopedResource()
            }
        }
        let url = DailyFilename(date: Date(), calendar: calendar).url(in: folder)
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Switches access to `folder`, loads it as the active document, then
    /// re-applies `preservedText` as the current (dirty) draft and saves it
    /// — "save my current edits into the newly selected folder." Used for
    /// both the no-warning-needed automatic path and the "Save to selected
    /// folder" / "Replace existing file" confirmations (all three want the
    /// same outcome: the reselected folder ends up holding preservedText).
    static func saveIntoReselectedFolder(
        preservedText: String,
        folder: URL,
        folderAccessService: FolderAccessService,
        documentStore: DocumentStore
    ) async {
        folderAccessService.registerFolderAccess(url: folder)
        await documentStore.load(date: Date(), in: folder)
        documentStore.updateText(preservedText)
        await documentStore.saveNow()
    }

    /// Same switch-and-load as above, but saves the preserved text as a
    /// COPY (via DocumentStore's existing saveAsCopy(), unmodified) rather
    /// than overwriting today's existing file — "Save as copy".
    static func saveAsCopyIntoReselectedFolder(
        preservedText: String,
        folder: URL,
        folderAccessService: FolderAccessService,
        documentStore: DocumentStore
    ) async {
        folderAccessService.registerFolderAccess(url: folder)
        await documentStore.load(date: Date(), in: folder)
        documentStore.updateText(preservedText)
        do {
            _ = try await documentStore.saveAsCopy()
        } catch {
            Log.folderAccess.error("Reselection save-as-copy failed: \(error.localizedDescription)")
        }
    }
}
