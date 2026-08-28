import Foundation

/// The confirmation(s) required before completing a folder reselection
/// (PLAN.md Feature 02, requirements 6/10/11/12; Risks 4 and 5).
struct ReselectionRequirement: OptionSet, Equatable {
    let rawValue: Int

    /// The picked folder's name differs from the last known hint while
    /// unsaved edits exist — PlainLog cannot verify it's the original folder.
    static let reselectionWarning = ReselectionRequirement(rawValue: 1 << 0)

    /// Today's daily file already exists in the picked folder — saving would
    /// overwrite it.
    static let existingTargetFileWarning = ReselectionRequirement(rawValue: 1 << 1)
}

/// ReselectionGuard — Sprint 5 · Piece 5.7 (PLAN.md Feature 02).
/// Pure decision model: given the current dirty/hint/target-file state, says
/// which confirmation(s), if any, must be resolved before a folder
/// reselection proceeds to save. No I/O, no side effects — every input is a
/// parameter, the result is a plain value.
enum ReselectionGuard {

    /// Ordering when both warnings apply: the reselection warning (is this
    /// even the right folder at all?) must be resolved BEFORE the
    /// existing-target-file warning (is it safe to write into it?) — you
    /// confirm folder identity before being asked about overwriting its
    /// contents. Callers present them in that sequence; this type doesn't
    /// enforce it, since OptionSet doesn't have a natural iteration order,
    /// but both PlainLogTests/ReselectionGuardTests.swift and every call
    /// site check .reselectionWarning first.
    ///
    /// Gating: PLAN.md's requirement 12 ("If today file already exists...")
    /// reads as unconditional on its own, but requirement 6/7 frame ALL of
    /// Feature 02's warnings as protecting UNSAVED EDITS specifically (Risks
    /// 4/5 are both about not losing in-memory text) — and reselecting into
    /// a folder that already has today's file is entirely ordinary when
    /// there's nothing dirty to protect. So both warnings are gated on
    /// isDirty: when not dirty, this returns [] unconditionally, regardless
    /// of the other two inputs.
    static func evaluate(
        isDirty: Bool,
        folderNameMatchesHint: Bool,
        todayFileExistsInTarget: Bool
    ) -> ReselectionRequirement {
        guard isDirty else { return [] }

        var requirement: ReselectionRequirement = []
        if !folderNameMatchesHint {
            requirement.insert(.reselectionWarning)
        }
        if todayFileExistsInTarget {
            requirement.insert(.existingTargetFileWarning)
        }
        return requirement
    }
}
