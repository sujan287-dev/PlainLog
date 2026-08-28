import Foundation

/// Result of a weekly summary generation (Feature 13).
struct WeeklySummaryResult {
    /// The full report, Markdown-formatted.
    let markdown: String
    /// True if the requested end date was in the future and got clamped to today.
    let usedFutureDateFallback: Bool
    /// Days in the 7-day window whose daily file exists in iCloud but wasn't
    /// downloaded locally, and so was excluded from the report.
    let skippedICloudDays: [Date]
}

/// ExportKit — Sprint 5 (PLAN.md Feature 13).
/// Headless weekly summary generation: reads the last seven daily files and
/// aggregates their tasks, tags, and expenses into a single Markdown report.
///
/// Reuses TaskParser.parse and ExpenseParser.parse from ParserKit (unmodified
/// — see PlainLog/Core/Parser/ParserKit.swift). Tags are scanned separately,
/// line by line: TagParser.parse only returns tag names, but the weekly
/// report needs each tag's per-day line content too, so ExportKit does its
/// own [tag:name] scan (same prefix/validation rules as TagParser, via the
/// shared TagParser.isValidTagName) rather than modifying ParserKit's return
/// type for this one caller.
///
/// Pure/headless: no UI, no singletons, no stored state. Every input is a
/// parameter; the result is returned, never applied to shared state directly.
enum ExportKit {

    static func generateWeeklySummary(
        endDate: Date,
        folderURL: URL,
        fileIO: FileIOService,
        calendar: Calendar
    ) -> WeeklySummaryResult {
        let today = calendar.startOfDay(for: Date())
        let requestedEnd = calendar.startOfDay(for: endDate)
        let usedFutureDateFallback = requestedEnd > today
        let effectiveEndDate = usedFutureDateFallback ? today : requestedEnd

        var days: [Date] = []
        for offset in -6...0 {
            if let day = calendar.date(byAdding: .day, value: offset, to: effectiveEndDate) {
                days.append(day)
            }
        }

        var completedTasks: [String] = []
        var openTasks: [String] = []
        var tagOrder: [String] = []
        var tagEntries: [String: [(day: Date, line: String)]] = [:]
        var expenseEntries: [(day: Date, description: String, amount: Decimal)] = []
        var skippedICloudDays: [Date] = []

        for day in days {
            let fileURL = DailyFilename(date: day, calendar: calendar).url(in: folderURL)

            // iCloud gate FIRST, before any existence check: an evicted
            // (cloud-only) iCloud item reports fileExists == false at its
            // real path, so checking existence first would misreport it as
            // "no file this day" and silently drop it from the report
            // instead of recording it in skippedICloudDays — the same bug
            // class FileIOService.openDailyFile and readText(at:) both guard
            // against (see their doc comments). Same reasoning here.
            switch fileIO.iCloudState(at: fileURL) {
            case .cloudOnly, .downloading:
                skippedICloudDays.append(day)
                continue
            case .notICloud, .localReady, .downloadFailed:
                break
            }

            guard fileIO.fileExists(at: fileURL) else { continue }
            guard let content = try? fileIO.readText(at: fileURL) else { continue }

            for task in TaskParser.parse(content) {
                if task.isCompleted {
                    completedTasks.append(task.text)
                } else {
                    openTasks.append(task.text)
                }
            }

            for expense in ExpenseParser.parse(content) {
                expenseEntries.append((day: day, description: expense.description, amount: expense.amount))
            }

            for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
                let (names, strippedLine) = extractTagOccurrences(from: String(line))
                for name in names {
                    if tagEntries[name] == nil {
                        tagEntries[name] = []
                        tagOrder.append(name)
                    }
                    tagEntries[name]?.append((day: day, line: strippedLine))
                }
            }
        }

        // Same NaN-guard as ParserKit.parseSummary: Decimal arithmetic
        // doesn't trap on overflow, it produces a non-finite result — if the
        // running total ever goes non-finite, stop accumulating further
        // rather than let it propagate into the formatted total.
        let expenseTotal = expenseEntries.reduce(Decimal.zero) { partial, entry in
            let sum = partial + entry.amount
            return sum.isNaN ? partial : sum
        }

