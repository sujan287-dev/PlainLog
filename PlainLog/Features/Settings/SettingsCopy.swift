import Foundation

/// Settings screen copy (PLAN.md Feature 11, verbatim, test-enforced).
/// Section titles and row labels are taken directly from Feature 11's
/// "Settings sections" / "Summary section" / "About section" lists.
enum SettingsCopy {

    // MARK: - Section titles (Feature 11 "Settings sections", in order)

    static let folderSection = "Folder"
    static let appearanceSection = "Appearance"
    static let summarySection = "Summary"
    static let proSection = "Pro"
    static let aboutSection = "About"

    // MARK: - Folder section

    /// Not itself a Feature 11 row label — Feature 11's Folder rows (Current
    /// folder / Status / Last successful save / Reconnect folder) already
    /// live inside FolderHealthView, reused unmodified. This is the single
    /// row that opens it from Settings (see SettingsView's own doc comment
    /// for why it's presented as a nested sheet rather than inlined).
    static let folderHealthRow = "Folder Health"

    // MARK: - Summary section rows (Feature 11 "Summary section", verbatim)

    static let defaultCurrencySymbol = "Default currency symbol"
    static let showExpenseTotal = "Show expense total"
    static let showTaskCount = "Show task count"
    static let showTags = "Show tags"

    // MARK: - About section rows (Feature 11 "About section", verbatim labels)

    static let version = "Version"
    static let privacyPolicy = "Privacy policy"
    static let support = "Support"

    /// Shown under "Privacy policy". Feature 11 lists only the row label —
    /// no policy document or URL exists anywhere in PLAN.md, so this shows
    /// the actual privacy stance inline instead of linking to nothing.
    /// Composed from PaywallCopy's own verbatim trust lines (Feature 12)
    /// plus CLAUDE.md's locked "no tracking" constraint (§4).
    static let privacyStance = "\(PaywallCopy.trustNoAccount) \(PaywallCopy.trustNoData) No tracking."
}
