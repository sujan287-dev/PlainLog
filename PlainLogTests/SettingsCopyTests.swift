import XCTest
@testable import PlainLog

/// Sprint 5 · Piece 5.5 — Settings copy (verbatim against PLAN.md Feature 11)
/// and SummaryDisplaySettings' persistence (the one new model this piece
/// introduces — the Sepia Pro gate itself is already covered by
/// AppearanceSettingsTests and isn't duplicated here).
final class SettingsCopyTests: XCTestCase {

    // MARK: - Section titles

    func testSettingsSectionTitles() {
        XCTAssertEqual(SettingsCopy.folderSection, "Folder")
        XCTAssertEqual(SettingsCopy.appearanceSection, "Appearance")
        XCTAssertEqual(SettingsCopy.summarySection, "Summary")
        XCTAssertEqual(SettingsCopy.proSection, "Pro")
        XCTAssertEqual(SettingsCopy.aboutSection, "About")
    }

    // MARK: - Summary section row labels

    func testSummarySectionRowLabels() {
        XCTAssertEqual(SettingsCopy.defaultCurrencySymbol, "Default currency symbol")
        XCTAssertEqual(SettingsCopy.showExpenseTotal, "Show expense total")
        XCTAssertEqual(SettingsCopy.showTaskCount, "Show task count")
        XCTAssertEqual(SettingsCopy.showTags, "Show tags")
    }

    // MARK: - About section row labels

    func testAboutSectionRowLabels() {
        XCTAssertEqual(SettingsCopy.version, "Version")
        XCTAssertEqual(SettingsCopy.privacyPolicy, "Privacy policy")
        XCTAssertEqual(SettingsCopy.support, "Support")
    }

    // MARK: - Privacy stance

    func testAboutPrivacyStance() {
        XCTAssertEqual(
            SettingsCopy.privacyStance,
            "No account. No data collection. No tracking."
        )
    }
}

/// SummaryDisplaySettings tests (new in this piece). Same fresh-UserDefaults-
/// suite-per-test pattern as AppearanceSettingsTests/BillingKitTests.
@MainActor
final class SummaryDisplaySettingsTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "SummaryDisplaySettingsTests-\(UUID().uuidString)"
        userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        if let suiteName {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        userDefaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    // MARK: - Defaults (Piece 5.6: symbol default corrected from "$" to "")

    func testSummarySettingsDefaultVisibility() {
        let settings = SummaryDisplaySettings(userDefaults: userDefaults)
        XCTAssertTrue(settings.showExpenseTotal)
        XCTAssertTrue(settings.showTaskCount)
        XCTAssertTrue(settings.showTags)
    }

    func testCurrencySymbolDefaultIsEmpty() throws {
        let settings = SummaryDisplaySettings(userDefaults: userDefaults)
        XCTAssertEqual(settings.defaultCurrencySymbol, "")

        // Must reproduce Feature 10's own summary bar example exactly.
        let total = try XCTUnwrap(Decimal(string: "118.75"))
        XCTAssertEqual(
            SummaryBarSegments.expenseText(symbol: settings.defaultCurrencySymbol, total: total),
            "Expenses: 118.75"
        )
    }

    func testCurrencySymbolTrimsWhitespace() throws {
        let total = try XCTUnwrap(Decimal(string: "118.75"))
        XCTAssertEqual(
            SummaryBarSegments.expenseText(symbol: "  ", total: total),
            "Expenses: 118.75"
        )
    }

    // MARK: - Persistence

    func testVisibilityTogglesPersist() {
        let settings = SummaryDisplaySettings(userDefaults: userDefaults)
        settings.setDefaultCurrencySymbol("\u{20AC}")
        settings.setShowExpenseTotal(false)
        settings.setShowTaskCount(false)
        settings.setShowTags(false)

        let reloaded = SummaryDisplaySettings(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.defaultCurrencySymbol, "\u{20AC}")
        XCTAssertFalse(reloaded.showExpenseTotal)
        XCTAssertFalse(reloaded.showTaskCount)
        XCTAssertFalse(reloaded.showTags)
    }
}

/// SummaryBarSegments tests (new in this piece) — the pure prefix-formatting
/// helper SummaryBar's expense segment is built from. No UserDefaults, no
/// environment, no SwiftUI rendering.
final class SummaryBarSegmentsTests: XCTestCase {

    func testExpenseSegmentWithNoSymbol() throws {
        let total = try XCTUnwrap(Decimal(string: "118.75"))
        XCTAssertEqual(
            SummaryBarSegments.expenseText(symbol: "", total: total),
            "Expenses: 118.75"
        )
    }

    func testExpenseSegmentPrefixesTrimmedSymbol() throws {
        let total = try XCTUnwrap(Decimal(string: "118.75"))
        XCTAssertEqual(
            SummaryBarSegments.expenseText(symbol: "$", total: total),
            "Expenses: $118.75"
        )
        XCTAssertEqual(
            SummaryBarSegments.expenseText(symbol: " \u{20AC} ", total: total),
            "Expenses: \u{20AC}118.75"
        )
    }
}
