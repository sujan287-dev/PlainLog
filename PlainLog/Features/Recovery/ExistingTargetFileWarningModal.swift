import SwiftUI

/// Existing Target File Warning Modal — Feature 02.
/// Shown when the user has unsaved edits and today's daily file already
/// exists in the picked folder — saving may overwrite it.
struct ExistingTargetFileWarningModal: View {
    @Binding var isPresented: Bool
    let saveAsCopy: () -> Void
    let replaceExisting: () -> Void
    let cancel: () -> Void

    var body: some View {
        Color.clear
            .alert(
                Feature02ModalCopy.existingTargetFileWarningTitle,
                isPresented: $isPresented
            ) {
                Button(Feature02ModalCopy.existingTargetFileSaveAsCopyButton, action: saveAsCopy)
                Button(Feature02ModalCopy.existingTargetFileReplaceButton, role: .destructive, action: replaceExisting)
                Button(Feature02ModalCopy.existingTargetFileCancelButton, role: .cancel, action: cancel)
            } message: {
                Text(Feature02ModalCopy.existingTargetFileWarningMessage)
            }
    }
}
