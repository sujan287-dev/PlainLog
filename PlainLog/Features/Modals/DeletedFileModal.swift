import SwiftUI

/// Deleted File Modal — Feature 08.
/// Shown when the active file was deleted outside PlainLog. Two variants
/// depending on whether there are unsaved edits — no merge logic in either.
struct DeletedFileModal: View {
    enum Variant {
        case withUnsavedEdits
        case withoutUnsavedEdits
    }

    @Binding var isPresented: Bool
    let variant: Variant
    let recreate: () -> Void
    let discard: () -> Void
    let ok: () -> Void

    var body: some View {
        Color.clear
            .alert(title, isPresented: $isPresented) {
                switch variant {
                case .withUnsavedEdits:
                    Button("Recreate file", action: recreate)
                    Button("Discard edits", action: discard)
                case .withoutUnsavedEdits:
                    Button("OK", action: ok)
                }
            } message: {
                if !message.isEmpty {
                    Text(message)
                }
            }
    }

    private var title: String {
        switch variant {
        case .withUnsavedEdits:
            return Feature08ModalCopy.deletedTitleWithEdits
        case .withoutUnsavedEdits:
            return Feature08ModalCopy.deletedTitleWithoutEdits
        }
    }

    private var message: String {
        switch variant {
        case .withUnsavedEdits:
            return Feature08ModalCopy.deletedMessageWithEdits
        case .withoutUnsavedEdits:
            return Feature08ModalCopy.deletedMessageWithoutEdits
        }
    }
}
