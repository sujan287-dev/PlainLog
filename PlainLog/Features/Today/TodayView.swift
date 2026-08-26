import SwiftUI

/// Today Screen — Sprint 3 (PLAN.md IA; host for Feature 04).
/// Created only when folder state is .folderReady (RootView routing).
/// Owns the session's DocumentStore and loads today's file on appear.
struct TodayView: View {
    @Environment(FolderAccessService.self) private var folderAccessService
    @State private var documentStore = DocumentStore()

    var body: some View {
        Group {
            if let folder = folderAccessService.currentFolderURL {
                EditorView(store: documentStore)
                    // .task(id:) restarts the load if the connected folder
                    // changes (e.g. the user reconnects via Folder Health).
                    //
                    // KNOWN DEFERRAL: if unsaved edits exist when the folder
                    // changes, this reload discards them. Feature 02's
                    // reselection-warning copy will be wired when the recovery
                    // flow is integrated. Do not half-fix this here.
                    .task(id: folder) {
                        await documentStore.load(date: Date(), in: folder)
                    }
            } else {
                // FolderReady routing guarantees a folder; defensive fallback.
                Text("No folder connected.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
