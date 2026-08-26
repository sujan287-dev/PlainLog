import XCTest
@testable import PlainLog

/// Sprint 4 · Piece 4.1 — ParserKit tests (Feature 10).
final class ParserKitTests: XCTestCase {

    private func decimal(_ s: String) throws -> Decimal {
        try XCTUnwrap(Decimal(string: s))
    }

    // MARK: - Task parsing

    func testUncheckedTaskWithHyphen() {
        let tasks = TaskParser.parse("- [ ] Buy milk")
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].text, "Buy milk")
        XCTAssertFalse(tasks[0].isCompleted)
    }

    func testCheckedTaskLowercaseX() {
        let tasks = TaskParser.parse("- [x] Buy milk")
        XCTAssertEqual(tasks.count, 1)
        XCTAssertTrue(tasks[0].isCompleted)
    }

    func testCheckedTaskUppercaseX() {
        let tasks = TaskParser.parse("- [X] Buy milk")
        XCTAssertEqual(tasks.count, 1)
        XCTAssertTrue(tasks[0].isCompleted)
    }

    func testTaskWithAsterisk() {
        let tasks = TaskParser.parse("* [ ] Buy milk")
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].text, "Buy milk")
    }

    func testTaskWithLeadingWhitespace() {
        let tasks = TaskParser.parse("   - [ ] Indented task")
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].text, "Indented task")
    }

    func testTaskWithEmptyTextIsIgnored() {
        let tasks = TaskParser.parse("- [ ] ")
        XCTAssertEqual(tasks.count, 0)
    }

    func testTaskWithInvalidCheckCharIsIgnored() {
        let tasks = TaskParser.parse("- [y] Buy milk")
        XCTAssertEqual(tasks.count, 0)
    }

    func testNonTaskLineIsIgnored() {
        let tasks = TaskParser.parse("Just a regular line")
        XCTAssertEqual(tasks.count, 0)
    }

    func testMultipleTasksCountedCorrectly() {
        let text = """
        - [ ] Task one
        - [x] Task two
        * [ ] Task three
        * [X] Task four
        Not a task
        """
        let tasks = TaskParser.parse(text)
        XCTAssertEqual(tasks.count, 4)
        XCTAssertEqual(tasks.filter { $0.isCompleted }.count, 2)
    }

    // MARK: - Tag parsing

    func testValidTag() {
        let tags = TagParser.parse("[tag:idea]")
        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags[0].name, "idea")
    }

    func testTagWithHyphen() {
        let tags = TagParser.parse("[tag:follow-up]")
        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags[0].name, "follow-up")
    }

    func testTagWithUnderscoreAndDigit() {
        let tags = TagParser.parse("[tag:home_1]")
        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags[0].name, "home_1")
    }

    func testEmptyTagIsIgnored() {
        let tags = TagParser.parse("[tag:]")
        XCTAssertEqual(tags.count, 0)
    }

    func testTagWithSpaceIsIgnored() {
        let tags = TagParser.parse("[tag:idea extra]")
        XCTAssertEqual(tags.count, 0)
    }

    func testTagWithSpaceVariantIsIgnored() {
        let tags = TagParser.parse("[tag:work meeting]")
        XCTAssertEqual(tags.count, 0)
    }

    func testMultipleTags() {
        let tags = TagParser.parse("[tag:idea] and [tag:health]")
        XCTAssertEqual(tags.count, 2)
        XCTAssertEqual(tags[0].name, "idea")
        XCTAssertEqual(tags[1].name, "health")
    }

    func testTagInsideTaskLine() {
        let tags = TagParser.parse("- [ ] Buy milk [tag:shopping]")
        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags[0].name, "shopping")
    }

    // MARK: - Expense parsing

    func testExpenseWithDecimalPoint() throws {
        let expenses = ExpenseParser.parse("[expense: 15.50 lunch]")
        XCTAssertEqual(expenses.count, 1)
        XCTAssertEqual(expenses[0].amount, try decimal("15.50"))
        XCTAssertEqual(expenses[0].description, "lunch")
    }

    func testExpenseWholeNumber() throws {
        let expenses = ExpenseParser.parse("[expense: 4 coffee]")
        XCTAssertEqual(expenses.count, 1)
        XCTAssertEqual(expenses[0].amount, try decimal("4"))
        XCTAssertEqual(expenses[0].description, "coffee")
    }

    func testExpenseWithCommaDecimal() throws {
        let expenses = ExpenseParser.parse("[expense: 12,50 snack]")
        XCTAssertEqual(expenses.count, 1)
        XCTAssertEqual(expenses[0].amount, try decimal("12.50"))
        XCTAssertEqual(expenses[0].description, "snack")
    }

    func testExpenseWithCurrencySymbol() throws {
        let expenses = ExpenseParser.parse("[expense: $99 gym]")
        XCTAssertEqual(expenses.count, 1)
        XCTAssertEqual(expenses[0].amount, try decimal("99"))
        XCTAssertEqual(expenses[0].description, "gym")
    }

    func testExpenseWithCurrencyAndDecimal() throws {
        let expenses = ExpenseParser.parse("[expense: $15.50 lunch]")
        XCTAssertEqual(expenses.count, 1)
        XCTAssertEqual(expenses[0].amount, try decimal("15.50"))
        XCTAssertEqual(expenses[0].description, "lunch")
    }

    func testExpenseWithTrailingCurrencySymbol() throws {
        let expenses = ExpenseParser.parse("[expense: 99$ gym]")
        XCTAssertEqual(expenses.count, 1)
        XCTAssertEqual(expenses[0].amount, try decimal("99"))
        XCTAssertEqual(expenses[0].description, "gym")
    }

    func testExpenseWithoutDescription() throws {
        let expenses = ExpenseParser.parse("[expense: 15.50]")
        XCTAssertEqual(expenses.count, 1)
        XCTAssertEqual(expenses[0].amount, try decimal("15.50"))
        XCTAssertEqual(expenses[0].description, "")
    }

    func testExpenseWithMultiWordDescription() throws {
        let expenses = ExpenseParser.parse("[expense: 15.50 lunch with friends]")
        XCTAssertEqual(expenses.count, 1)
        XCTAssertEqual(expenses[0].description, "lunch with friends")
    }

    func testExpenseWithoutAmountIsIgnored() {
        let expenses = ExpenseParser.parse("[expense: lunch]")
        XCTAssertEqual(expenses.count, 0)
    }

    func testExpenseEmptyIsIgnored() {
        let expenses = ExpenseParser.parse("[expense: ]")
        XCTAssertEqual(expenses.count, 0)
    }

    func testExpenseWithThousandsSeparatorIsIgnored() {
        let expenses = ExpenseParser.parse("[expense: 1,000 big purchase]")
        XCTAssertEqual(expenses.count, 0)
    }

    func testExpenseWithDotThousandsIsIgnored() {
        let expenses = ExpenseParser.parse("[expense: 1.000 big purchase]")
        XCTAssertEqual(expenses.count, 0)
    }

    func testMultipleExpensesParsed() {
        let text = """
        [expense: 15.50 lunch]
        [expense: 4 coffee]
        """
        let expenses = ExpenseParser.parse(text)
        XCTAssertEqual(expenses.count, 2)
    }

    // MARK: - Summary aggregation

    func testSummaryAggregatesCorrectly() throws {
        let text = """
        # Log
        - [ ] Open task
        - [x] Done task
        - [ ] Another open
        [tag:idea]
        [tag:health]
        [tag:idea]
        [expense: 10.00 lunch]
        [expense: 5.50 coffee]
        """
        let summary = ParserKit.parseSummary(text)

        XCTAssertEqual(summary.taskTotalCount, 3)
        XCTAssertEqual(summary.taskCompletedCount, 1)
        XCTAssertEqual(summary.tags, ["idea", "health"])
        XCTAssertEqual(summary.expenseTotal, try decimal("15.50"))
    }

    func testSummaryEmptyText() {
        let summary = ParserKit.parseSummary("")
        XCTAssertEqual(summary.taskTotalCount, 0)
        XCTAssertEqual(summary.taskCompletedCount, 0)
        XCTAssertEqual(summary.tags, [])
        XCTAssertEqual(summary.expenseTotal, Decimal.zero)
    }

    func testParserDoesNotModifyInput() {
        let text = "- [ ] Task [tag:a] [expense: 1 x]"
        let original = text
        _ = ParserKit.parseSummary(text)
        XCTAssertEqual(text, original)
    }
}
