import SwiftUI

/// Privacy Policy screen — Sprint 5 · Piece 5.10 (PLAN.md Feature 11 About
/// section / §15). Read-only, scrollable. Presented as a sheet from
/// Settings > About > "Privacy policy".
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(PrivacyPolicyCopy.text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Privacy Policy")
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
}
