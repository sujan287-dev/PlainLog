import SwiftUI

struct TodayView: View {
    @Environment(FolderAccessService.self) private var folderAccessService

    var body: some View {
        VStack(spacing: 20) {
            Text("Today Screen")
                .font(.largeTitle).bold()

            if let url = folderAccessService.currentFolderURL {
                Text("Connected to:\n\(url.lastPathComponent)")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Text("Editor coming in Sprint 3.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
