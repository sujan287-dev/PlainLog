import SwiftUI
import UIKit

/// SPRINT 2 TEMPORARY HARNESS — replaced by the real editor + DocumentStore
/// in Sprint 3. Exercises the Sprint 2 safety modals (conflict, iCloud download,
/// save error) against the real FileIOService so the flows are demonstrable.
///
/// Modal copy is VERBATIM from PLAN.md Features 06, 07, 08. Do not paraphrase.
struct FileIOHarnessView: View {
    @Environment(FolderAccessService.self) private var folderAccess
    @State private var io = FileIOService()

    // Session state (simulates the editor's in-memory text + snapshot).
    @State private var currentText = ""
    @State private var snapshot: FileSnapshot?
    @State private var statusMessage = "Harness ready."

    // Modal triggers.
    @State private var showConflict = false
    @State private var showSaveError = false
    @State private var showICloudDownload = false

    private var todayURL: URL? {
        guard let folder = folderAccess.currentFolderURL else { return nil }
        return DailyFilename(date: Date()).url(in: folder)
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Sprint 2 File I/O Harness")
                .font(.headline)
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open today's file") { openToday() }
            Button("Simulate external edit") { simulateExternalEdit() }
            Button("Simulate save failure") { showSaveError = true }
            Button("Simulate iCloud download needed") { showICloudDownload = true }
        }
        .buttonStyle(.bordered)
        .padding()
        // Conflict modal — Feature 08 (verbatim copy)
        .alert("This file changed outside PlainLog", isPresented: $showConflict) {
            Button("Reload") { reloadFile() }
            Button("Save as copy") { saveAsCopyAction() }
        } message: {
            Text("You have unsaved edits.\nReload the file, or save your edits as a copy.")
        }
        // Save error modal — Feature 06 (verbatim copy)
        .alert("PlainLog could not save this file", isPresented: $showSaveError) {
            Button("Retry") { retrySave() }
            Button("Copy current text") { copyCurrentText() }
        } message: {
            Text("Your current edits are still in memory.\nTry saving again or copy your text.")
        }
        // iCloud download UI — Feature 07 (verbatim copy)
        .alert("Fetching today\u{2019}s file from iCloud", isPresented: $showICloudDownload) {
            Button("Retry") { retryICloudDownload() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("PlainLog is waiting for iCloud Drive to download today\u{2019}s file.")
        }
    }

    // MARK: - Harness actions

    private func openToday() {
        guard let folder = folderAccess.currentFolderURL else {
            statusMessage = "No folder connected."
            return
        }
        switch io.openDailyFile(for: Date(), in: folder) {
        case .loaded(let text, let snap):
            currentText = text
            snapshot = snap
            statusMessage = "Loaded today's file (\(text.count) chars)."
        case .pending:
            // Seed meaningful sample content so other scenarios have data to work with.
            currentText = "# Sample log\n- [ ] test task\n[tag:harness]"
            snapshot = nil
            statusMessage = "No file yet — seeded sample text (pending)."
        case .downloading:
            statusMessage = "File is downloading from iCloud."
        case .downloadFailed(let reason):
            statusMessage = "Download failed: \(reason)"
        case .loadFailed(let reason):
            statusMessage = "Load failed: \(reason)"
        }
    }

    private func simulateExternalEdit() {
        guard let url = todayURL else {
            statusMessage = "No file URL."
            return
        }
        do {
            // Ensure the file exists with the in-memory text, then snapshot it.
            try io.writeText(currentText.isEmpty ? "# harness seed" : currentText, to: url)
            snapshot = io.takeSnapshot(at: url)
            // Simulate an external writer changing the file behind our back.
            try io.writeText("EXTERNAL EDIT by another app", to: url)
            // Detect the change against our snapshot.
            if let snap = snapshot {
                let change = io.checkExternalChange(at: url, against: snap)
                if change == .modified {
                    statusMessage = "External change detected."
                    showConflict = true
                } else {
                    statusMessage = "No external change detected (\(change))."
                }
            }
        } catch {
            statusMessage = "simulateExternalEdit error: \(error)"
        }
    }

    private func reloadFile() {
        guard let folder = folderAccess.currentFolderURL else { return }
        if case .loaded(let text, let snap) = io.openDailyFile(for: Date(), in: folder) {
            currentText = text
            snapshot = snap
            statusMessage = "Reloaded from disk."
        }
    }

    private func saveAsCopyAction() {
        guard let folder = folderAccess.currentFolderURL else { return }
        do {
            let copyURL = try io.saveAsCopy(text: currentText, forSaveAt: Date(), in: folder)
            statusMessage = "Saved as copy: \(copyURL.lastPathComponent)"
        } catch {
            statusMessage = "saveAsCopy error: \(error)"
        }
    }

    private func retrySave() {
        guard let url = todayURL else { return }
        do {
            try io.writeText(currentText, to: url)
            snapshot = io.takeSnapshot(at: url)
            statusMessage = "Retry save succeeded."
        } catch {
            statusMessage = "Retry save failed: \(error)"
        }
    }

    private func copyCurrentText() {
        UIPasteboard.general.string = currentText
        statusMessage = "Copied current text to pasteboard."
    }

    private func retryICloudDownload() {
        guard let url = todayURL else { return }
        do {
            try io.requestCloudDownload(at: url)
            statusMessage = "Download requested."
        } catch {
            statusMessage = "Download request failed: \(error)"
        }
    }
}
