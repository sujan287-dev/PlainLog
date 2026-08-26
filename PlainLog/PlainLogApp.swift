import SwiftUI

@main
struct PlainLogApp: App {
    @State private var folderAccessService = FolderAccessService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(folderAccessService)
                .onAppear {
                    folderAccessService.start()
                }
        }
    }
}
