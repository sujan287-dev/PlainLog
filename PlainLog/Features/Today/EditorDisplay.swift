import Foundation

/// Editor chrome display logic and copy (Sprint 3).
/// All copy is VERBATIM from PLAN.md Feature 04 and enforced by
/// EditorDisplayTests. Do not paraphrase. Do not edit without updating
/// PLAN.md and the tests together.
enum SaveStatusDisplay {

    /// Maps model states to Feature 04's save status indicator text.
    /// Returns nil when no indicator should be shown.
    /// File-level states take precedence because they block editing entirely.
    static func text(saveState: SaveState, fileState: DailyFileState?) -> String? {
        if fileState == .downloading {
            return "Waiting for iCloud"
        }

        switch saveState {
        case .idle:
            return nil
        case .waitingToSave:
            return "Waiting to save"
        case .saving:
            return "Saving\u{2026}"
        case .saved:
            return "Saved"
        case .saveFailed, .conflictDetectedDuringSave, .targetFileAlreadyExists:
            return "Save failed"
        case .accessLostDuringSave:
            return "Folder access lost"
        }
    }
}

/// Static editor copy (verbatim, test-enforced).
enum EditorCopy {
    /// Feature 04 placeholder.
    /// Curly apostrophe (U+2019) and ellipsis (U+2026) exactly as in PLAN.md,
    /// written as explicit escapes so the characters cannot be silently swapped.
    static let placeholder = "Write today\u{2019}s log\u{2026}"

    /// Feature 04 large file warning (verbatim, test-enforced).
    static let largeFileWarning = "This file is large.\nEditing may be slower than usual."
}

/// Feature 10 summary bar's expense-total formatting.
enum ExpenseTotalDisplay {

    /// Formats a Decimal expense total per the Feature 10 summary bar example
    /// ("Expenses: 118.75"). Money stays Decimal end-to-end — bridged through
    /// NSDecimalNumber only for this formatter call, never through Double.
    ///
    /// A fresh NumberFormatter is built on every call rather than shared as a
    /// static instance: NumberFormatter is NOT thread-safe, and Sprint 5's
    /// ExportKit will call this from a background task. Construction cost is
    /// negligible at the call rates here (summary-bar renders, debounced to
    /// 300ms+ intervals; future weekly-export runs).
    static func text(for total: Decimal) -> String {
        let formatter = NumberFormatter()
        // Locale is explicitly en_US_POSIX, NEVER the device locale: PLAN.md's
        // summary bar example and this app's tests use "." as the decimal
        // separator (e.g. "118.75"). The device locale could format the same
        // value as "118,75", breaking display parity with the spec and making
        // output non-deterministic across regions. Grouping is disabled so no
        // comma can appear anywhere in the output, in either role (decimal or
        // thousands separator).
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2

        let number = NSDecimalNumber(decimal: total)
        if let formatted = formatter.string(from: number) {
            return formatted
        }
        // Not expected for finite Decimal values, but never crash: fall back
        // to a plain string interpolation of the Decimal.
        return "\(total)"
    }
}
