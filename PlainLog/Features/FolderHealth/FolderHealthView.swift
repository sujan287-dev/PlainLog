import SwiftUI
import UniformTypeIdentifiers

/// Folder Health screen per PLAN.md Feature 11 "Folder section."
/// Shows current folder, connection status, last save time, and reconnect action.
///
/// Reconnect is one of Feature 02's two reselection entry points (alongside
/// RecoveryView) — Piece 5.7 routes it through the same ReselectionFlowState
/// so the unsaved-edits confirmation flows can't diverge between the two.
struct FolderHealthView: View {
    @Environment(FolderAccessService.self) private var folderAccessService
    @Environment(DocumentStore.self) private var documentStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingFileImporter = false
    @State private var reselectionFlow = ReselectionFlowState()

    var body: some View {
        NavigationStack {
            List {
                // Folder section per PLAN.md Feature 11
                Section("Folder") {
                    LabeledContent("Current folder", value: folderName)
                    LabeledContent("Status", value: folderAccessService.statusDescription)
                    if folderAccessService.bookmarkNeedsRefresh {
                        LabeledContent("Needs reconnection", value: "Yes")
                    }
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
}
