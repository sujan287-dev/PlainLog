import SwiftUI

/// Reselection Warning Modal — Feature 02.
/// Shown when the user has unsaved edits and the picked folder's name
/// differs from the last known hint — PlainLog cannot verify it's the
/// original folder.
struct ReselectionWarningModal: View {
    @Binding var isPresented: Bool
    let saveToSelectedFolder: () -> Void
    let copyText: () -> Void
    let cancel: () -> Void

    var body: some View {
        Color.clear
            .alert(
                Feature02ModalCopy.reselectionWarningTitle,
                isPresented: $isPresented
            ) {
                Button(Feature02ModalCopy.reselectionWarningSaveButton, action: saveToSelectedFolder)
                Button(Feature02ModalCopy.reselectionWarningCopyButton, action: copyText)
                Button(Feature02ModalCopy.reselectionWarningCancelButton, role: .cancel, action: cancel)
            } message: {
                Text(Feature02ModalCopy.reselectionWarningMessage)
            }
    }
}
