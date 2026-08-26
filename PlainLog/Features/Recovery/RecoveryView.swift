import SwiftUI
import UniformTypeIdentifiers

/// Recovery screen shown when folder access is lost.
/// Displays the "without unsaved edits" variant per PLAN.md Feature 02.
/// The "with unsaved edits" variant (with Copy current text button)
/// will be added in Sprint 3 when the editor exists.
struct RecoveryView: View {
    @Environment(FolderAccessService.self) private var folderAccessService

    @State private var showingFileImporter = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("We lost access to your PlainLog folder")
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)

            Text("Please reconnect your folder to open your notes.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Show the specific reason if available (secondary detail)
            if let reason = accessLostReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Button {
                showingFileImporter = true
            } label: {
                Text("Choose folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(32)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }

    // MARK: - Helpers

    /// Extract the reason string from the current state, if applicable.
    private var accessLostReason: String? {
        switch folderAccessService.state {
        case .accessLost(let reason):
            return reason
        case .folderUnwritable(let reason):
            return reason
        default:
            return nil
        }
    }

    /// Handle folder reselection. Per PLAN.md Feature 02 failure flow:
    /// User selects folder → Save new bookmark → Enter FolderReady.
    /// No confirmation screen in the recovery flow (unlike onboarding).
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Log.folderAccess.info("Recovery: user reselected folder '\(url.lastPathComponent)'")
            folderAccessService.registerFolderAccess(url: url)

        case .failure(let error):
            Log.folderAccess.error("Recovery folder picker error: \(error.localizedDescription)")
        }
    }
}
