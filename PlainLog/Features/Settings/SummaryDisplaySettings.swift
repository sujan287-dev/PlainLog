import Foundation
import Observation

/// SummaryDisplaySettings — Sprint 5 · Piece 5.5 (PLAN.md Feature 11 Summary
/// section). Backs the Settings screen's "Default currency symbol" / "Show
/// expense total" / "Show task count" / "Show tags" rows with real,
/// persisted state.
///
/// Scope note: this piece builds the Settings screen only. Making the daily
/// summary bar (Sprint 4's SummaryBar/ParserKit) actually RESPECT these
/// preferences would mean touching those existing Sprint 4 files, which are
/// out of scope here (read-only per this piece's boundaries). So this model
/// is intentionally self-contained to the Settings feature — not injected
/// into the app-wide environment — until a future piece wires it in.
@MainActor
@Observable
final class SummaryDisplaySettings {

    private static let currencySymbolKey = "plainlog.summary.currencySymbol"
    private static let showExpenseTotalKey = "plainlog.summary.showExpenseTotal"
    private static let showTaskCountKey = "plainlog.summary.showTaskCount"
    private static let showTagsKey = "plainlog.summary.showTags"

    private let userDefaults: UserDefaults

    private(set) var defaultCurrencySymbol: String
    private(set) var showExpenseTotal: Bool
    private(set) var showTaskCount: Bool
    private(set) var showTags: Bool

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.defaultCurrencySymbol = userDefaults.string(forKey: Self.currencySymbolKey) ?? "$"
        self.showExpenseTotal = (userDefaults.object(forKey: Self.showExpenseTotalKey) as? Bool) ?? true
        self.showTaskCount = (userDefaults.object(forKey: Self.showTaskCountKey) as? Bool) ?? true
        self.showTags = (userDefaults.object(forKey: Self.showTagsKey) as? Bool) ?? true
    }

    func setDefaultCurrencySymbol(_ symbol: String) {
        defaultCurrencySymbol = symbol
        userDefaults.set(symbol, forKey: Self.currencySymbolKey)
    }

    func setShowExpenseTotal(_ value: Bool) {
        showExpenseTotal = value
        userDefaults.set(value, forKey: Self.showExpenseTotalKey)
    }

    func setShowTaskCount(_ value: Bool) {
        showTaskCount = value
        userDefaults.set(value, forKey: Self.showTaskCountKey)
    }

    func setShowTags(_ value: Bool) {
        showTags = value
        userDefaults.set(value, forKey: Self.showTagsKey)
    }
}
