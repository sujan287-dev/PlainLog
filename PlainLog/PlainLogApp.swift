import SwiftUI

@main
struct PlainLogApp: App {
    @State private var folderAccessService = FolderAccessService()
    @State private var billingKit = BillingKit()
    @State private var appearanceSettings = AppearanceSettings()
    @State private var summaryDisplaySettings = SummaryDisplaySettings()
    // Lifted from TodayView in Piece 5.7: RootView shows RecoveryView instead
    // of TodayView whenever folder access isn't .folderReady, which would
    // unmount (and deallocate) a TodayView-owned DocumentStore the instant
    // access is lost — losing any in-memory unsaved edits before RecoveryView
    // could ever read them. Owning it here lets it survive that transition.
    // DocumentStore.swift itself is unchanged; only where it's created moved.
    @State private var documentStore = DocumentStore()
    @State private var connectivityMonitor = ConnectivityMonitor()

    var body: some Scene {
        WindowGroup {
            // Sepia has no standard ColorScheme (see AppearanceSettings.colorScheme),
            // so its background/foreground/tint apply here as a best-effort root
            // override, applied only when active — System/Light/Dark are left to
            // .preferredColorScheme below, and existing views' own semantic colors
            // are never touched (Piece 5.4 scope: no view refactors).
            Group {
                if appearanceSettings.isSepia {
                    RootView()
                        .background(appearanceSettings.sepiaBackground)
                        .foregroundStyle(appearanceSettings.sepiaForeground)
                        .tint(appearanceSettings.sepiaForeground)
                } else {
                    RootView()
                }
            }
            .environment(folderAccessService)
            .environment(billingKit)
            .environment(appearanceSettings)
            .environment(summaryDisplaySettings)
            .environment(documentStore)
            .environment(connectivityMonitor)
            .onAppear {
                folderAccessService.start()
                // Bugfix (L1, full-codebase audit): wire the previously-
                // unreachable .folderUnwritable recovery flow — a
                // permission-denied save now routes here instead of only
                // ever surfacing as a generic save-error message.
                documentStore.onUnwritableFolder = { reason in
                    folderAccessService.reportUnwritableFolder(reason: reason)
                }
            }
            .task {
                await billingKit.loadProducts()
            }
            .preferredColorScheme(appearanceSettings.colorScheme)
            .fontDesign(appearanceSettings.font == .monospaced ? .monospaced : .default)
            .dynamicTypeSize(appearanceSettings.dynamicTypeSize)
        }
    }
}
