import SwiftUI

/// Editor Pane — Sprint 3 (PLAN.md Feature 04).
/// Raw Markdown editing via SwiftUI TextEditor only (spec §4: no custom
/// UITextView in v1, no live syntax highlighting).
/// Autosave arrives in Piece 3.3, Preview in Piece 3.4, date navigation
/// in Sprint 4. The folder-health button moves into Settings (Feature 11)
/// once the Settings screen exists in Sprint 5.
struct EditorView: View {
    let store: DocumentStore

    @State private var showingFolderHealth = false

    /// Single mutation path: every keystroke goes through
    /// DocumentStore.updateText so dirty tracking is never bypassed.
    /// A direct binding to store.currentText would skip it — do not add one.
    private var textBinding: Binding<String> {
        Binding(
            get: { store.currentText },
            set: { store.updateText($0) }
        )
    }

    /// Editing is allowed only when the document is loaded or pending-new.
    /// All other states (downloading, failed, not yet loaded) lock the editor.
    private var canEdit: Bool {
        switch store.fileState {
        case .loaded, .pending:
            return true
        case .downloading, .downloadFailed, .loadFailed, nil:
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            editorArea
            bottomBar
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text(DailyFilename(date: store.selectedDate).dateStamp)
                .font(.headline)
                .monospacedDigit()

            Spacer()

            // Sprint 1 Folder Health entry point. Moves into Settings in Sprint 5.
            Button {
                showingFolderHealth = true
            } label: {
                Image(systemName: "folder")
            }
            .accessibilityLabel("Folder Health")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .sheet(isPresented: $showingFolderHealth) {
            FolderHealthView()
        }
    }

    // MARK: - Editor area

    private var editorArea: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: textBinding)
                .disabled(!canEdit)

            // Feature 04 placeholder, shown for empty editable documents
            // (covers both pending-new files and existing empty files).
            if store.currentText.isEmpty && canEdit {
                Text(EditorCopy.placeholder)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            if let status = SaveStatusDisplay.text(
                saveState: store.saveState,
                fileState: store.fileState
            ) {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}
