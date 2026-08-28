import Foundation
import SwiftUI
import Observation

/// Theme choice (PLAN.md Feature 11 Appearance section). Sepia is Pro-gated
/// (Feature 12); System/Light/Dark are free.
enum Theme: String, Equatable, Codable, CaseIterable {
    case system
    case light
    case dark
    case sepia
}

/// Font choice (PLAN.md Feature 11 Appearance section). Both are free — the
/// spec lists no additional Pro fonts for v1.
enum FontChoice: String, Equatable, Codable, CaseIterable {
    case system
    case monospaced
}

/// Font size (PLAN.md Feature 11 Appearance section: "Font size", no
/// specific steps named — three sizes is the agreed v1 interpretation).
enum FontSize: String, Equatable, Codable, CaseIterable {
    case small
    case medium
    case large
}

/// Result of a setTheme(_:isProEnabled:) call (Feature 12's Sepia Pro gate).
enum ThemeChangeResult: Equatable {
    case applied
    case requiresPro
}

/// AppearanceSettings — Sprint 5 (PLAN.md Feature 11 Appearance / Feature 12).
/// Single source of truth for theme, font, and font-size, persisted to
/// UserDefaults and applied app-wide from PlainLogApp.
///
/// Design (PLAN.md §4 / Feature 12):
/// - Sepia is the only Pro-gated appearance item. System/Light/Dark themes,
///   both fonts, and font size are all free ("Basic appearance settings").
/// - The gate is model-level: setTheme(.sepia, isProEnabled: false) does NOT
///   apply or persist the change, and returns .requiresPro so the caller
///   (the Settings screen, Piece 5.5) can present the paywall. This piece
///   only builds the gate itself, not that UI.
@MainActor
@Observable
final class AppearanceSettings {

    private static let themeKey = "plainlog.appearance.theme"
    private static let fontKey = "plainlog.appearance.font"
    private static let fontSizeKey = "plainlog.appearance.fontSize"

    private let userDefaults: UserDefaults

    private(set) var theme: Theme
    private(set) var font: FontChoice
    private(set) var fontSize: FontSize

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.theme = Theme(rawValue: userDefaults.string(forKey: Self.themeKey) ?? "") ?? .system
        self.font = FontChoice(rawValue: userDefaults.string(forKey: Self.fontKey) ?? "") ?? .system
        self.fontSize = FontSize(rawValue: userDefaults.string(forKey: Self.fontSizeKey) ?? "") ?? .medium
    }

    // MARK: - Mutations

    /// Sets the theme. Every theme except Sepia applies unconditionally.
    /// Sepia requires isProEnabled == true; otherwise the stored theme is
    /// left untouched and .requiresPro is returned.
    func setTheme(_ newTheme: Theme, isProEnabled: Bool) -> ThemeChangeResult {
        if newTheme == .sepia && !isProEnabled {
            return .requiresPro
        }
        theme = newTheme
        userDefaults.set(newTheme.rawValue, forKey: Self.themeKey)
        return .applied
    }

    /// Sets the font. No Pro gate — both System and Monospaced are free.
    func setFont(_ newFont: FontChoice) {
        font = newFont
        userDefaults.set(newFont.rawValue, forKey: Self.fontKey)
    }

    /// Sets the font size. No Pro gate.
    func setFontSize(_ newSize: FontSize) {
        fontSize = newSize
        userDefaults.set(newSize.rawValue, forKey: Self.fontSizeKey)
    }

    // MARK: - Derived appearance

    /// Maps theme to a SwiftUI ColorScheme. Sepia has no standard
    /// ColorScheme equivalent — it applies via its own custom palette below,
    /// so it maps to nil here (same as System, which also defers to nil).
    var colorScheme: ColorScheme? {
        switch theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        case .sepia: nil
        }
    }

    var isSepia: Bool {
        theme == .sepia
    }

    /// Sepia palette: warm paper tones. Best-effort — visual refinement is
    /// device-QA territory (this piece's scope boundary).
    var sepiaBackground: Color {
        Color(red: 0.96, green: 0.93, blue: 0.86)
    }

    var sepiaForeground: Color {
        Color(red: 0.29, green: 0.22, blue: 0.15)
    }

    /// Maps font size to SwiftUI's DynamicTypeSize for app-wide application.
    var dynamicTypeSize: DynamicTypeSize {
        switch fontSize {
        case .small: .small
        case .medium: .medium
        case .large: .large
        }
    }
}
