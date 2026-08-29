import Foundation

/// The five .alert-based modals EditorView can present.
enum EditorModal: Equatable {
    case conflict
    case deletedFile(DeletedFileModal.Variant)
    case saveError
    case iCloudDownload
    case offlineCopyWarning
}

/// EditorModalQueue — bugfix H3 (full-codebase audit).
/// Pure FIFO presentation queue: EditorView used to drive its five
/// .alert-based modals from five independent @State flags that could flip
/// true concurrently (e.g. a save-error queued while the app was
/// backgrounded, plus a foreground external-change check resolving to
/// .modified/.deleted in the same event). UIKit only presents one alert at
/// a time — the second .background's .alert call silently lost that race,
/// with no re-trigger, which could drop the safety-critical conflict or
/// deletion warning entirely.
///
/// This queue makes "at most one modal active, nothing lost" a property of
/// the data structure itself rather than of ad hoc coordination: `present`
/// enqueues (deduplicated — presenting an already-queued modal is a no-op),
/// `active` is always the front of the queue, and `dismissActive` advances
/// to the next one. No I/O, fully testable without a View.
struct EditorModalQueue: Equatable {
    private(set) var items: [EditorModal] = []

    var active: EditorModal? { items.first }

    mutating func present(_ modal: EditorModal) {
        guard !items.contains(modal) else { return }
        items.append(modal)
    }

    mutating func dismissActive() {
        guard !items.isEmpty else { return }
        items.removeFirst()
    }
}
