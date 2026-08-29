import XCTest
@testable import PlainLog

/// Bugfix M2 (full-codebase audit) — the re-entrancy guard on
/// ReselectionFlowState. Also the first dedicated test coverage for this
/// class's orchestration layer at all (previously only ReselectionGuard's
/// pure decision function was tested — a gap the audit separately flagged
/// as M4). Uses a real FolderAccessService/DocumentStore against throwaway
/// temp folders, matching FolderAccessServiceTests'/DocumentStoreTests' own
/// conventions. No StoreKit dependency.
@MainActor
final class ReselectionFlowStateTests: XCTestCase {

    private var flow: ReselectionFlowState!
    private var documentStore: DocumentStore!
    private var folderAccessService: FolderAccessService!
    private var fileIO: FileIOService!
    private var originalFolder: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        flow = ReselectionFlowState()
        fileIO = FileIOService()
        documentStore = DocumentStore(fileIO: fileIO)
        folderAccessService = FolderAccessService(store: MockBookmarkStore())
        // folderDisplayNameHint persists to real UserDefaults.standard
        // (unlike the injected mock bookmark store) — clear it up front so
        // the "name mismatch" scenarios below are deterministic regardless
        // of what other tests in this process may have left behind.
        folderAccessService.clearAccess()

        originalFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReselectionFlowStateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: originalFolder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        folderAccessService.clearAccess()
        if let originalFolder {
            try? FileManager.default.removeItem(at: originalFolder)
        }
        flow = nil
        documentStore = nil
        folderAccessService = nil
        fileIO = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makeDirtyDocument() async {
        await documentStore.load(date: Date(), in: originalFolder)
        documentStore.updateText("some in-progress text")
    }

    private func makeEmptyPickedFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReselectionFlowStatePicked-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - isProcessing

    func testIsProcessingStaysTrueWhileAWarningIsAwaitingConfirmation() async throws {
        await makeDirtyDocument()
        let picked = try makeEmptyPickedFolder()
        defer { try? FileManager.default.removeItem(at: picked) }

        flow.handleFolderSelection(.success([picked]), folderAccessService: folderAccessService, documentStore: documentStore)

        // No name hint registered -> mismatch -> reselection warning
        // required, never auto-confirmed -> isProcessing stays true until
        // the user resolves it.
        XCTAssertTrue(flow.isProcessing)
        XCTAssertTrue(flow.showingReselectionWarning)
    }

    func testCancellingResetsIsProcessing() async throws {
        await makeDirtyDocument()
        let picked = try makeEmptyPickedFolder()
        defer { try? FileManager.default.removeItem(at: picked) }

        flow.handleFolderSelection(.success([picked]), folderAccessService: folderAccessService, documentStore: documentStore)
        XCTAssertTrue(flow.isProcessing)

        flow.cancelPendingReselection()

        XCTAssertFalse(flow.isProcessing)
        XCTAssertNil(flow.pendingReselectionURL)
    }

    /// The core guarantee this fix adds: a second folder pick while the
    /// first is still being resolved must not overwrite the first attempt's
    /// pending state.
    func testSecondFolderPickWhileProcessingIsIgnored() async throws {
        await makeDirtyDocument()
        let firstPick = try makeEmptyPickedFolder()
        let secondPick = try makeEmptyPickedFolder()
        defer {
            try? FileManager.default.removeItem(at: firstPick)
            try? FileManager.default.removeItem(at: secondPick)
        }

        flow.handleFolderSelection(.success([firstPick]), folderAccessService: folderAccessService, documentStore: documentStore)
        XCTAssertTrue(flow.isProcessing)
        let pendingAfterFirst = flow.pendingReselectionURL

        flow.handleFolderSelection(.success([secondPick]), folderAccessService: folderAccessService, documentStore: documentStore)

        XCTAssertEqual(
            flow.pendingReselectionURL,
            pendingAfterFirst,
            "A second pick while processing must not overwrite the first attempt's pending URL."
        )
    }

    func testNonDirtyDocumentNeverSetsIsProcessing() async throws {
        await documentStore.load(date: Date(), in: originalFolder)
        XCTAssertFalse(documentStore.isDirty)

        let picked = try makeEmptyPickedFolder()
        defer { try? FileManager.default.removeItem(at: picked) }

        flow.handleFolderSelection(.success([picked]), folderAccessService: folderAccessService, documentStore: documentStore)

        XCTAssertFalse(flow.isProcessing)
    }
}
