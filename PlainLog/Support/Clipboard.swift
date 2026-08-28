import UIKit

/// Copies text to the system pasteboard (Feature 02's "Copy current text" /
/// "Copy text" escape hatches). No analytics, no persistence — a thin,
/// stateless wrapper so call sites don't each import UIKit directly.
enum Clipboard {
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}
