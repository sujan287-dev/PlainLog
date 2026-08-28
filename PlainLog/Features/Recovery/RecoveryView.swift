import SwiftUI
import UniformTypeIdentifiers

/// Recovery screen shown when folder access is lost.
/// Variant is chosen by DocumentStore.isDirty (Piece 5.7): clean shows the
/// original "without unsaved edits" copy; dirty shows Feature 02's
/// "with unsaved edits" copy plus the reselection/existing-target-file
/// confirmation flows (Feature 02 requirements 6/10/11/12, Risks 4 and 5),
/// via the shared ReselectionFlowState (also used by FolderHealthView).
struct RecoveryView: View {
    @Environment(FolderAccessService.self) private var folderAccessService
    @Environment(DocumentStore.self) private var documentStore

    @State private var showingFileImporter = false
    @State private var reselectionFlow = ReselectionFlowState()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            if documentStore.isDirty {
                dirtyContent
            } else {
                cleanContent
            }

            // Show the specific reason if available (secondary detail)
            if let reason = accessLostReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            actionButtons

            Spacer()
        }
        .padding(32)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            reselectionFlow.handleFolderSelection(
                result,
                folderAccessService: folderAccessService,
                documentStore: documentStore
            )
        }
        .background(
            ReselectionWarningModal(
                isPresented: $reselectionFlow.showingReselectionWarning,
                saveToSelectedFolder: {
                    reselectionFlow.confirmReselectionWarning(
                        folderAccessService: folderAccessService,
                        documentStore: documentStore
                    )
                },
                copyText: { reselectionFlow.copyPreservedText() },
                cancel: { reselectionFlow.cancelPendingReselection() }
            )
        )
        .background(
            ExistingTargetFileWarningModal(
                isPresented: $reselectionFlow.showingExistingTargetFileWarning,
                saveAsCopy: {
                    Task {
                        await reselectionFlow.saveAsCopyIntoSelectedFolder(
                            folderAccessService: folderAccessService,
                            documentStore: documentStore
                        )
                    }
                },
                replaceExisting: {
                    Task {
                        await reselectionFlow.saveIntoSelectedFolder(
                            folderAccessService: folderAccessService,
                            documentStore: documentStore
                        )
                    }
                },
                cancel: { reselectionFlow.cancelPendingReselection() }
            )
        )
    }

    // MARK: - Variant content

    private var cleanContent: some View {
        VStack(spacing: 24) {
            Text("We lost access to your PlainLog folder")
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)

            Text("Please reconnect your folder to open your notes.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var dirtyContent: some View {
        VStack(spacing: 24) {
            Text(Feature02ModalCopy.recoveryWithEditsTitle)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)

            Text(Feature02ModalCopy.recoveryWithEditsBody)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button {
            showingFileImporter = true
        } label: {
            // Same text in both variants (Feature 02: both the "without" and
            // "with unsaved edits" copy blocks use the literal button label
            // "Choose folder").
            Text(Feature02ModalCopy.recoveryWithEditsChooseFolderButton)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        if documentStore.isDirty {
            Button {
                Clipboard.copy(documentStore.currentText)
            } label: {
                Text(Feature02ModalCopy.recoveryWithEditsCopyTextButton)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
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
}
