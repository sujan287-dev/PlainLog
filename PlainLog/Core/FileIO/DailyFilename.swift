import Foundation

/// Represents a daily filename in the format YYYY-MM-DD.md.
/// Uses the device's local timezone per PLAN.md Feature 03.
struct DailyFilename {
    let date: Date
    let calendar: Calendar

    init(date: Date, calendar: Calendar = .current) {
        self.date = date
        self.calendar = calendar
    }

    /// The filename string: YYYY-MM-DD.md
    var filename: String {
        // The filename format is Gregorian/ISO-8601-style regardless of the
        // device's regional calendar setting (Buddhist, Japanese, Islamic,
        // Hebrew, etc. all produce different year/month/day numbers for the
        // same instant). Only the time zone is device-local, per PLAN.md
        // Feature 03 ("use device local time zone") — the calendar system
        // used to compute those numbers is always Gregorian.
        var gregorianCalendar = Calendar(identifier: .gregorian)
        gregorianCalendar.timeZone = calendar.timeZone

        let formatter = DateFormatter()
        formatter.calendar = gregorianCalendar
        formatter.timeZone = gregorianCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: date)).md"
    }

    /// The full file URL when appended to a folder.
    func url(in folder: URL) -> URL {
        folder.appendingPathComponent(filename)
    }

    /// The YYYY-MM-DD date stamp (the filename without its .md extension).
    var dateStamp: String {
        guard filename.hasSuffix(".md") else { return filename }
        return String(filename.dropLast(".md".count))
    }
}
