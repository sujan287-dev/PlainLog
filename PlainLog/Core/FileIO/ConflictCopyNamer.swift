import Foundation

/// Generates non-colliding "save as copy" filenames per PLAN.md Feature 08.
///
/// Primary format: YYYY-MM-DD-copy-HHMM.md (e.g. 2026-08-26-copy-1530.md).
/// On collision: appends -2, -3, ... (e.g. 2026-08-26-copy-1530-2.md).
///
/// Kept pure (no filesystem access) so the naming table is fully unit-testable.
enum ConflictCopyNamer {

    /// Returns a copy filename that does not collide with `existingNames`.
    /// - Parameters:
    ///   - saveMoment: drives both the day part and the HHMM part.
    ///   - existingNames: filenames already present in the target folder.
    ///   - calendar: Gregorian calendar with the desired timezone (device local).
    static func nextCopyName(
        forSaveAt saveMoment: Date,
        existingNames: Set<String>,
        calendar: Calendar
    ) -> String {
        let dayPart = dayFormatter(calendar: calendar).string(from: saveMoment)
        let timePart = timeFormatter(calendar: calendar).string(from: saveMoment)

        let primary = "\(dayPart)-copy-\(timePart).md"
        if !existingNames.contains(primary) {
            return primary
        }

        // Collision: append an incrementing counter until a free name is found.
        var counter = 2
        while true {
            let candidate = "\(dayPart)-copy-\(timePart)-\(counter).md"
            if !existingNames.contains(candidate) {
                return candidate
            }
            counter += 1
        }
    }

    private static func dayFormatter(calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private static func timeFormatter(calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "HHmm"
        return f
    }
}
