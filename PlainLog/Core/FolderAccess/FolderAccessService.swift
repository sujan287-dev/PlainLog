import Foundation
import Observation

@MainActor
@Observable
final class FolderAccessService {
    private let store: BookmarkStore
    private var currentSecurityScopedURL: URL?

    var state: FolderAccessState = .noFolderSelected

    // Read-only access to the current folder URL for other services
    var currentFolderURL: URL? {
        if case .folderReady(let url) = state { return url }
        return nil
    }

    init(store: BookmarkStore = UserDefaultsBookmarkStore()) {
        self.store = store
    }

    /// Call on app launch to restore access.
    func start() {
        guard let data = store.loadBookmarkData() else {
            state = .noFolderSelected
            return
        }

        state = .resolvingBookmark
        resolveBookmark(data: data, isStaleRefresh: false)
    }

    /// Call when the user selects a new folder (from UI, implemented in Piece 4).
    /// For now, this is a public API to be tested.
    func registerFolderAccess(url: URL) {
        // Stop access to previous folder if any
        stopAccessingCurrentFolder()

        do {
            // Create bookmark data
            // We use .minimalScope to keep it robust against moves/renames where possible,
            // but standard behavior is usually fine.
            let data = try url.bookmarkData(
                options: .minimalScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            store.saveBookmarkData(data)
            resolveBookmark(data: data, isStaleRefresh: false)
        } catch {
            Log.folderAccess.error("Failed to create bookmark: \(error.localizedDescription)")
            state = .accessLost(reason: "Could not save folder access.")
        }
    }

    func clearAccess() {
        stopAccessingCurrentFolder()
        store.clearBookmarkData()
        state = .noFolderSelected
    }

    // MARK: - Private Logic

    private func resolveBookmark(data: Data, isStaleRefresh: Bool) {
        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            Log.folderAccess.error("Bookmark resolution failed: \(error.localizedDescription)")
            store.clearBookmarkData() // Invalid bookmark, clear it to prevent loops
            state = .accessLost(reason: "Folder access expired.")
            return
        }

        // Security-scoped access start
        guard url.startAccessingSecurityScopedResource() else {
            Log.folderAccess.error("Failed to start security-scoped access.")
            state = .accessLost(reason: "Permission denied.")
            return
        }

        currentSecurityScopedURL = url

        if isStale {
            Log.folderAccess.info("Bookmark was stale. Refreshing...")
            do {
                let freshData = try url.bookmarkData(
                    options: .minimalScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                store.saveBookmarkData(freshData)
            } catch {
                // Access is already live for this session — only the persisted
                // bookmark failed to refresh. Do not treat this as access loss;
                // the next resolve attempt will simply see a stale bookmark again
                // and retry the refresh.
                Log.folderAccess.error("Failed to refresh stale bookmark: \(error.localizedDescription)")
            }
        }

        state = .folderReady(url: url)
        Log.folderAccess.info("Folder Ready: \(url.lastPathComponent)")
    }

    private func stopAccessingCurrentFolder() {
        if let url = currentSecurityScopedURL {
            url.stopAccessingSecurityScopedResource()
            currentSecurityScopedURL = nil
        }
    }

    deinit {
        // Safety net, though deinit on MainActor services is tricky.
        // The OS cleans up security scoped resources on app termination anyway.
    }
}
