import Foundation

/// One row of the Feature 09 history browser: a single day, whether its
/// file exists on disk, and whether it's today or the currently selected
/// document. Pure data — no I/O beyond the synchronous existence check
/// performed while building the window below.
struct HistoryEntry: Equatable, Identifiable {
    let date: Date
    let filename: String
    let fileExists: Bool
    let isToday: Bool
    let isSelected: Bool

    var id: Date { date }
}

extension HistoryEntry {
    /// Builds the Feature 09 history window: today plus the previous 29
    /// days, 30 entries total, in descending chronological order (today
    /// first).
    ///
    /// File existence is a synchronous FileManager check per day (30 stat
    /// calls — negligible at this scale). For a file that doesn't exist yet,
    /// fileExists is false — that's the pending-file signal. For a cloud-only
    /// placeholder (`.md.icloud`), fileExists on the real `.md` path is also
    /// false, which is correct under these semantics: the file isn't local
    /// yet, and tapping it routes through the existing openDailyFile ->
    /// .downloading flow, not through this indicator.
    ///
    /// `calendar` must be the same Gregorian-local calendar DocumentStore's
    /// navigationCalendar uses, so "today" and day-arithmetic here agree
    /// with what navigation actually does.
    static func window(
        folderURL: URL?,
        selectedDate: Date,
        calendar: Calendar
    ) -> [HistoryEntry] {
        let today = calendar.startOfDay(for: Date())

        return (0..<30).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let dailyFilename = DailyFilename(date: date, calendar: calendar)

            let fileExists: Bool
            if let folderURL {
                let url = dailyFilename.url(in: folderURL)
                fileExists = FileManager.default.fileExists(atPath: url.path)
            } else {
                fileExists = false
            }

            return HistoryEntry(
                date: date,
                filename: dailyFilename.filename,
                fileExists: fileExists,
                isToday: calendar.isDate(date, inSameDayAs: today),
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
            )
        }
    }
}
