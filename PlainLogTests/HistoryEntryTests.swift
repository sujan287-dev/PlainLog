import XCTest
@testable import PlainLog

/// Sprint 4 · Piece 4.4 — HistoryEntry window construction tests (Feature 09).
final class HistoryEntryTests: XCTestCase {

    private var testFolder: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "PlainLogHistoryEntryTests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: testFolder,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let testFolder {
            try? FileManager.default.removeItem(at: testFolder)
        }
        testFolder = nil
        try super.tearDownWithError()
    }

    /// Matches DocumentStore's navigationCalendar / HistoryBrowserView's own
    /// calendar exactly (Gregorian + device local timezone).
    private func localCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    func testHistoryWindowHasExactlyThirtyEntries() {
        let entries = HistoryEntry.window(
            folderURL: testFolder,
            selectedDate: Date(),
            calendar: localCalendar()
        )

        XCTAssertEqual(entries.count, 30)
    }

    func testHistoryWindowIsDescendingWithTodayFirst() {
        let cal = localCalendar()
        let entries = HistoryEntry.window(
            folderURL: testFolder,
            selectedDate: Date(),
            calendar: cal
        )

        XCTAssertTrue(cal.isDate(entries[0].date, inSameDayAs: Date()))

        for i in 0..<(entries.count - 1) {
            XCTAssertGreaterThan(entries[i].date, entries[i + 1].date)
            let dayGap = cal.dateComponents(
                [.day],
                from: entries[i + 1].date,
                to: entries[i].date
            ).day
            XCTAssertEqual(dayGap, 1)
        }
    }

    func testHistoryWindowReflectsFileExistenceForExactlyOneDate() throws {
        let cal = localCalendar()
        let baseline = HistoryEntry.window(
            folderURL: testFolder,
            selectedDate: Date(),
            calendar: cal
        )

        // Pick a date in the middle of the window and write a file for it.
        let target = baseline[10]
        let url = DailyFilename(date: target.date, calendar: cal).url(in: testFolder)
        try "content".write(to: url, atomically: true, encoding: .utf8)

        let entries = HistoryEntry.window(
            folderURL: testFolder,
            selectedDate: Date(),
            calendar: cal
        )

        let existing = entries.filter { $0.fileExists }
        XCTAssertEqual(existing.count, 1)
        XCTAssertTrue(cal.isDate(existing[0].date, inSameDayAs: target.date))
    }

    func testHistoryWindowHasExactlyOneTodayEntryAndItIsFirst() {
        let cal = localCalendar()
        let entries = HistoryEntry.window(
            folderURL: testFolder,
            selectedDate: Date(),
            calendar: cal
        )

        let todayEntries = entries.filter { $0.isToday }
        XCTAssertEqual(todayEntries.count, 1)
        XCTAssertTrue(entries.first?.isToday ?? false)
    }
}
