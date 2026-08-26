import XCTest
@testable import PlainLog

/// Enforces Feature 04 copy and the save-status mapping, verbatim from PLAN.md.
/// If these fail, the copy drifted — fix the copy, never weaken the tests.
final class EditorDisplayTests: XCTestCase {

    // MARK: - Save status indicators (Feature 04)

    func testSaveStateIndicatorsAreVerbatim() {
        let loaded = DailyFileState.loaded(text: "x", snapshot: nil)

        XCTAssertNil(SaveStatusDisplay.text(saveState: .idle, fileState: loaded))
        XCTAssertEqual(
            SaveStatusDisplay.text(saveState: .waitingToSave, fileState: loaded),
            "Waiting to save"
        )
        XCTAssertEqual(
            SaveStatusDisplay.text(saveState: .saving, fileState: loaded),
            "Saving\u{2026}"
        )
        XCTAssertEqual(
            SaveStatusDisplay.text(saveState: .saved, fileState: loaded),
            "Saved"
        )
        XCTAssertEqual(
            SaveStatusDisplay.text(saveState: .saveFailed(reason: "disk"), fileState: loaded),
            "Save failed"
        )
        XCTAssertEqual(
            SaveStatusDisplay.text(saveState: .accessLostDuringSave, fileState: loaded),
            "Folder access lost"
        )
    }

    func testDownloadingFileStateTakesPrecedence() {
        XCTAssertEqual(
            SaveStatusDisplay.text(saveState: .saved, fileState: .downloading),
            "Waiting for iCloud"
        )
        XCTAssertEqual(
            SaveStatusDisplay.text(saveState: .idle, fileState: .downloading),
            "Waiting for iCloud"
        )
    }

    func testConflictSaveStatesShowSaveFailed() {
        let loaded = DailyFileState.loaded(text: "x", snapshot: nil)
        XCTAssertEqual(
            SaveStatusDisplay.text(saveState: .conflictDetectedDuringSave, fileState: loaded),
            "Save failed"
        )
        XCTAssertEqual(
            SaveStatusDisplay.text(saveState: .targetFileAlreadyExists, fileState: loaded),
            "Save failed"
        )
    }

    // MARK: - Placeholder (Feature 04)

    func testPlaceholderIsVerbatim() {
        XCTAssertEqual(EditorCopy.placeholder, "Write today\u{2019}s log\u{2026}")
    }
}
