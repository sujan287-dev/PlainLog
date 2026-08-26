import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to PlainLog")
                .font(.largeTitle).bold()
            Text("Folder picker coming in Piece 4.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
