import Foundation

/// OfflineCaptureGuard — Sprint 5 · Piece 5.9 (PLAN.md Feature 07 requirement
/// 8 / Risk 2). Pure decision model — no I/O, every input is a parameter.
///
/// Truth table (warning required only when ALL THREE are true):
///
/// | folderIsICloud | isOffline | isCreatingNewFile | Required? |
/// |-----------------|-----------|--------------------|-----------|
/// | false            | any       | any                | No        |
/// | any              | false     | any                | No        |
/// | any              | any       | false               | No        |
/// | true             | true      | true               | Yes       |
///
/// Rationale: the warning exists because an offline device can't confirm
/// whether iCloud already holds a version of today's file (Risk 2) — that
/// risk only exists for iCloud folders, only while offline, and only when a
/// BRAND NEW file is about to be created (editing a file that already exists
/// locally isn't a "might already exist elsewhere" conflict).
enum OfflineCaptureGuard {
    static func isWarningRequired(
        folderIsICloud: Bool,
        isOffline: Bool,
        isCreatingNewFile: Bool
    ) -> Bool {
        folderIsICloud && isOffline && isCreatingNewFile
    }
}
