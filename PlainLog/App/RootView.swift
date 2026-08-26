import SwiftUI

struct RootView: View {
    @Environment(FolderAccessService.self) private var folderAccessService

    var body: some View {
        switch folderAccessService.state {
        case .noFolderSelected:
            WelcomeView()

        case .resolvingBookmark:
            ProgressView("Accessing your folder...")
                .controlSize(.large)

        case .folderReady:
            TodayView()

        case .bookmarkStale, .accessLost, .folderUnwritable:
            RecoveryView()
        }
    }
}
