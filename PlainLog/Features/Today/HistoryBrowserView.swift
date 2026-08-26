import SwiftUI

/// History Browser — Sprint 4 (PLAN.md Feature 09).
/// A sheet listing the last 30 daily files, with file-existence indicators
/// and tap-to-navigate. Grid calendar UI is deferred (Piece 4.4 scope).
struct HistoryBrowserView: View {
    let folderURL: URL?
    let selectedDate: Date
    let onSelect: (Date) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Mirrors DocumentStore's navigationCalendar convention (Gregorian +
    /// device local timezone) so the history window agrees with navigation
    /// on what "today" and "the same day" mean.
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private var entries: [HistoryEntry] {
        HistoryEntry.window(
            folderURL: folderURL,
            selectedDate: selectedDate,
            calendar: Self.calendar
        )
    }

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                Button {
                    onSelect(entry.date)
                } label: {
                    row(for: entry)
                }
                .buttonStyle(.plain)
                .listRowBackground(entry.isToday ? Color.accentColor.opacity(0.1) : nil)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for entry: HistoryEntry) -> some View {
        HStack {
            // Filled dot = file exists (local or cloud-only, both count).
            // Hollow outline = no file yet.
            Circle()
                .fill(entry.fileExists ? Color.accentColor : Color.clear)
                .overlay(
                    Circle().strokeBorder(Color.secondary, lineWidth: entry.fileExists ? 0 : 1)
                )
                .frame(width: 10, height: 10)

            Text(DailyFilename(date: entry.date).dateStamp)
                .font(.body)
                .fontWeight(entry.isToday ? .bold : .regular)
                .monospacedDigit()

            Spacer()

            if entry.isToday {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if entry.isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
    }
}
