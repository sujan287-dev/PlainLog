import XCTest
@testable import PlainLog

/// Sprint 5 · Piece 5.3 — ExportKit tests. Uses a real FileIOService against
/// a throwaway temp folder (never a user folder), matching the pattern from
/// FileIOServiceTests/DocumentStoreTests. No StoreKit dependency.
final class ExportKitTests: XCTestCase {

    private var fileIO: FileIOService!
    private var testFolder: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileIO = FileIOService()
        testFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: testFolder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let testFolder {
            try? FileManager.default.removeItem(at: testFolder)
        }
        fileIO = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// UTC-fixed calendar (matches FileIOServiceTests/DocumentStoreTests'
    /// own convention) so date math in the test is deterministic regardless
    /// of the machine running it, and is passed as the SAME calendar to both
    /// file-writing and generateWeeklySummary so filenames agree.
    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int) throws -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return try XCTUnwrap(utcCalendar().date(from: comps))
    }

    private func writeDailyFile(_ text: String, date: Date, calendar: Calendar) throws {
        let url = DailyFilename(date: date, calendar: calendar).url(in: testFolder)
        try fileIO.writeText(text, to: url)
    }

    // MARK: - Structure

    func testWeeklySummaryGeneratesCorrectStructure() throws {
        let calendar = utcCalendar()
        let dayA = try makeDate(year: 2026, month: 8, day: 24)
        let dayB = try makeDate(year: 2026, month: 8, day: 25)
        let dayC = try makeDate(year: 2026, month: 8, day: 26)

        try writeDailyFile(
            "- [x] Ship export feature\n[tag:idea] Landing page concept\n[expense: 15.50 lunch]\n",
            date: dayA,
            calendar: calendar
        )
        try writeDailyFile(
            "- [ ] Review PR\n- [x] Write tests\n[tag:work] Follow up with client\n[expense: 4.25 coffee]\n",
            date: dayB,
            calendar: calendar
        )
        try writeDailyFile(
            "- [ ] Plan sprint 6\n[tag:idea] Newsletter idea\n[expense: 99.00 gym]\n",
            date: dayC,
            calendar: calendar
        )

        let result = ExportKit.generateWeeklySummary(
            endDate: dayC,
            folderURL: testFolder,
            fileIO: fileIO,
            calendar: calendar
        )

        XCTAssertFalse(result.usedFutureDateFallback)
        XCTAssertTrue(result.skippedICloudDays.isEmpty)

        XCTAssertTrue(result.markdown.hasPrefix("# Weekly Summary: 2026-08-20 to 2026-08-26"))

        XCTAssertTrue(result.markdown.contains(
            "## Completed Tasks\n- Ship export feature\n- Write tests"
        ))
        XCTAssertTrue(result.markdown.contains(
            "## Open Tasks\n- Review PR\n- Plan sprint 6"
        ))
        XCTAssertTrue(result.markdown.contains(
            "## Tags\n### idea\n- 2026-08-24: Landing page concept\n- 2026-08-26: Newsletter idea"
        ))
        XCTAssertTrue(result.markdown.contains(
            "### work\n- 2026-08-25: Follow up with client"
        ))
        XCTAssertTrue(result.markdown.contains(
            "## Expenses\n- 2026-08-24: lunch \u{2014} 15.50\n- 2026-08-25: coffee \u{2014} 4.25\n- 2026-08-26: gym \u{2014} 99.00"
        ))
        XCTAssertTrue(result.markdown.contains("Total expenses: 118.75"))
    }

    // MARK: - Missing days

    func testWeeklySummaryHandlesMissingDays() throws {
        let calendar = utcCalendar()
        let dayA = try makeDate(year: 2026, month: 8, day: 24)
        let dayC = try makeDate(year: 2026, month: 8, day: 26)

        // dayB (2026-08-25) deliberately has no file.
        try writeDailyFile(
            "- [x] Task A\n[expense: 10.00 misc]\n",
            date: dayA,
            calendar: calendar
        )
        try writeDailyFile(
            "- [x] Task C\n[expense: 5.00 snack]\n",
            date: dayC,
            calendar: calendar
        )

        let result = ExportKit.generateWeeklySummary(
            endDate: dayC,
            folderURL: testFolder,
            fileIO: fileIO,
            calendar: calendar
        )

        XCTAssertFalse(result.usedFutureDateFallback)
        XCTAssertTrue(result.skippedICloudDays.isEmpty)
        XCTAssertTrue(result.markdown.hasPrefix("# Weekly Summary: 2026-08-20 to 2026-08-26"))
        XCTAssertTrue(result.markdown.contains("## Completed Tasks\n- Task A\n- Task C"))
        XCTAssertTrue(result.markdown.contains(
            "## Expenses\n- 2026-08-24: misc \u{2014} 10.00\n- 2026-08-26: snack \u{2014} 5.00"
        ))
        XCTAssertTrue(result.markdown.contains("Total expenses: 15.00"))

        // No open tasks or tags were ever written — those sections must be
        // omitted entirely, not emitted empty.
        XCTAssertFalse(result.markdown.contains("## Open Tasks"))
        XCTAssertFalse(result.markdown.contains("## Tags"))
    }

    // MARK: - Future date clamping

    func testWeeklySummaryClampsFutureDate() throws {
        let calendar = utcCalendar()
        let farFuture = try makeDate(year: 2099, month: 1, day: 1)

        let result = ExportKit.generateWeeklySummary(
            endDate: farFuture,
            folderURL: testFolder,
            fileIO: fileIO,
            calendar: calendar
        )

        XCTAssertTrue(result.usedFutureDateFallback)
        XCTAssertTrue(result.markdown.contains("> The selected date is in the future."))
        XCTAssertTrue(result.markdown.contains("> PlainLog will export the week ending today."))
    }

    // MARK: - Empty week

    func testWeeklySummaryEmptyWeek() throws {
        let calendar = utcCalendar()
        let dayC = try makeDate(year: 2026, month: 8, day: 26)

        let result = ExportKit.generateWeeklySummary(
            endDate: dayC,
            folderURL: testFolder,
            fileIO: fileIO,
            calendar: calendar
        )

        XCTAssertFalse(result.usedFutureDateFallback)
        XCTAssertTrue(result.skippedICloudDays.isEmpty)
        // No entries anywhere: every section is omitted, leaving only the title.
        XCTAssertEqual(result.markdown, "# Weekly Summary: 2026-08-20 to 2026-08-26")
    }

    // MARK: - Expense total precision

    func testWeeklySummaryExpenseTotal() throws {
        let calendar = utcCalendar()
        let dayA = try makeDate(year: 2026, month: 8, day: 24)
        let dayB = try makeDate(year: 2026, month: 8, day: 25)
        let dayC = try makeDate(year: 2026, month: 8, day: 26)

        try writeDailyFile("[expense: 10.10 a]\n", date: dayA, calendar: calendar)
        try writeDailyFile("[expense: 20.20 b]\n", date: dayB, calendar: calendar)
        try writeDailyFile("[expense: 5.05 c]\n", date: dayC, calendar: calendar)

        let result = ExportKit.generateWeeklySummary(
            endDate: dayC,
            folderURL: testFolder,
            fileIO: fileIO,
            calendar: calendar
        )

        // 10.10 + 20.20 + 5.05 = 35.35 exactly. ExpenseParser and ExportKit's
        // accumulator are both typed Decimal end-to-end (never bridged
        // through Double), so this must land on exactly "35.35", not a
        // near-miss that only happens to round correctly at 2dp.
        XCTAssertTrue(result.markdown.contains("Total expenses: 35.35"))
    }
}
