import XCTest
@testable import PlainLog

/// Sprint 5 · Piece 5.4 — pure model tests for AppearanceSettings. Each test
/// uses its own UserDefaults suite (never .standard), torn down via
/// removePersistentDomain, matching BillingKitTests' convention. No
/// StoreKit dependency — no skips.
@MainActor
final class AppearanceSettingsTests: XCTestCase {

    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "AppearanceSettingsTests-\(UUID().uuidString)"
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

    // MARK: - Defaults

    func testAppearanceSettingsDefaults() {
        let settings = AppearanceSettings(userDefaults: userDefaults)
        XCTAssertEqual(settings.theme, .system)
        XCTAssertEqual(settings.font, .system)
        XCTAssertEqual(settings.fontSize, .medium)
    }

    // MARK: - Persistence

    func testAppearanceSettingsPersistence() {
        let settings = AppearanceSettings(userDefaults: userDefaults)
        XCTAssertEqual(settings.setTheme(.dark, isProEnabled: false), .applied)
        settings.setFont(.monospaced)
        settings.setFontSize(.large)

        let reloaded = AppearanceSettings(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.theme, .dark)
        XCTAssertEqual(reloaded.font, .monospaced)
        XCTAssertEqual(reloaded.fontSize, .large)
    }

    // MARK: - Theme -> ColorScheme mapping

    func testThemeColorSchemeMapping() {
        let settings = AppearanceSettings(userDefaults: userDefaults)

        XCTAssertNil(settings.colorScheme) // default .system

        XCTAssertEqual(settings.setTheme(.light, isProEnabled: false), .applied)
        XCTAssertEqual(settings.colorScheme, .light)

        XCTAssertEqual(settings.setTheme(.dark, isProEnabled: false), .applied)
        XCTAssertEqual(settings.colorScheme, .dark)

        XCTAssertEqual(settings.setTheme(.sepia, isProEnabled: true), .applied)
        XCTAssertNil(settings.colorScheme)
    }

    // MARK: - Sepia detection

    func testSepiaIsDetected() {
        let settings = AppearanceSettings(userDefaults: userDefaults)
        XCTAssertFalse(settings.isSepia)

        XCTAssertEqual(settings.setTheme(.sepia, isProEnabled: true), .applied)
        XCTAssertTrue(settings.isSepia)
    }

    // MARK: - Sepia Pro gate

    func testSetSepiaWithoutProReturnsRequiresPro() {
        let settings = AppearanceSettings(userDefaults: userDefaults)

        let result = settings.setTheme(.sepia, isProEnabled: false)

        XCTAssertEqual(result, .requiresPro)
        XCTAssertEqual(settings.theme, .system)
        XCTAssertFalse(settings.isSepia)
    }

    func testSetSepiaWithProApplies() {
        let settings = AppearanceSettings(userDefaults: userDefaults)

        let result = settings.setTheme(.sepia, isProEnabled: true)

        XCTAssertEqual(result, .applied)
        XCTAssertEqual(settings.theme, .sepia)
    }

    func testSetNonSepiaThemeAlwaysApplies() {
        let settings = AppearanceSettings(userDefaults: userDefaults)

        let result = settings.setTheme(.dark, isProEnabled: false)

        XCTAssertEqual(result, .applied)
        XCTAssertEqual(settings.theme, .dark)
    }
}
