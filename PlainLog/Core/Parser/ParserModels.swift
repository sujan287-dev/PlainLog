import Foundation

/// A parsed task from a daily log (Feature 10).
struct ParsedTask: Equatable {
    let text: String
    let isCompleted: Bool
}

/// A parsed tag from a daily log (Feature 10).
struct ParsedTag: Equatable {
    let name: String
}

/// A parsed expense from a daily log (Feature 10).
/// Amount is stored as Decimal to avoid floating-point errors.
struct ParsedExpense: Equatable {
    let amount: Decimal
    let description: String
}

/// Aggregated summary of a daily log (Feature 10).
struct ParsedSummary: Equatable {
    let taskCompletedCount: Int
    let taskTotalCount: Int
    /// Unique tag names in order of first appearance.
    let tags: [String]
    let expenseTotal: Decimal
}
