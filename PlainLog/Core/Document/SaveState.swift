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
}
