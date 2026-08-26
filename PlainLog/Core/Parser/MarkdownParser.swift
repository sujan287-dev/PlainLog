import Foundation

/// Line-oriented block parser for the Feature 05 subset.
/// Pure, no I/O, no state. Returns nil on any unrecoverable parse error
/// (caller falls back to raw text).
enum MarkdownParser {

    /// Parse a Markdown document into block-level nodes.
    /// Returns nil if parsing hits an unrecoverable error (triggers fallback).
    static func parse(_ text: String) -> [MarkdownNode]? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var nodes: [MarkdownNode] = []
        var i = 0

        while i < lines.count {
            let line = String(lines[i])

            // Blank line
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                nodes.append(.blank)
                i += 1
                continue
            }

            // Code block: ```
            if line.hasPrefix("```") {
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let lang: String? = language.isEmpty ? nil : language
                var code = ""
                i += 1
                while i < lines.count {
                    let cl = String(lines[i])
                    if cl == "```" {
                        i += 1
                        break
                    }
                    if !code.isEmpty { code.append("\n") }
                    code.append(cl)
                    i += 1
                }
                nodes.append(.codeBlock(language: lang, code: code))
                continue
            }

            // Heading: # ... (1-6 hashes)
            if let (level, text) = scanHeading(line) {
                nodes.append(.heading(level: level, text: text))
                i += 1
                continue
            }

            // Checkbox: - [ ] or - [x] (or * [ ] / * [x])
            if let (checked, text) = scanCheckbox(line) {
                nodes.append(.checkbox(checked: checked, text: text))
                i += 1
                continue
            }

            // Bullet item: - or *
            if let text = scanBullet(line) {
                nodes.append(.bulletItem(text: text))
                i += 1
                continue
            }

            // Numbered item: 1. 2. etc.
            if let (number, text) = scanNumbered(line) {
                nodes.append(.numberedItem(number: number, text: text))
                i += 1
                continue
            }

            // Paragraph (default)
            nodes.append(.paragraph(text: line))
            i += 1
        }

        return nodes
    }

    // MARK: - Block scanners

    private static func scanHeading(_ line: String) -> (Int, String)? {
        var level = 0
        var i = line.startIndex
        while i < line.endIndex && line[i] == "#" {
            level += 1
            i = line.index(after: i)
        }
        guard level >= 1 && level <= 6 else { return nil }
        guard i < line.endIndex && line[i] == " " else { return nil }
        let text = String(line[line.index(after: i)...])
        return (level, text)
    }

    private static func scanCheckbox(_ line: String) -> (Bool, String)? {
        let trimmed = line.trimmingCharacters(in: .init(charactersIn: " \t"))
        let prefixPatterns = ["- [ ] ", "- [x] ", "- [X] ", "* [ ] ", "* [x] ", "* [X] "]
        for prefix in prefixPatterns {
            if trimmed.hasPrefix(prefix) {
                let checked = prefix.contains("x") || prefix.contains("X")
                let text = String(trimmed.dropFirst(prefix.count))
                return (checked, text)
            }
        }
        return nil
    }

    private static func scanBullet(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .init(charactersIn: " \t"))
        if trimmed.hasPrefix("- ") {
            return String(trimmed.dropFirst(2))
        }
        if trimmed.hasPrefix("* ") {
            return String(trimmed.dropFirst(2))
        }
        return nil
    }

    private static func scanNumbered(_ line: String) -> (Int, String)? {
        let trimmed = line.trimmingCharacters(in: .init(charactersIn: " \t"))
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let numberPart = trimmed[trimmed.startIndex..<dotIndex]
        guard numberPart.allSatisfy({ $0.isNumber }) else { return nil }
        guard let number = Int(numberPart) else { return nil }
        let afterDot = trimmed.index(after: dotIndex)
        guard afterDot < trimmed.endIndex && trimmed[afterDot] == " " else { return nil }
        let text = String(trimmed[trimmed.index(after: afterDot)...])
        return (number, text)
    }
}
