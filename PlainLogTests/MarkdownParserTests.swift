import XCTest
@testable import PlainLog

/// Tests for MarkdownParser and InlineParser (Feature 05 subset).
final class MarkdownParserTests: XCTestCase {

    // MARK: - Block-level parsing

    func testParseHeadings() {
        let nodes = MarkdownParser.parse("# H1\n## H2\n### H3")
        XCTAssertEqual(nodes, [
            .heading(level: 1, text: "H1"),
            .heading(level: 2, text: "H2"),
            .heading(level: 3, text: "H3"),
        ])
    }

    func testParseBulletItems() {
        let nodes = MarkdownParser.parse("- a\n* b")
        XCTAssertEqual(nodes, [
            .bulletItem(text: "a"),
            .bulletItem(text: "b"),
        ])
    }

    func testParseNumberedItems() {
        let nodes = MarkdownParser.parse("1. first\n2. second")
        XCTAssertEqual(nodes, [
            .numberedItem(number: 1, text: "first"),
            .numberedItem(number: 2, text: "second"),
        ])
    }

    func testParseCheckboxes() {
        let nodes = MarkdownParser.parse("- [ ] open\n- [x] done\n- [X] DONE")
        XCTAssertEqual(nodes, [
            .checkbox(checked: false, text: "open"),
            .checkbox(checked: true, text: "done"),
            .checkbox(checked: true, text: "DONE"),
        ])
    }

    func testParseCodeBlock() {
        let text = "```swift\nlet x = 1\n```"
        let nodes = MarkdownParser.parse(text)
        XCTAssertEqual(nodes, [
            .codeBlock(language: "swift", code: "let x = 1"),
        ])
    }

    func testParseCodeBlockWithoutLanguage() {
        let text = "```\nraw\n```"
        let nodes = MarkdownParser.parse(text)
        XCTAssertEqual(nodes, [
            .codeBlock(language: nil, code: "raw"),
        ])
    }

    func testParseBlankLines() {
        let nodes = MarkdownParser.parse("a\n\nb")
        XCTAssertEqual(nodes, [
            .paragraph(text: "a"),
            .blank,
            .paragraph(text: "b"),
        ])
    }

    func testParseMixedDocument() {
        let text = """
        # Log
        - [ ] task one
        - [x] task two
        - bullet
        1. numbered

        **bold** and *italic*
        """
        let nodes = MarkdownParser.parse(text)
        // 7 lines: heading, checkbox, checkbox, bullet, numbered, blank, paragraph.
        // (Verified against the literal input — see Piece 3.4 self-review.)
        XCTAssertEqual(nodes.count, 7)
    }

    // MARK: - Inline parsing

    func testInlineBold() {
        let spans = InlineParser.parse("**hello**")
        XCTAssertEqual(spans, [.bold("hello")])
    }

    func testInlineItalic() {
        let spans = InlineParser.parse("*hello*")
        XCTAssertEqual(spans, [.italic("hello")])
    }

    func testInlineCode() {
        let spans = InlineParser.parse("`code`")
        XCTAssertEqual(spans, [.inlineCode("code")])
    }

    func testInlineTag() {
        let spans = InlineParser.parse("[tag:work]")
        XCTAssertEqual(spans, [.tag("work")])
    }

    func testInlineTagWithHyphenAndUnderscore() {
        let spans = InlineParser.parse("[tag:follow-up_1]")
        XCTAssertEqual(spans, [.tag("follow-up_1")])
    }

    func testInlineExpense() {
        let spans = InlineParser.parse("[expense: 15.50 lunch]")
        XCTAssertEqual(spans, [.expense("15.50 lunch")])
    }

    func testInlineMixedContent() {
        let spans = InlineParser.parse("Hello **world** and *friend*")
        XCTAssertEqual(spans, [
            .text("Hello "),
            .bold("world"),
            .text(" and "),
            .italic("friend"),
        ])
    }

    func testInlineTagInvalidReturnsNil() {
        // Empty name
        XCTAssertNil(InlineParser.parse("[tag:]"))
        // Space in name (invalid)
        XCTAssertNil(InlineParser.parse("[tag:work meeting]"))
    }

    func testInlineUnmatchedBacktickReturnsTextLiteral() {
        // Single unmatched backtick should be treated as literal text, not a failure.
        let spans = InlineParser.parse("hello ` world")
        XCTAssertEqual(spans, [.text("hello ` world")])
    }

    func testInlineUnmatchedBoldReturnsTextLiteral() {
        // Unmatched ** should be treated as literal text.
        let spans = InlineParser.parse("hello ** world")
        XCTAssertEqual(spans, [.text("hello ** world")])
    }

    func testInlineAsteriskAsteriskEdgeCasePinnedBehavior() {
        // Pins current, deterministic (if unintuitive) behavior for "*a**":
        // the '*' right after "a" isn't accepted as the italic close because
        // it's immediately followed by another '*' (which scanItalic treats
        // as "this might be a bold close, not mine"), so it's absorbed into
        // the italic content instead, and the final '*' closes it.
        let spans = InlineParser.parse("*a**")
        XCTAssertEqual(spans, [.italic("a*")])
    }
}
