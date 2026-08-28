import SwiftUI

/// Editor Pane — Sprint 3 (PLAN.md Feature 04).
/// Hosts both Edit Mode (TextEditor) and Preview Mode (MarkdownRenderer).
/// Autosave (Piece 3.3), preview renderer (Piece 3.4). Date navigation
/// and the summary bar arrive in Sprint 4.
struct EditorView: View {
    let store: DocumentStore

    @Environment(\.scenePhase) private var scenePhase
    @Environment(BillingKit.self) private var billingKit

    @State private var showingFolderHealth = false
    @State private var showingHistory = false
    @State private var showingPaywall = false
    @State private var editorMode: EditorMode = .editing

    // Feature 13: weekly summary export.
    @State private var isExporting = false
    @State private var exportedFile: ExportedWeeklyFile?
    @State private var exportErrorMessage: String?

    // Feature 08: foreground external-change check.
    @State private var showingConflictModal = false
    @State private var showingDeletedFileModal = false
    @State private var deletedFileVariant: DeletedFileModal.Variant = .withoutUnsavedEdits

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
        // Feature 08: invisible carriers for the .alert-based modals below,
        // driven by the @State flags the foreground check sets.
        .background(
            ConflictModal(
                isPresented: $showingConflictModal,
                reload: { Task { await reloadCurrentDocument() } },
                saveAsCopy: { Task { await saveCurrentDocumentAsCopyThenReload() } }
            )
        )
        .background(
            DeletedFileModal(
                isPresented: $showingDeletedFileModal,
                variant: deletedFileVariant,
                recreate: { Task { await recreateDeletedFileThenReload() } },
                discard: { Task { await reloadCurrentDocument() } },
                ok: { Task { await reloadCurrentDocument() } }
            )
        )
        // Feature 08: check for external changes whenever the app returns
        // to the foreground.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task { await checkForExternalChanges() }
            }
        }
    }

    // MARK: - Foreground external-change check (Feature 08)

    /// Runs on every return to the foreground. Only meaningful once a file is
    /// actually loaded with a snapshot to compare against — pending, failed,
    /// and downloading states have nothing on disk to have changed.
    private func checkForExternalChanges() async {
        guard case .loaded = store.fileState,
              let snapshot = store.loadedSnapshot,
              let url = store.targetFileURL else {
            return
        }

        let fileIO = FileIOService()
        let result = await Task.detached(priority: .userInitiated) {
            fileIO.checkExternalChange(at: url, against: snapshot)
        }.value

        switch result {
        case .unchanged:
            break

        case .modified:
            if store.isDirty {
                showingConflictModal = true
            } else {
                // Feature 08: no unsaved edits — reload silently, no modal.
                await reloadCurrentDocument()
            }

        case .deleted:
            deletedFileVariant = store.isDirty ? .withUnsavedEdits : .withoutUnsavedEdits
            showingDeletedFileModal = true
        }
    }

    /// Reload action shared by: silent reload on unmodified-but-changed
    /// content, the conflict modal's "Reload", the deleted-file modal's
    /// "Discard edits", and its "OK" (which resolves to .pending since the
    /// file no longer exists) — no merge logic anywhere (Feature 08).
    private func reloadCurrentDocument() async {
        guard let folderURL = store.folderURL else { return }
        await store.load(date: store.selectedDate, in: folderURL)
    }

    /// Conflict modal's "Save as copy": preserve the local edits under a new
    /// filename, then reload the original (unedited-locally) file.
    private func saveCurrentDocumentAsCopyThenReload() async {
        do {
            _ = try await store.saveAsCopy()
        } catch {
            Log.document.error("Save as copy failed: \(error.localizedDescription)")
        }
        await reloadCurrentDocument()
    }

    /// Deleted-file modal's "Recreate file": write the current text back to
    /// disk, then reload to refresh fileState/loadedSnapshot consistently.
    private func recreateDeletedFileThenReload() async {
        await store.saveNow()
        await reloadCurrentDocument()
    }

    // MARK: - Weekly export (Feature 13)

    /// Gregorian calendar bound to the device's local timezone — mirrors
    /// DocumentStore.navigationCalendar and DailyFilename's own default
    /// construction, so the export window agrees with which file a given
    /// date represents.
    private static var exportCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// Generates the weekly report and prepares it for the share sheet.
    /// Runs off the main actor: WeeklyExportOrchestrator calls into
    /// FileIOService's synchronous, background-thread-only methods.
    private func performWeeklyExport() async {
        guard let folderURL = store.folderURL else { return }

        isExporting = true
        defer { isExporting = false }

        let fileIO = FileIOService()
        let endDate = store.selectedDate
        let calendar = Self.exportCalendar

        let outcome = await Task.detached(priority: .userInitiated) { () -> Result<URL, String> in
            WeeklyExportOrchestrator.export(
                endDate: endDate,
                folderURL: folderURL,
                fileIO: fileIO,
                calendar: calendar
            )
        }.value

        switch outcome {
        case .success(let url):
            exportedFile = ExportedWeeklyFile(url: url)
        case .failure(let message):
            Log.export.error("Weekly export failed: \(message)")
            exportErrorMessage = "Could not prepare the export file."
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 8) {
            // Row 1: date navigation (Feature 09).
            HStack {
                Button {
                    Task { await store.goToPreviousDay() }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous day")

                Spacer()

                Text(DailyFilename(date: store.selectedDate).dateStamp)
                    .font(.headline)
                    .bold()
                    .monospacedDigit()

                Spacer()

                Button {
                    Task { await store.goToNextDay() }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next day")
            }

            // Row 2: controls.
            HStack {
                Button("Today") {
                    Task { await store.goToToday() }
                }

                Spacer()

                // History browser entry point (Feature 09).
                Button {
                    showingHistory = true
                } label: {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel("History")

                // Pro trigger (Feature 12). Non-interactive indicator once
                // entitled; otherwise opens the paywall sheet.
                if billingKit.isProEnabled {
                    Text("Pro ✓")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("PlainLog Pro")
                } else {
                    Button {
                        showingPaywall = true
                    } label: {
                        Image(systemName: "star")
                    }
                    .accessibilityLabel("PlainLog Pro")
                }

                // Weekly export trigger (Feature 13). Pro-gated: non-Pro
                // taps open the paywall instead of generating anything.
                Button {
                    if billingKit.isProEnabled {
                        Task { await performWeeklyExport() }
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    if isExporting {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .accessibilityLabel("Weekly export")
                .disabled(isExporting)

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
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .sheet(isPresented: $showingFolderHealth) {
            FolderHealthView()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(item: $exportedFile) { file in
            ActivityShareSheet(activityItems: [file.url])
        }
        .alert(
            "Export Failed",
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { isPresented in
                    if !isPresented { exportErrorMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
        .sheet(isPresented: $showingHistory) {
            HistoryBrowserView(
                folderURL: store.folderURL,
                selectedDate: store.selectedDate,
                onSelect: { selected in
                    // Dismiss first, then navigate on the next runloop turn
                    // (matches the WelcomeView fileImporter fix) — presenting
                    // the download/conflict flow that navigate(to:) can
                    // trigger in the same tick as this sheet's dismissal
                    // risks the same present-while-dismissing race.
                    showingHistory = false
                    Task { @MainActor in
                        await store.goTo(date: selected)
                    }
                }
            )
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
        // Parse once per render. Block-level parsing never fails; the
        // renderer's inline fallback still covers malformed inline syntax.
        MarkdownRenderer(nodes: MarkdownParser.parse(store.currentText))
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
