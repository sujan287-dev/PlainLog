import Foundation

/// A block-level Markdown node for the Feature 05 subset.
/// Inline styling (bold, italic, code, tags, expenses) is represented inside
/// each block's inline spans. The renderer maps these nodes to SwiftUI views.
enum MarkdownNode: Equatable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case bulletItem(text: String)
    case numberedItem(number: Int, text: String)
    case checkbox(checked: Bool, text: String)
    case codeBlock(language: String?, code: String)
    case blank
}

/// An inline span within a text run. Used by the inline parser.
enum InlineSpan: Equatable {
    case text(String)
    case bold(String)
    case italic(String)
    case inlineCode(String)
    case tag(String)              // [tag:name]
    case expense(String)          // [expense: ...]
}
