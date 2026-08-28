import Foundation
import Observation

/// Shared folder-reselection flow state (Feature 02) — owned as local
/// @State by each of the two reselection entry points (RecoveryView,
/// FolderHealthView) so their confirmation logic can't silently diverge.
/// Not injected into the app-wide environment: this is transient per-
/// presentation UI flow state, not a persisted service.
///
/// Orchestration itself is delegated to ReselectionCoordinator (pure
/// composition of FolderAccessService's/DocumentStore's existing public
/// API); this class only tracks what's pending and which modal, if any,
/// is showing.
@MainActor
@Observable
final class ReselectionFlowState {

    private(set) var pendingReselectionURL: URL?
    private(set) var pendingRequirement: ReselectionRequirement = []
    private(set) var preservedText: String = ""

    var showingReselectionWarning = false
    var showingExistingTargetFileWarning = false

    /// Entry point: call from a fileImporter's completion handler.
    func handleFolderSelection(
        _ result: Result<[URL], Error>,
        folderAccessService: FolderAccessService,
        documentStore: DocumentStore
    ) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Log.folderAccess.info("Reselection: user picked folder '\(url.lastPathComponent)'")
            evaluateAndProceed(with: url, folderAccessService: folderAccessService, documentStore: documentStore)

        case .failure(let error):
            Log.folderAccess.error("Folder reselection picker error: \(error.localizedDescription)")
        }
    }

    private func evaluateAndProceed(
        with url: URL,
        folderAccessService: FolderAccessService,
        documentStore: DocumentStore
    ) {
        guard documentStore.isDirty else {
            folderAccessService.registerFolderAccess(url: url)
            return
        }

        let nameMatches = folderAccessService.folderDisplayNameHint == url.lastPathComponent
        let todayExists = ReselectionCoordinator.todayFileExists(in: url)
        let requirement = ReselectionGuard.evaluate(
            isDirty: true,
            folderNameMatchesHint: nameMatches,
            todayFileExistsInTarget: todayExists
        )

        pendingReselectionURL = url
        pendingRequirement = requirement
        preservedText = documentStore.currentText

        // Ordering: reselection warning (is this even the right folder?)
        // resolves before existing-target-file warning (is it safe to write
        // into it?) — see ReselectionGuard's doc comment. Neither applies:
        // dirty but name matches and no existing file, so save straight
        // through without interrupting the user.
        if requirement.contains(.reselectionWarning) {
            showingReselectionWarning = true
        } else if requirement.contains(.existingTargetFileWarning) {
            showingExistingTargetFileWarning = true
        } else {
            Task {
                await self.saveIntoSelectedFolder(folderAccessService: folderAccessService, documentStore: documentStore)
            }
        }
    }

    /// Reselection warning's "Save to selected folder": chain into the
    /// existing-target-file warning if that ALSO applied to this pick,
    /// otherwise save straight through.
    func confirmReselectionWarning(folderAccessService: FolderAccessService, documentStore: DocumentStore) {
        if pendingRequirement.contains(.existingTargetFileWarning) {
            showingExistingTargetFileWarning = true
        } else {
            Task {
                await saveIntoSelectedFolder(folderAccessService: folderAccessService, documentStore: documentStore)
            }
        }
    }

    func copyPreservedText() {
        Clipboard.copy(preservedText)
    }

    func cancelPendingReselection() {
        pendingReselectionURL = nil
        pendingRequirement = []
        preservedText = ""
    }

    /// "Save to selected folder" / the no-warning-needed automatic path /
    /// "Replace existing file" — all three want the reselected folder to end
    /// up holding the preserved draft.
    func saveIntoSelectedFolder(folderAccessService: FolderAccessService, documentStore: DocumentStore) async {
        guard let url = pendingReselectionURL else { return }
        await ReselectionCoordinator.saveIntoReselectedFolder(
            preservedText: preservedText,
            folder: url,
            folderAccessService: folderAccessService,
            documentStore: documentStore
        )
        cancelPendingReselection()
    }

    func saveAsCopyIntoSelectedFolder(folderAccessService: FolderAccessService, documentStore: DocumentStore) async {
        guard let url = pendingReselectionURL else { return }
        await ReselectionCoordinator.saveAsCopyIntoReselectedFolder(
            preservedText: preservedText,
            folder: url,
            folderAccessService: folderAccessService,
            documentStore: documentStore
        )
        cancelPendingReselection()
    }
}
