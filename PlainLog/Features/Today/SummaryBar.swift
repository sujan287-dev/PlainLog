import SwiftUI

/// Summary Bar — Sprint 4 (PLAN.md Feature 10).
/// Read-only overview of the document's parsed tasks, expenses, and tags.
/// No interactivity in v1 — tapping and filtering are deferred.
struct SummaryBar: View {
    let summary: ParsedSummary

    var body: some View {
        HStack(spacing: 12) {
            Text("Expenses: \(ExpenseTotalDisplay.text(for: summary.expenseTotal))")

            Text("Tasks: \(summary.taskCompletedCount)/\(summary.taskTotalCount)")

            if !summary.tags.isEmpty {
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
