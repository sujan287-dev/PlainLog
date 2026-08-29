import Foundation

/// Settings > Pro section copy for the Supporter badge (PLAN.md Feature 12
/// "Pro features" list). The badge label/caption are NOT quoted anywhere in
/// PLAN.md — the spec names "Supporter badge" as a Pro feature but gives it
/// no copy of its own. This is a small, invented, on-brand UI string (kept
/// short and honest, flagged in this piece's report), test-enforced the
/// same way as every other copy-constants file in this codebase.
enum SettingsProCopy {
    static let supporterBadgeLabel = "Supporter"
    static let supporterBadgeCaption = "Thank you for supporting PlainLog."
}
