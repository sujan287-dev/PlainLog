import SwiftUI

/// Today Screen placeholder for Sprint 1.
/// Real editor UI arrives in Sprint 3.
/// Includes a Folder Health button to access the folder status screen.
struct TodayView: View {
    @Environment(FolderAccessService.self) private var folderAccessService
    @State private var showingFolderHealth = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Today Screen")
                .font(.largeTitle)
                .bold()

            if let url = folderAccessService.currentFolderURL {
                Text("Connected to:\n\(url.lastPathComponent)")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Text("Editor coming in Sprint 3.")
                .foregroundStyle(.tertiary)

            Spacer()

            // Folder Health access button
            Button {
                showingFolderHealth = true
            } label: {
                Label("Folder Health", systemImage: "folder.badge.questionmark")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(32)
        .sheet(isPresented: $showingFolderHealth) {
            FolderHealthView()
        }
    }
}
