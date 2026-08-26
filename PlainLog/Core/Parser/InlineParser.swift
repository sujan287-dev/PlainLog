import Foundation

/// Character-scanning inline parser for the Feature 05 inline subset:
/// bold (**), italic (*), inline code (`), tags ([tag:name]), expenses
/// ([expense: ...]).
///
/// Kept character-based (no regex) to keep edge cases deterministic.
/// Returns nil if parsing hits an unrecoverable inconsistency.
enum InlineParser {

    /// Parse inline spans from a text string.
    /// Returns nil if the input cannot be parsed safely (triggers fallback).
    static func parse(_ input: String) -> [InlineSpan]? {
        var spans: [InlineSpan] = []
        var current = ""
        var index = input.startIndex

        while index < input.endIndex {
            let char = input[index]

            // Tag: [tag:name]
            if char == "[" && input[index...].hasPrefix("[tag:") {
                if let (tag, end) = scanTag(input, from: index) {
                    if !current.isEmpty {
                        spans.append(.text(current))
                        current = ""
                    }
                    spans.append(.tag(tag))
                    index = end
                    continue
                } else {
                    return nil  // Malformed tag -> fallback
                }
            }

            // Expense: [expense: ...]
            if char == "[" && input[index...].hasPrefix("[expense:") {
                if let (expense, end) = scanExpense(input, from: index) {
                    if !current.isEmpty {
                        spans.append(.text(current))
                        current = ""
                    }
                    spans.append(.expense(expense))
                    index = end
                    continue
                } else {
                    return nil  // Malformed expense -> fallback
                }
            }

            // Inline code: `...`
            if char == "`" {
                if let (code, end) = scanInlineCode(input, from: index) {
                    if !current.isEmpty {
                        spans.append(.text(current))
                        current = ""
                    }
                    spans.append(.inlineCode(code))
                    index = end
                    continue
                } else {
                    // Unmatched backtick: treat as literal text
                    current.append(char)
                    index = input.index(after: index)
                    continue
                }
            }

            // Bold: **...**
            if char == "*" && nextChar(input, after: index) == "*" {
                if let (bold, end) = scanBold(input, from: index) {
                    if !current.isEmpty {
                        spans.append(.text(current))
                        current = ""
                    }
                    spans.append(.bold(bold))
                    index = end
                    continue
                } else {
                    // Unmatched **: treat first * as literal
                    current.append(char)
                    index = input.index(after: index)
                    continue
                }
            }

            // Italic: *...*
            if char == "*" {
                if let (italic, end) = scanItalic(input, from: index) {
                    if !current.isEmpty {
                        spans.append(.text(current))
                        current = ""
                    }
                    spans.append(.italic(italic))
                    index = end
                    continue
                } else {
                    current.append(char)
                    index = input.index(after: index)
                    continue
                }
            }

            // Plain character
            current.append(char)
            index = input.index(after: index)
        }

        if !current.isEmpty {
            spans.append(.text(current))
        }

        return spans
    }

    // MARK: - Scanners

    private static func nextChar(_ s: String, after i: String.Index) -> Character? {
        let next = s.index(after: i)
        return next < s.endIndex ? s[next] : nil
    }

    private static func scanTag(_ s: String, from start: String.Index) -> (String, String.Index)? {
        // Expected format: [tag:name]
        let prefix = "[tag:"
        guard s[start...].hasPrefix(prefix) else { return nil }
        var i = s.index(start, offsetBy: prefix.count)
        var name = ""
        while i < s.endIndex && s[i] != "]" {
            name.append(s[i])
            i = s.index(after: i)
        }
        guard i < s.endIndex && s[i] == "]" else { return nil }
        guard !name.isEmpty else { return nil }
        // Validate name characters (a-z, A-Z, 0-9, -, _)
        guard name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else {
            return nil
        }
        return (name, s.index(after: i))
    }

    private static func scanExpense(_ s: String, from start: String.Index) -> (String, String.Index)? {
        let prefix = "[expense:"
        guard s[start...].hasPrefix(prefix) else { return nil }
        var i = s.index(start, offsetBy: prefix.count)
        var content = ""
        while i < s.endIndex && s[i] != "]" {
            content.append(s[i])
            i = s.index(after: i)
        }
        guard i < s.endIndex && s[i] == "]" else { return nil }
        // Trim leading/trailing whitespace from content
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return (trimmed, s.index(after: i))
    }

    private static func scanInlineCode(_ s: String, from start: String.Index) -> (String, String.Index)? {
        guard s[start] == "`" else { return nil }
        var i = s.index(after: start)
        var code = ""
        while i < s.endIndex && s[i] != "`" {
            code.append(s[i])
            i = s.index(after: i)
        }
        guard i < s.endIndex && s[i] == "`" else { return nil }
        return (code, s.index(after: i))
    }

    private static func scanBold(_ s: String, from start: String.Index) -> (String, String.Index)? {
        let s1 = s.index(after: start)
        guard s1 < s.endIndex && s[s1] == "*" else { return nil }
        var i = s.index(after: s1)
        var bold = ""
        while i < s.endIndex {
            if s[i] == "*" {
                let next = s.index(after: i)
                if next < s.endIndex && s[next] == "*" {
                    return (bold, s.index(after: next))
                }
            }
            bold.append(s[i])
            i = s.index(after: i)
        }
        return nil  // Unmatched **
    }

    private static func scanItalic(_ s: String, from start: String.Index) -> (String, String.Index)? {
        guard s[start] == "*" else { return nil }
        // Make sure this isn't ** (which is bold)
        let next = s.index(after: start)
        guard next < s.endIndex && s[next] != "*" else { return nil }
        var i = next
        var italic = ""
        while i < s.endIndex {
            if s[i] == "*" {
                // Make sure the closing * isn't followed by another *
                let afterClose = s.index(after: i)
                if afterClose >= s.endIndex || s[afterClose] != "*" {
                    return (italic, afterClose)
                }
            }
            italic.append(s[i])
            i = s.index(after: i)
        }
        return nil  // Unmatched *
    }
}
