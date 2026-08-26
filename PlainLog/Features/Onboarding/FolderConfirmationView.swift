import SwiftUI

struct FolderConfirmationView: View {
    let folderURL: URL
    let isICloudFolder: Bool
    let hasExistingFiles: Bool
    let onConfirm: () -> Void
    let onChooseDifferent: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "folder")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("Use this folder?")
                .font(.title)
                .bold()

            // Folder details card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Selected folder:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(folderURL.lastPathComponent)
                        .bold()
                }

                Divider()

                Text("PlainLog will store daily Markdown files here.")
                    .font(.subheadline)

                Text("No hidden files will be added.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // iCloud warning (conditional)
            if isICloudFolder {
                iCloudWarningCard
            }

            // Existing files notice (conditional, non-blocking)
            if hasExistingFiles {
                existingFilesNoticeCard
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button(action: onConfirm) {
                    Text(isICloudFolder ? "Use iCloud folder" : "Use this folder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: onChooseDifferent) {
                    Text("Choose a different folder")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(24)
    }

    // MARK: - iCloud Warning

    private var iCloudWarningCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("iCloud Drive folder detected", systemImage: "icloud")
                .font(.subheadline)
                .bold()
                .foregroundStyle(.orange)

            // Exact copy from PLAN.md Feature 01 "iCloud warning copy".
            Text("You selected an iCloud Drive folder.\n\nPlainLog can use it, but iCloud may need to download files before opening them.\n\nFor the fastest offline experience, choose a folder in On My iPhone.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Existing Files Notice

    private var existingFilesNoticeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Existing Markdown files found", systemImage: "doc.text.magnifyingglass")
                .font(.subheadline)
                .bold()
                .foregroundStyle(.blue)

            Text("This folder already contains Markdown files. PlainLog will add daily files alongside them without modifying existing content.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
