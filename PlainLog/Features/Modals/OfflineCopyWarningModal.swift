import SwiftUI

/// Offline Copy Warning Modal — Feature 07 requirement 8 / Risk 2.
/// Shown when a brand-new daily file is about to be created in an iCloud
/// folder while the device is offline (OfflineCaptureGuard). "Create offline
/// file" proceeds with creation; "Cancel" aborts it — the text stays in
/// memory as a still-pending file, never written as a shadow draft.
struct OfflineCopyWarningModal: View {
    @Binding var isPresented: Bool
    let createOfflineFile: () -> Void
    let cancel: () -> Void

    var body: some View {
        Color.clear
            .alert(
                Feature0607ModalCopy.offlineCopyWarningTitle,
                isPresented: $isPresented
            ) {
                Button(Feature0607ModalCopy.offlineCopyWarningCreateButton, action: createOfflineFile)
                Button(Feature0607ModalCopy.offlineCopyWarningCancelButton, role: .cancel, action: cancel)
            } message: {
                Text(Feature0607ModalCopy.offlineCopyWarningMessage)
            }
    }
}
