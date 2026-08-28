import SwiftUI

/// Summary Bar — Sprint 4 (PLAN.md Feature 10), wired to display settings in
/// Sprint 5 · Piece 5.6 (PLAN.md Feature 11 Summary section).
/// Read-only overview of the document's parsed tasks, expenses, and tags.
/// No interactivity in v1 — tapping and filtering are deferred.
struct SummaryBar: View {
    let summary: ParsedSummary

    @Environment(SummaryDisplaySettings.self) private var displaySettings

    /// True when at least one segment will actually render. Guards against
    /// an empty HStack with stray spacing when every toggle is off, or when
    /// tags are shown but the document simply has none (the tags segment's
    /// own pre-existing condition, unchanged).
    private var hasVisibleSegment: Bool {
        displaySettings.showExpenseTotal
            || displaySettings.showTaskCount
            || (displaySettings.showTags && !summary.tags.isEmpty)
    }

    var body: some View {
        if hasVisibleSegment {
            HStack(spacing: 12) {
                if displaySettings.showExpenseTotal {
                    Text(SummaryBarSegments.expenseText(
                        symbol: displaySettings.defaultCurrencySymbol,
                        total: summary.expenseTotal
                    ))
                }

                if displaySettings.showTaskCount {
                    Text("Tasks: \(summary.taskCompletedCount)/\(summary.taskTotalCount)")
                }

                if displaySettings.showTags, !summary.tags.isEmpty {
                    Text("Tags: \(summary.tags.joined(separator: ", "))")
                        .lineLimit(1)
                        .truncationMode(.tail)
                        // Lower priority than the Expenses/Tasks segments so a
                        // long tag list is the one that shrinks/truncates first;
                        // it never squeezes its siblings out of the row.
                        .layoutPriority(-1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

/// Summary bar segment formatting that needs logic beyond a plain verbatim
/// string (unlike EditorDisplay's SaveStatusDisplay/EditorCopy constants).
enum SummaryBarSegments {

    /// "Expenses: <symbol><total>" with a trimmed, non-empty symbol prefixed
    /// directly onto the formatted total, or "Expenses: <total>" when the
    /// symbol is empty/whitespace-only — the default, which reproduces
    /// Feature 10's own example ("Expenses: 118.75") exactly. Reuses
    /// ExpenseTotalDisplay's existing formatter unchanged (en_US_POSIX, no
    /// grouping, 0–2 fraction digits) — only the symbol prefix is new.
    static func expenseText(symbol: String, total: Decimal) -> String {
        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = ExpenseTotalDisplay.text(for: total)
        guard !trimmedSymbol.isEmpty else {
            return "Expenses: \(amount)"
        }
        return "Expenses: \(trimmedSymbol)\(amount)"
    }
}
