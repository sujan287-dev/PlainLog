import SwiftUI

struct RecoveryView: View {
    @Environment(FolderAccessService.self) private var folderAccessService

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text("Folder Access Lost")
                .font(.title).bold()
            Text("Recovery UI coming in Piece 5.")
                .foregroundStyle(.secondary)

            Button("Clear Access (Test)") {
                folderAccessService.clearAccess()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
