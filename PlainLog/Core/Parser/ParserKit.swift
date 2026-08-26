import Foundation

// MARK: - Task parsing

/// Parses task lines per Feature 10.
/// Supported syntax:
///   - [ ] Task     - [x] Task     * [ ] Task     * [x] Task
/// Rules: case-insensitive x, leading whitespace allowed, hyphen or asterisk.
/// Pure — does not modify input.
enum TaskParser {

    static func parse(_ text: String) -> [ParsedTask] {
        var tasks: [ParsedTask] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            if let task = parseLine(String(line)) {
                tasks.append(task)
            }
        }
        return tasks
    }

    private static func parseLine(_ line: String) -> ParsedTask? {
        // Leading whitespace is allowed.
        var rest = line.drop { $0 == " " || $0 == "\t" }

        // Bullet: - or *
        guard let bullet = rest.first, bullet == "-" || bullet == "*" else { return nil }
        rest = rest.dropFirst()

        // Whitespace after the bullet.
        rest = rest.drop { $0 == " " || $0 == "\t" }

        guard rest.first == "[" else { return nil }
        rest = rest.dropFirst()

        // Check character: space = unchecked, x/X = checked (case-insensitive).
        guard let checkChar = rest.first else { return nil }
        let isCompleted: Bool
        if checkChar == " " {
            isCompleted = false
        } else if checkChar == "x" || checkChar == "X" {
            isCompleted = true
        } else {
            return nil
        }
        rest = rest.dropFirst()

        guard rest.first == "]" else { return nil }
        rest = rest.dropFirst()

        // Whitespace after ].
        rest = rest.drop { $0 == " " || $0 == "\t" }

        let text = String(rest)
        guard !text.isEmpty else { return nil }

        return ParsedTask(text: text, isCompleted: isCompleted)
    }
}

// MARK: - Tag parsing

/// Parses tags per Feature 10. Syntax: [tag:name]
/// Allowed name characters: a-z, A-Z, 0-9, -, _ (ASCII only).
/// Pure — does not modify input.
enum TagParser {

    static func parse(_ text: String) -> [ParsedTag] {
        var tags: [ParsedTag] = []
        var index = text.startIndex

        while index < text.endIndex {
            if text[index...].hasPrefix("[tag:") {
                let nameStart = text.index(index, offsetBy: 5) // "[tag:".count
                var nameEnd = nameStart
                while nameEnd < text.endIndex && text[nameEnd] != "]" {
                    nameEnd = text.index(after: nameEnd)
                }

                if nameEnd < text.endIndex && text[nameEnd] == "]" {
                    let name = String(text[nameStart..<nameEnd])
                    if isValidTagName(name) {
                        tags.append(ParsedTag(name: name))
                    }
                    index = text.index(after: nameEnd)
                    continue
                }
            }
            index = text.index(after: index)
        }

        return tags
    }

    /// Feature 10: tag names allow only ASCII a-z, A-Z, 0-9, -, _.
    static func isValidTagName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        return name.allSatisfy { char in
            (char >= "a" && char <= "z") ||
            (char >= "A" && char <= "Z") ||
            (char >= "0" && char <= "9") ||
            char == "-" ||
            char == "_"
        }
    }
}

// MARK: - Expense parsing

/// Parses expenses per Feature 10. Syntax: [expense: AMOUNT DESCRIPTION]
/// Amount required, description optional. Decimal point or comma allowed.
/// Currency symbol ignored. Thousands separators not supported.
/// Pure — does not modify input.
enum ExpenseParser {

