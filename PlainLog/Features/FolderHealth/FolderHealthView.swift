import SwiftUI
import UniformTypeIdentifiers

/// Folder Health screen per PLAN.md Feature 11 "Folder section."
/// Shows current folder, connection status, last save time, and reconnect action.
struct FolderHealthView: View {
    @Environment(FolderAccessService.self) private var folderAccessService
    @Environment(\.dismiss) private var dismiss

    @State private var showingFileImporter = false

    var body: some View {
        NavigationStack {
            List {
                // Folder section per PLAN.md Feature 11
                Section("Folder") {
                    LabeledContent("Current folder", value: folderName)
                    LabeledContent("Status", value: folderAccessService.statusDescription)
                    LabeledContent("Last successful save", value: lastSaveText)
                }

                // Reconnect action
                Section {
                    Button("Reconnect folder") {
                        showingFileImporter = true
                    }
                    .foregroundStyle(.blue)
                }
            }
            .navigationTitle("Folder Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }

    // MARK: - Computed Properties

    /// Display the folder name from the private hint, falling back to
    /// the current URL's lastPathComponent, then "Unknown."
    private var folderName: String {
        if let hint = folderAccessService.folderDisplayNameHint {
            return hint
        }
        if let url = folderAccessService.currentFolderURL {
            return url.lastPathComponent
        }
        return "Unknown"
    }

    /// Last successful save time.
    /// Sprint 1: placeholder — FileIOService (Sprint 2) will provide real data.
    private var lastSaveText: String {
        // TODO(Sprint 2): Wire to FileIOService.lastSuccessfulSaveTime
        "—"
    }

    // MARK: - Reconnect Flow

    /// Reconnect uses the same flow as recovery (Feature 02 failure flow):
    /// select folder → registerFolderAccess → FolderReady. No confirmation screen.
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Log.folderAccess.info("Folder Health: user reconnected to '\(url.lastPathComponent)'")
            folderAccessService.registerFolderAccess(url: url)
            dismiss()

        case .failure(let error):
            Log.folderAccess.error("Folder Health reconnect error: \(error.localizedDescription)")
        }
    }
}
