import Foundation
import Observation

/// SummaryDisplaySettings — Sprint 5 · Piece 5.5 (PLAN.md Feature 11 Summary
/// section), lifted to the app-wide environment in Piece 5.6 (PLAN.md
/// Feature 10 requirement 10: "Expense totals display using chosen currency
/// symbol"). Backs the Settings screen's "Default currency symbol" / "Show
/// expense total" / "Show task count" / "Show tags" rows AND SummaryBar's
/// actual rendering with the same persisted state — one source of truth,
/// instantiated once in PlainLogApp and read via @Environment by both.
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
        // Empty by default (not "$"): Feature 10's own summary bar example
        // ("Expenses: 118.75") shows no symbol at all, and this default must
        // reproduce it exactly until the user chooses one.
        self.defaultCurrencySymbol = userDefaults.string(forKey: Self.currencySymbolKey) ?? ""
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