    static func parse(_ text: String) -> [ParsedExpense] {
        var expenses: [ParsedExpense] = []
        var index = text.startIndex

        while index < text.endIndex {
            if text[index...].hasPrefix("[expense:") {
                let contentStart = text.index(index, offsetBy: 9) // "[expense:".count
                var contentEnd = contentStart
                while contentEnd < text.endIndex && text[contentEnd] != "]" {
                    contentEnd = text.index(after: contentEnd)
                }

                if contentEnd < text.endIndex && text[contentEnd] == "]" {
                    let content = String(text[contentStart..<contentEnd])
                    if let expense = parseContent(content) {
                        expenses.append(expense)
                    }
                    index = text.index(after: contentEnd)
                    continue
                }
            }
            index = text.index(after: index)
        }

        return expenses
    }

    private static func parseContent(_ content: String) -> ParsedExpense? {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Amount token = everything before the first whitespace.
        // Description = the rest, trimmed.
        let amountToken: String
        let description: String
        if let whitespaceIndex = trimmed.firstIndex(where: { $0.isWhitespace }) {
            amountToken = String(trimmed[trimmed.startIndex..<whitespaceIndex])
            description = String(trimmed[whitespaceIndex...])
                .trimmingCharacters(in: .whitespaces)
        } else {
            amountToken = trimmed
            description = ""
        }

        guard let amount = parseAmount(amountToken) else { return nil }
        return ParsedExpense(amount: amount, description: description)
    }

    private static func parseAmount(_ token: String) -> Decimal? {
        var s = token
        // Strip leading currency symbols.
        while let first = s.first, isCurrencySymbol(first) {
            s.removeFirst()
        }
        // Strip trailing currency symbols.
        while let last = s.last, isCurrencySymbol(last) {
            s.removeLast()
        }
        return parseSimpleDecimal(s)
    }

    /// Parses a simple decimal: digits with at most ONE separator (. or ,)
    /// followed by 1-2 digits. Rejects thousands separators (3 digits after the
    /// separator) per "simple decimals only".
    private static func parseSimpleDecimal(_ s: String) -> Decimal? {
        guard !s.isEmpty else { return nil }

        let separators = s.filter { $0 == "." || $0 == "," }
        guard separators.count <= 1 else { return nil }

        if let sepChar = separators.first {
            guard let sepIndex = s.firstIndex(of: sepChar) else { return nil }
            let beforeSep = s[s.startIndex..<sepIndex]
            let afterSep = s[s.index(after: sepIndex)...]

            guard !beforeSep.isEmpty, beforeSep.allSatisfy({ $0.isNumber }) else { return nil }
            // 1-2 digits after the separator; 3 digits means a thousands separator -> reject.
            guard afterSep.count >= 1, afterSep.count <= 2,
                  afterSep.allSatisfy({ $0.isNumber }) else { return nil }
        } else {
            guard s.allSatisfy({ $0.isNumber }) else { return nil }
        }

        // Normalize comma to dot for Decimal parsing.
        let normalized = s.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    private static func isCurrencySymbol(_ char: Character) -> Bool {
        // $, euro, pound, yen
        return char == "$" || char == "\u{20AC}" || char == "\u{00A3}" || char == "\u{00A5}"
    }
}

// MARK: - ParserKit

/// ParserKit — Sprint 4 (PLAN.md §12).
/// Aggregates task, tag, and expense parsing into a summary model.
/// Pure — does not modify input; parsing happens in memory only.
enum ParserKit {

    static func parseSummary(_ text: String) -> ParsedSummary {
        let tasks = TaskParser.parse(text)
        let tags = TagParser.parse(text)
        let expenses = ExpenseParser.parse(text)

        let completedCount = tasks.filter { $0.isCompleted }.count
        let totalCount = tasks.count

        // Deduplicate tags, preserving first-appearance order.
        var seen = Set<String>()
        var uniqueTags: [String] = []
        for tag in tags where seen.insert(tag.name).inserted {
            uniqueTags.append(tag.name)
        }

        let expenseTotal = expenses.reduce(Decimal.zero) { $0 + $1.amount }

        return ParsedSummary(
            taskCompletedCount: completedCount,
            taskTotalCount: totalCount,
            tags: uniqueTags,
            expenseTotal: expenseTotal
        )
    }
}
