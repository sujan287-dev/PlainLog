import SwiftUI

/// Today Screen — Sprint 3 (PLAN.md IA; host for Feature 04).
/// Created only when folder state is .folderReady (RootView routing).
/// Loads today's file on appear and triggers save-on-background (Feature 06).
/// DocumentStore itself lives in PlainLogApp's environment (Piece 5.7) rather
/// than being owned here — it must survive TodayView being unmounted when
/// folder access is lost, so RecoveryView can still see unsaved edits.
struct TodayView: View {
    @Environment(FolderAccessService.self) private var folderAccessService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DocumentStore.self) private var documentStore

    var body: some View {
        Group {
            if let folder = folderAccessService.currentFolderURL {
                EditorView(store: documentStore)
                    .task(id: folder) {
                        await documentStore.load(date: Date(), in: folder)
                    }
                    // Feature 06: save when app moves to background.
                    .onChange(of: scenePhase) { oldPhase, newPhase in
                        if newPhase == .background {
                            Task {
                                await documentStore.saveNow()
                            }
                        }
                    }
            } else {
                Text("No folder connected.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