        let markdown = formatReport(
            startDate: days.first ?? effectiveEndDate,
            endDate: days.last ?? effectiveEndDate,
            completedTasks: completedTasks,
            openTasks: openTasks,
            tagOrder: tagOrder,
            tagEntries: tagEntries,
            expenseEntries: expenseEntries,
            expenseTotal: expenseTotal,
            usedFutureDateFallback: usedFutureDateFallback,
            skippedICloudDays: skippedICloudDays,
            calendar: calendar
        )

        return WeeklySummaryResult(
            markdown: markdown,
            usedFutureDateFallback: usedFutureDateFallback,
            skippedICloudDays: skippedICloudDays
        )
    }

    // MARK: - Tag line scan

    /// Scans a single line for [tag:name] occurrences. Mirrors TagParser's
    /// own prefix-matching and name-validation rules exactly (including its
    /// character-by-character fallthrough on an invalid/unterminated match),
    /// but additionally builds the line with every valid occurrence removed
    /// and trimmed — content TagParser.parse doesn't expose.
    /// Returns the valid tag names found, in order of appearance, and the
    /// stripped line (shared by every tag found on that line).
    private static func extractTagOccurrences(from line: String) -> (names: [String], strippedLine: String) {
        var names: [String] = []
        var result = ""
        var index = line.startIndex

        while index < line.endIndex {
            if line[index...].hasPrefix("[tag:") {
                let nameStart = line.index(index, offsetBy: 5) // "[tag:".count
                var nameEnd = nameStart
                while nameEnd < line.endIndex && line[nameEnd] != "]" {
                    nameEnd = line.index(after: nameEnd)
                }

                if nameEnd < line.endIndex && line[nameEnd] == "]" {
                    let name = String(line[nameStart..<nameEnd])
                    if TagParser.isValidTagName(name) {
                        names.append(name)
                        index = line.index(after: nameEnd)
                        continue
                    }
                }
            }
            result.append(line[index])
            index = line.index(after: index)
        }

        return (names, result.trimmingCharacters(in: .whitespaces))
    }

    // MARK: - Report formatting

    /// Formats the aggregated data into Markdown per Feature 13's exact
    /// structure. A section is omitted entirely when it has no entries.
    private static func formatReport(
        startDate: Date,
        endDate: Date,
        completedTasks: [String],
        openTasks: [String],
        tagOrder: [String],
        tagEntries: [String: [(day: Date, line: String)]],
        expenseEntries: [(day: Date, description: String, amount: Decimal)],
        expenseTotal: Decimal,
        usedFutureDateFallback: Bool,
        skippedICloudDays: [Date],
        calendar: Calendar
    ) -> String {
        var lines: [String] = []

        if usedFutureDateFallback {
            lines.append("> The selected date is in the future.")
            lines.append("> PlainLog will export the week ending today.")
            lines.append("")
        }

        let startStamp = DailyFilename(date: startDate, calendar: calendar).dateStamp
        let endStamp = DailyFilename(date: endDate, calendar: calendar).dateStamp
        lines.append("# Weekly Summary: \(startStamp) to \(endStamp)")

        if !completedTasks.isEmpty {
            lines.append("")
            lines.append("## Completed Tasks")
            for task in completedTasks {
                lines.append("- \(task)")
            }
        }

        if !openTasks.isEmpty {
            lines.append("")
            lines.append("## Open Tasks")
            for task in openTasks {
                lines.append("- \(task)")
            }
        }

        if !tagOrder.isEmpty {
            lines.append("")
            lines.append("## Tags")
            for (index, tagName) in tagOrder.enumerated() {
                if index > 0 {
                    lines.append("")
                }
                lines.append("### \(tagName)")
                for entry in tagEntries[tagName] ?? [] {
                    let dayStamp = DailyFilename(date: entry.day, calendar: calendar).dateStamp
                    lines.append("- \(dayStamp): \(entry.line)")
                }
            }
        }

        if !expenseEntries.isEmpty {
            lines.append("")
            lines.append("## Expenses")
            for entry in expenseEntries {
                let dayStamp = DailyFilename(date: entry.day, calendar: calendar).dateStamp
                let amountText = ExpenseTotalDisplay.text(for: entry.amount)
                lines.append("- \(dayStamp): \(entry.description) \u{2014} \(amountText)")
            }
            lines.append("")
            lines.append("Total expenses: \(ExpenseTotalDisplay.text(for: expenseTotal))")
        }

        if !skippedICloudDays.isEmpty {
            lines.append("")
            lines.append("> Some files are still in iCloud and were not included in this export.")
        }

        return lines.joined(separator: "\n")
    }
}
