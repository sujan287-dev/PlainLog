import SwiftUI

@main
struct PlainLogApp: App {
    @State private var folderAccessService = FolderAccessService()
    @State private var billingKit = BillingKit()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(folderAccessService)
                .environment(billingKit)
                .onAppear {
                    folderAccessService.start()
                }
                .task {
                    await billingKit.loadProducts()
                }
        }
    }
}
