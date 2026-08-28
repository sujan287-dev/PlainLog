import Foundation

/// Privacy Policy — Sprint 5 · Piece 5.10 (PLAN.md §15 "Privacy and App
/// Store Compliance"). Hardcoded, test-enforced — no bundled resource file,
/// no remote fetch. Do not edit without updating §15 and the tests together.
///
/// No support contact is included here by design: the founder will supply
/// one separately (out of scope for this piece).
enum PrivacyPolicyCopy {
    static let text = """
    PlainLog does not collect user data.

    PlainLog has no accounts, no analytics, no tracking, and no telemetry. \
    We do not collect your notes, your identity, or any usage data.

    Your notes are stored as plain .md text files, in a folder you choose \
    on your own device. PlainLog never uploads your notes to any server — \
    there is no PlainLog server for notes to go to.

    If you choose a folder inside iCloud Drive, your files sync through \
    your own iCloud account, provided by Apple. That syncing is between \
    you and Apple; PlainLog is not involved and does not see that data.

    If you purchase PlainLog Pro, that one-time purchase is processed \
    entirely by Apple through the App Store. PlainLog does not receive or \
    store your payment information.

    In short: no account, no cloud backend, no analytics, no tracking — \
    your notes stay on your device and in your own iCloud, under your \
    control.
    """
}
