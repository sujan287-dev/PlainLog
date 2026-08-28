import Foundation
import SwiftUI
import UIKit

/// Weekly export orchestration (Feature 13) — bridges the headless ExportKit
/// service to a share-sheet-ready temp file. EditorView drives this from its
/// Pro-gated export button; this holds no view state of its own.
enum WeeklyExportOrchestrator {

    /// Generates the weekly report and writes it to a fresh file in
    /// FileManager.temporaryDirectory (never the user's PlainLog folder —
    /// PLAN.md §11 "Export behavior" / "Temporary files"). Returns the temp
    /// file's URL, or a user-facing error description on write failure.
    ///
    /// Synchronous and must run off the main actor: ExportKit calls into
    /// FileIOService's synchronous, background-thread-only read methods
    /// (same threading contract DocumentStore and EditorView's own foreground
    /// external-change check already honor).
    static func export(
        endDate: Date,
        folderURL: URL,
        fileIO: FileIOService,
        calendar: Calendar
    ) -> Result<URL, String> {
        let result = ExportKit.generateWeeklySummary(
            endDate: endDate,
            folderURL: folderURL,
            fileIO: fileIO,
            calendar: calendar
        )

        // WeeklySummaryResult doesn't carry the clamped end date (it's not
        // one of Feature 13's specified fields), so the filename date is
        // recomputed here with the same one-line clamp ExportKit itself
        // applies internally.
        let today = calendar.startOfDay(for: Date())
        let requestedEnd = calendar.startOfDay(for: endDate)
        let filenameDate = requestedEnd > today ? today : requestedEnd
        let stamp = DailyFilename(date: filenameDate, calendar: calendar).dateStamp
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlainLog-Weekly-\(stamp).md")

        do {
            try Data(result.markdown.utf8).write(to: tempURL, options: .atomic)
            return .success(tempURL)
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}

/// Identifiable wrapper so a generated export file can drive .sheet(item:).
struct ExportedWeeklyFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// Thin UIKit bridge presenting the system share sheet for the exported file
/// (Feature 13). SwiftUI's ShareLink triggers its own tap gesture, which
/// doesn't fit the "generate on tap, then present" flow the weekly export
/// needs — EditorView instead presents this representable via .sheet(item:)
/// once the temp file is ready, so the share sheet opens directly on the
/// export button's own tap.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
