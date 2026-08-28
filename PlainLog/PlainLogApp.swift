import SwiftUI

@main
struct PlainLogApp: App {
    @State private var folderAccessService = FolderAccessService()
    @State private var billingKit = BillingKit()
    @State private var appearanceSettings = AppearanceSettings()

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
            .onAppear {
                folderAccessService.start()
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
