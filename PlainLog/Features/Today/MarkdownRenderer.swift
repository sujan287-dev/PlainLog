import SwiftUI

/// Renders parsed Markdown nodes as SwiftUI views.
/// Block-level parsing (MarkdownParser) never fails, so there's no raw-text
/// fallback at this level — only renderInline's inline-parse fallback below,
/// which can genuinely fail on malformed inline syntax.
struct MarkdownRenderer: View {
    let nodes: [MarkdownNode]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                    renderNode(node)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func renderNode(_ node: MarkdownNode) -> some View {
        switch node {
        case .heading(let level, let text):
            Text(renderInline(text))
                .font(headingFont(for: level))
                .bold()

        case .paragraph(let text):
            Text(renderInline(text))

        case .bulletItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                Text(renderInline(text))
            }

        case .numberedItem(let number, let text):
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                    .monospacedDigit()
                Text(renderInline(text))
            }

        case .checkbox(let checked, let text):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(checked ? .green : .secondary)
                Text(renderInline(text))
                    .strikethrough(checked)
                    .foregroundStyle(checked ? .secondary : .primary)
            }

        case .codeBlock(let language, let code):
            VStack(alignment: .leading, spacing: 4) {
                if let language {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

        case .blank:
            Color.clear.frame(height: 4)
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .largeTitle
        case 2: return .title
        case 3: return .title2
        case 4: return .title3
        case 5: return .headline
        default: return .subheadline
        }
    }

    /// Renders inline spans into an AttributedString for SwiftUI Text.
    private func renderInline(_ text: String) -> AttributedString {
        guard let spans = InlineParser.parse(text) else {
            // Inline parse failure: return raw text (block-level parse succeeded
            // but inline failed; partial render is acceptable here).
            return AttributedString(text)
        }

        var result = AttributedString()
        for span in spans {
            switch span {
            case .text(let s):
                result.append(AttributedString(s))
            case .bold(let s):
                var attr = AttributedString(s)
                attr.inlinePresentationIntent = .stronglyEmphasized
                result.append(attr)
            case .italic(let s):
                var attr = AttributedString(s)
                attr.inlinePresentationIntent = .emphasized
                result.append(attr)
            case .inlineCode(let s):
                var attr = AttributedString(s)
                attr.font = .system(.body, design: .monospaced)
                attr.backgroundColor = Color(.secondarySystemBackground)
                result.append(attr)
            case .tag(let name):
                var attr = AttributedString("[\(name)]")
                attr.foregroundColor = .blue
                attr.font = .system(.body, design: .monospaced)
                result.append(attr)
            case .expense(let content):
                var attr = AttributedString("[\(content)]")
                attr.foregroundColor = .orange
                attr.font = .system(.body, design: .monospaced)
                result.append(attr)
            }
        }
        return result
    }
}
