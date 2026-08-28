import Foundation

/// SaveErrorModalGuard — Sprint 5 · Piece 5.8 (PLAN.md Feature 06).
/// Pure "show once per failure episode" decision for the save-error modal.
/// No I/O — every input is a parameter, the result is a plain value.
///
/// An "episode" is one unbroken run of save failures. The modal shows
/// automatically only for the FIRST failure in a run; while episodeActive
/// stays true, further automatic failures (e.g. autosave retrying while the
/// user keeps typing during an ongoing folder-access problem) don't re-pop
/// it. The episode ends — episodeActive -> false — when a save actually
/// succeeds (.saved) or the state clears (.idle), OR when the caller reports
/// an explicit user action (Retry / Copy current text tapped): a deliberate
/// retry is a real signal, not a silent background re-trigger, so a failure
/// AFTER it deserves its own fresh presentation rather than being suppressed
/// forever by the first episode.
enum SaveErrorModalGuard {

    /// True when `state` is one of Feature 06's save-error states.
    static func isFailureState(_ state: SaveState) -> Bool {
        switch state {
        case .saveFailed, .accessLostDuringSave:
            return true
        case .idle, .waitingToSave, .saving, .saved,
             .conflictDetectedDuringSave, .targetFileAlreadyExists,
             .conflictDetected, .fileDeletedExternally:
            return false
        }
    }

    /// Evaluates a saveState transition against the current episode flag.
    /// Returns whether to show the modal now, and the flag's next value.
    static func evaluate(state: SaveState, episodeActive: Bool) -> (shouldShow: Bool, episodeActive: Bool) {
        if isFailureState(state) {
            return (shouldShow: !episodeActive, episodeActive: true)
        }
        if state == .saved || state == .idle {
            return (shouldShow: false, episodeActive: false)
        }
        // Any other in-between state (.saving, .waitingToSave, a Feature 08
        // conflict/deletion state, etc.) doesn't resolve the episode either
        // way — we don't yet know whether a save currently in flight will
        // succeed or fail.
        return (shouldShow: false, episodeActive: episodeActive)
    }
}
