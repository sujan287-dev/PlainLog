import SwiftUI

/// Save Error Modal — Feature 06.
/// Shown when a save transitions to a failure state (.saveFailed /
/// .accessLostDuringSave), once per failure episode (SaveErrorModalGuard).
///
/// Feature 06 specifies only two buttons (Retry, Copy current text) — no
/// extra dismiss/cancel button is added. Both existing buttons already
/// dismiss the alert on tap (standard SwiftUI .alert behavior for any
/// button, regardless of role), so the user is never trapped without an
/// exit; a third, unspecified button would violate "verbatim" for no real
/// UX gain.
struct SaveErrorModal: View {
    @Binding var isPresented: Bool
    let retry: () -> Void
    let copyText: () -> Void

    var body: some View {
        Color.clear
            .alert(
                Feature0607ModalCopy.saveErrorTitle,
                isPresented: $isPresented
            ) {
                Button(Feature0607ModalCopy.saveErrorRetryButton, action: retry)
                Button(Feature0607ModalCopy.saveErrorCopyTextButton, action: copyText)
            } message: {
                Text(Feature0607ModalCopy.saveErrorBody)
            }
    }
}
