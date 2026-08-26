import SwiftUI

/// Today Screen placeholder for Sprint 2.
/// Real editor UI arrives in Sprint 3. Currently hosts the temporary Sprint 2
/// File I/O harness and the Folder Health sheet.
struct TodayView: View {
    @Environment(FolderAccessService.self) private var folderAccessService
    @State private var showingFolderHealth = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Today Screen")
                .font(.largeTitle)
                .bold()

            if let url = folderAccessService.currentFolderURL {
                Text("Connected to: \(url.lastPathComponent)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // SPRINT 2 TEMPORARY HARNESS — removed/replaced in Sprint 3.
            FileIOHarnessView()

            Spacer()

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
        .padding(24)
        .sheet(isPresented: $showingFolderHealth) {
            FolderHealthView()
        }
    }
}
