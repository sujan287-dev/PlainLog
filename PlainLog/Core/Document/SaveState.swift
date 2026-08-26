import Foundation

/// Save lifecycle states per PLAN.md §9 "Save states".
/// Piece 3.1 defines the full enum; Piece 3.3 drives the save transitions.
enum SaveState: Equatable {
    case idle
    case waitingToSave
    case saving
    case saved
    case saveFailed(reason: String)
    case accessLostDuringSave
    case conflictDetectedDuringSave
    case targetFileAlreadyExists
    /// External change detected on foreground return (Feature 08), with
    /// unsaved edits — distinct from conflictDetectedDuringSave, which fires
    /// mid-save rather than from the foreground check.
    case conflictDetected
    /// The active file was deleted outside PlainLog (Feature 08), detected
    /// on foreground return.
    case fileDeletedExternally
}
