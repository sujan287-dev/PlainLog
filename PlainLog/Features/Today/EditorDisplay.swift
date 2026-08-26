import Foundation

/// Editor chrome display logic and copy (Sprint 3).
/// All copy is VERBATIM from PLAN.md Feature 04 and enforced by
/// EditorDisplayTests. Do not paraphrase. Do not edit without updating
/// PLAN.md and the tests together.
enum SaveStatusDisplay {

    /// Maps model states to Feature 04's save status indicator text.
    /// Returns nil when no indicator should be shown.
    /// File-level states take precedence because they block editing entirely.
    static func text(saveState: SaveState, fileState: DailyFileState?) -> String? {
        if fileState == .downloading {
            return "Waiting for iCloud"
        }

        switch saveState {
        case .idle:
            return nil
        case .waitingToSave:
            return "Waiting to save"
        case .saving:
            return "Saving\u{2026}"
        case .saved:
            return "Saved"
        case .saveFailed, .conflictDetectedDuringSave, .targetFileAlreadyExists:
            return "Save failed"
        case .accessLostDuringSave:
            return "Folder access lost"
        }
    }
}

/// Static editor copy (verbatim, test-enforced).
enum EditorCopy {
    /// Feature 04 placeholder.
    /// Curly apostrophe (U+2019) and ellipsis (U+2026) exactly as in PLAN.md,
    /// written as explicit escapes so the characters cannot be silently swapped.
    static let placeholder = "Write today\u{2019}s log\u{2026}"
}
