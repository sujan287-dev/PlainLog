import SwiftUI

/// Editor Pane — Sprint 3 (PLAN.md Feature 04).
/// Hosts both Edit Mode (TextEditor) and Preview Mode (MarkdownRenderer).
/// Autosave (Piece 3.3), preview renderer (Piece 3.4). Date navigation
/// and the summary bar arrive in Sprint 4.
struct EditorView: View {
    let store: DocumentStore

    @State private var showingFolderHealth = false
    @State private var editorMode: EditorMode = .editing

    enum EditorMode: Hashable {
        case editing
        case previewing
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { store.currentText },
            set: { store.updateText($0) }
        )
    }

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
            contentArea
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

            // Edit / Preview toggle
            Picker("Mode", selection: $editorMode) {
                Text("Edit").tag(EditorMode.editing)
                Text("Preview").tag(EditorMode.previewing)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

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

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        switch editorMode {
        case .editing:
            editModeContent
        case .previewing:
            previewModeContent
        }
    }

    private var editModeContent: some View {
        VStack(spacing: 0) {
            // Feature 04 large file warning (non-blocking).
            if store.isLargeFile {
                largeFileWarningBanner
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: textBinding)
                    .disabled(!canEdit)

                if store.currentText.isEmpty && canEdit {
                    Text(EditorCopy.placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }

                // Feature 04 read-only indicator when the file can't be edited safely.
                if !canEdit {
                    readOnlyIndicator
                }
            }
        }
    }

    private var previewModeContent: some View {
        // Parse once per render. If parsing fails, renderer falls back to raw text.
        let nodes = MarkdownParser.parse(store.currentText)
        return MarkdownRenderer(rawText: store.currentText, nodes: nodes)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let summary = store.summary {
                SummaryBar(summary: summary)
            }

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
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Large file warning (Feature 04)

    private var largeFileWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(EditorCopy.largeFileWarning)
                .font(.caption)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Read-only indicator (Feature 04)

    private var readOnlyIndicator: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Read-only")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
