import SwiftUI

@main
struct PlainLogApp: App {
    // iOS 17+ @Observable pattern
    @State private var folderAccessService = FolderAccessService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(folderAccessService)
                .onAppear {
                    // Trigger bookmark resolution on launch
                    folderAccessService.start()
                }
        }
    }
}
