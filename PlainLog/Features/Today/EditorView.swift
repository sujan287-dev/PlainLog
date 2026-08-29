import SwiftUI

/// Editor Pane — Sprint 3 (PLAN.md Feature 04).
/// Hosts both Edit Mode (TextEditor) and Preview Mode (MarkdownRenderer).
/// Autosave (Piece 3.3), preview renderer (Piece 3.4). Date navigation
/// and the summary bar arrive in Sprint 4.
struct EditorView: View {
    let store: DocumentStore

    @Environment(\.scenePhase) private var scenePhase
    @Environment(BillingKit.self) private var billingKit
    @Environment(ConnectivityMonitor.self) private var connectivityMonitor

    @State private var showingSettings = false
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

    // Feature 06: save-error modal, shown once per failure episode.
    @State private var showingSaveErrorModal = false
    @State private var saveErrorEpisodeActive = false

    // Feature 07: iCloud-download modal.
    @State private var showingICloudDownloadModal = false

    // Feature 07 requirement 8: offline-copy-warning, shown once per
    // pending file (reset whenever a fresh .pending file loads).
    @State private var showingOfflineCopyWarningModal = false
    @State private var offlineWarningShownForCurrentFile = false

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
        // Feature 06: invisible carrier for the save-error modal.
        .background(
            SaveErrorModal(
                isPresented: $showingSaveErrorModal,
                retry: {
                    // Explicit user action: a failure after this deserves
                    // its own fresh presentation, not silent suppression.
                    saveErrorEpisodeActive = false
                    Task { await store.saveNow() }
                },
                copyText: {
                    saveErrorEpisodeActive = false
                    Clipboard.copy(store.currentText)
                }
            )
        )
        // Feature 07: invisible carrier for the iCloud-download modal.
        .background(
            ICloudDownloadModal(
                isPresented: $showingICloudDownloadModal,
                retry: { Task { await retryCloudDownload() } }
            )
        )
        // Feature 07 requirement 8: invisible carrier for the offline-copy
        // warning that gates brand-new-file creation.
        .background(
            OfflineCopyWarningModal(
                isPresented: $showingOfflineCopyWarningModal,
                createOfflineFile: {
                    store.unblockPendingCreation()
                    Task { await store.saveNow() }
                },
                cancel: {
                    // Block stays engaged: content remains in memory as a
                    // still-pending file. No shadow draft is ever written.
                }
            )
        )
        // Feature 08: check for external changes whenever the app returns
        // to the foreground.
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task { await checkForExternalChanges() }
            }
        }
        // Feature 06: show the save-error modal once per failure episode.
        .onChange(of: store.saveState) { _, newValue in
            let outcome = SaveErrorModalGuard.evaluate(state: newValue, episodeActive: saveErrorEpisodeActive)
            saveErrorEpisodeActive = outcome.episodeActive
            if outcome.shouldShow {
                showingSaveErrorModal = true
            }
        }
        // Feature 07: show the iCloud-download modal whenever fileState
        // becomes .downloading. Equatable diffing on fileState already
        // means this only fires on a genuine transition, not on every
        // re-render of an unchanged .downloading value.
        //
        // Feature 07 requirement 8: a fresh .pending file (any load that
        // lands on .pending — a new date, a reload, etc.) starts with a
        // clean slate for the offline-capture warning, regardless of
        // whatever the PREVIOUS document's gate state was.
        .onChange(of: store.fileState) { _, newValue in
            if newValue == .downloading {
                showingICloudDownloadModal = true
            }
            if newValue == .pending {
                offlineWarningShownForCurrentFile = false
                store.unblockPendingCreation()
            }
        }
        // Feature 07 requirement 8: the first meaningful edit to a NEW
        // pending file is the trigger — evaluated synchronously as part of
        // the same update that changed currentText, well before the 500ms
        // autosave debounce (a real async delay) could fire, so the block
        // (below) is armed before any write is attempted.
        .onChange(of: store.currentText) { _, _ in
            evaluateOfflineCaptureGuardIfNeeded()
        }
    }

    // MARK: - Offline copy warning (Feature 07 requirement 8)

    private func evaluateOfflineCaptureGuardIfNeeded() {
        guard store.isPendingNewFile, store.hasMeaningfulContent, !offlineWarningShownForCurrentFile else {
            return
        }
        guard let folderURL = store.folderURL else { return }

        let required = OfflineCaptureGuard.isWarningRequired(
            folderIsICloud: FolderAccessService.isICloudFolder(url: folderURL),
            isOffline: connectivityMonitor.isOffline,
            isCreatingNewFile: true
        )
        guard required else { return }

        offlineWarningShownForCurrentFile = true
        store.blockPendingCreation()
        showingOfflineCopyWarningModal = true
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

    // MARK: - iCloud download retry (Feature 07)

    /// Requests iCloud re-download the target file, then reloads so
    /// fileState is re-evaluated (transitions out of .downloading once the
    /// download actually completes; stays .downloading otherwise, and the
    /// modal simply doesn't re-pop for an unchanged value).
    private func retryCloudDownload() async {
        guard let folderURL = store.folderURL, let targetURL = store.targetFileURL else { return }

        let fileIO = FileIOService()
        await Task.detached(priority: .userInitiated) {
            do {
                try fileIO.requestCloudDownload(at: targetURL)
            } catch {
                Log.fileIO.error("iCloud download retry failed: \(error.localizedDescription)")
            }
        }.value

        await store.load(date: store.selectedDate, in: folderURL)
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

        let outcome = await Task.detached(priority: .userInitiated) { () -> Result<URL, WeeklyExportWriteError> in
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
        case .failure(let error):
            Log.export.error("Weekly export failed: \(error.message)")
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
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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
            // Bugfix (H1): persistent, actionable indicator while a new
            // file's creation is blocked pending offline-capture
            // confirmation — see blockedCreationBanner's doc comment.
            if store.isPendingCreationBlocked {
                blockedCreationBanner
            }

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

    // MARK: - Blocked-creation banner (bugfix H1, Feature 07 requirement 8)

    /// Shown whenever DocumentStore.isPendingCreationBlocked is true — i.e.
    /// the offline-copy-warning was shown and either hasn't been resolved
    /// yet or was explicitly Cancelled. Without this, Cancelling left the
    /// document permanently unsaveable (every save attempt and every
    /// navigation button silently no-ops) with no visible explanation and
    /// no way back — this banner surfaces the state and lets the user
    /// re-open the confirmation on demand, any time, without automatically
    /// re-popping the modal on every keystroke.
    private var blockedCreationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.orange)
            Text(Feature0607ModalCopy.offlineCaptureBlockedBanner)
                .font(.caption)
            Spacer()
            Button(Feature0607ModalCopy.offlineCaptureBlockedReviewButton) {
                showingOfflineCopyWarningModal = true
            }
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
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
