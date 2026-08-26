import SwiftUI
import UniformTypeIdentifiers

struct WelcomeView: View {
    @Environment(FolderAccessService.self) private var folderAccessService

    @State private var showingFileImporter = false
    @State private var selectedFolderURL: URL?
    @State private var isICloudFolder = false
    @State private var hasExistingMarkdownFiles = false
    @State private var showingConfirmation = false

    var body: some View {
        Group {
            if showingConfirmation, let url = selectedFolderURL {
                FolderConfirmationView(
                    folderURL: url,
                    isICloudFolder: isICloudFolder,
                    hasExistingFiles: hasExistingMarkdownFiles,
                    onConfirm: {
                        folderAccessService.registerFolderAccess(url: url)
                    },
                    onChooseDifferent: {
                        showingConfirmation = false
                        selectedFolderURL = nil
                        showingFileImporter = true
                    }
                )
            } else {
                welcomeContent
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

    // MARK: - Welcome Content

    private var welcomeContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.text")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("Welcome to PlainLog")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)

            Text("Your life as plain files.\nOne Markdown file per day.\nNo account. No database. No lock-in.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                showingFileImporter = true
            } label: {
                Text("Choose your PlainLog folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Tip: You can create a new folder in the Files app before selecting.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Folder Selection Handler

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start security-scoped access to inspect the folder
            let didAccess = url.startAccessingSecurityScopedResource()

            // Detect iCloud (best-effort)
            isICloudFolder = FolderAccessService.isICloudFolder(url: url)

            // Check for existing Markdown files
            hasExistingMarkdownFiles = FolderAccessService.hasExistingMarkdownFiles(in: url)

            // Stop inspection access. registerFolderAccess will re-establish
            // access when the user confirms.
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }

            selectedFolderURL = url
            showingConfirmation = true

        case .failure(let error):
            // User cancelled or an error occurred.
            // Don't show an alert for cancellation — just stay on welcome.
            Log.folderAccess.error("Folder picker error: \(error.localizedDescription)")
        }
    }
}
