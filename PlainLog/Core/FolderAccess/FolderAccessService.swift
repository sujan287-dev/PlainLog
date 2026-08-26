import Foundation
import Observation

@MainActor
@Observable
final class FolderAccessService {
    private static let displayNameKey = "plainlog.folder.displayNameHint"

    private let store: BookmarkStore
    private var currentSecurityScopedURL: URL?

    var state: FolderAccessState = .noFolderSelected

    /// True when the current session's bookmark was found stale and the
    /// automatic refresh failed. Access is still live for this session (via
    /// currentSecurityScopedURL) — this does not interrupt the user, it's
    /// surfaced non-blockingly on the Folder Health screen so they can
    /// reconnect before the next cold launch, when a still-stale bookmark
    /// would fail to resolve at all.
    private(set) var bookmarkNeedsRefresh: Bool = false

    // Read-only access to the current folder URL for other services
    var currentFolderURL: URL? {
        if case .folderReady(let url) = state { return url }
        return nil
    }

    /// Human-readable status description for the Folder Health screen.
    /// Maps FolderAccessState to user-facing text per PLAN.md Feature 11.
    var statusDescription: String {
        switch state {
        case .folderReady:       return "Connected"
        case .noFolderSelected:  return "No folder selected"
        case .resolvingBookmark: return "Connecting…"
        case .bookmarkStale:     return "Needs reconnection"
        case .accessLost:        return "Access lost"
        case .folderUnwritable:  return "Folder unwritable"
        }
    }

    /// The last known display name of the user's folder.
    /// Stored privately in UserDefaults — never in the user's folder.
    var folderDisplayNameHint: String? {
        UserDefaults.standard.string(forKey: Self.displayNameKey)
    }

    init(store: BookmarkStore = UserDefaultsBookmarkStore()) {
        self.store = store
    }

    /// Call once on app launch to restore access.
    ///
    /// Guarded to a single call from `.noFolderSelected`: SwiftUI's `onAppear`
    /// can fire more than once for a view in some lifecycle/navigation cases,
    /// and re-resolving here would call `startAccessingSecurityScopedResource()`
    /// again without a balancing `stop` for the previous resolve, leaking
    /// security-scoped access.
    func start() {
        guard case .noFolderSelected = state else { return }

        guard let data = store.loadBookmarkData() else {
            state = .noFolderSelected
            return
        }

        state = .resolvingBookmark
        resolveBookmark(data: data, isStaleRefresh: false)
    }

    /// Call when the user selects a new folder (from the onboarding folder picker).
    func registerFolderAccess(url: URL) {
        // Stop access to previous folder if any
        stopAccessingCurrentFolder()

        // Save display name hint (private, never in user folder)
        saveDisplayNameHint(url.lastPathComponent)

        // We need security-scoped access to create a bookmark from the URL.
        // The URL from .fileImporter is security-scoped but we must call
        // startAccessingSecurityScopedResource() before bookmarkData().
        let didAccess = url.startAccessingSecurityScopedResource()

        do {
            // .minimalBookmark keeps the bookmark small (no Finder display
            // metadata) — the only relevant creation option on iOS; the
            // security-scope options in this enum are macOS-only.
            let data = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            store.saveBookmarkData(data)

            // Stop the temporary access used for bookmark creation.
            // resolveBookmark will re-establish access via the resolved URL.
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }

            resolveBookmark(data: data, isStaleRefresh: false)
        } catch {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
            Log.folderAccess.error("Failed to create bookmark: \(error.localizedDescription)")
            state = .accessLost(reason: "Could not save folder access.")
        }
    }

    func clearAccess() {
        stopAccessingCurrentFolder()
        store.clearBookmarkData()
        UserDefaults.standard.removeObject(forKey: Self.displayNameKey)
        state = .noFolderSelected
    }

    /// Reports that the current folder can no longer be written to (e.g. a
    /// save failed with a permission-type error). Routes to the recovery
    /// flow — RootView already handles .folderUnwritable — so the user can
    /// pick a working folder. Keeps the existing bookmark on disk: it may
    /// still resolve fine, and RecoveryView's flow overwrites it with a
    /// fresh one as soon as the user picks a new folder anyway.
    func reportUnwritableFolder(reason: String) {
        stopAccessingCurrentFolder()
        state = .folderUnwritable(reason: reason)
    }

    /// Best-effort detection of whether a folder is in iCloud Drive.
    /// Returns false if detection fails (fail open — don't block onboarding).
    static func isICloudFolder(url: URL) -> Bool {
        // Check resource value first
        do {
            let values = try url.resourceValues(forKeys: [.isUbiquitousItemKey])
            if let isUbiquitous = values.isUbiquitousItem, isUbiquitous {
                return true
            }
        } catch {
            // Fall through to path heuristic
        }

        // Path heuristic as fallback
        let path = url.path.lowercased()
        return path.contains("mobile documents") || path.contains("clouddocs")
    }

    /// Check if the folder already contains Markdown files.
    /// Returns false if the folder cannot be read (fail open).
    static func hasExistingMarkdownFiles(in url: URL) -> Bool {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            return contents.contains { $0.pathExtension.lowercased() == "md" }
        } catch {
            Log.folderAccess.error("Could not check for existing files: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Logic

    private func saveDisplayNameHint(_ name: String) {
        UserDefaults.standard.set(name, forKey: Self.displayNameKey)
    }

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
        bookmarkNeedsRefresh = false

        if isStale {
            Log.folderAccess.info("Bookmark was stale. Refreshing...")
            do {
                let freshData = try url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                store.saveBookmarkData(freshData)
            } catch {
                // Access is already live for this session — only the persisted
                // bookmark failed to refresh. Do not treat this as access loss;
                // the next resolve attempt will simply see a stale bookmark again
                // and retry the refresh. Surface it non-blockingly instead.
                Log.folderAccess.error("Failed to refresh stale bookmark: \(error.localizedDescription)")
                bookmarkNeedsRefresh = true
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
