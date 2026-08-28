import SwiftUI

/// iCloud Download Modal — Feature 07.
/// Shown when fileState is .downloading (opening or navigating to a
/// cloud-only file). Retry re-requests the download; Cancel dismisses,
/// leaving the file in its locked/downloading state.
struct ICloudDownloadModal: View {
    @Binding var isPresented: Bool
    let retry: () -> Void

    var body: some View {
        Color.clear
            .alert(
                Feature0607ModalCopy.iCloudDownloadTitle,
                isPresented: $isPresented
            ) {
                Button(Feature0607ModalCopy.iCloudDownloadRetryButton, action: retry)
                Button(Feature0607ModalCopy.iCloudDownloadCancelButton, role: .cancel) {}
            } message: {
                Text(Feature0607ModalCopy.iCloudDownloadBody)
            }
    }
}
