import SwiftUI

/// Conflict Modal — Feature 08.
/// Shown when the active file changed outside PlainLog while there are
/// unsaved edits. No merge logic — the only actions are reload (discard
/// local edits) or save-as-copy (keep local edits under a new filename).
struct ConflictModal: View {
    @Binding var isPresented: Bool
    let reload: () -> Void
    let saveAsCopy: () -> Void

    var body: some View {
        Color.clear
            .alert(
                Feature08ModalCopy.conflictTitle,
                isPresented: $isPresented
            ) {
                Button("Reload", action: reload)
                Button("Save as copy", action: saveAsCopy)
            } message: {
                Text(Feature08ModalCopy.conflictMessage)
            }
    }
}
