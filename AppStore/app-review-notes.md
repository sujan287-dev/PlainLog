# App Review Notes

Staged for App Store Connect's "App Review Information" notes field.
Expands PLAN.md §15's App Review notes draft into complete, factual notes.

---

## What the app is

PlainLog is a local-first Markdown daily log.

It does not require an account. It does not use a database for user notes.
User notes are stored as standard .md files inside a folder selected by the
user, on the user's own device (or the user's own iCloud Drive, if they
choose a folder there).

## Why folder access is requested

PlainLog's only requested permission is user-selected folder access
(`UIDocumentPickerViewController` via SwiftUI's file importer), granted once
on first launch and persisted as a security-scoped bookmark. This access is
required because PlainLog writes the user's daily notes directly into that
folder as plain .md files — there is no other storage location and no
server-side alternative. PlainLog does not request Camera, Photos, Contacts,
Location, Microphone, Health, Call Log, Accessibility, or Background Refresh
permissions, and does not need any of them.

## Data collection

PlainLog does not collect user data. There is no analytics SDK, no tracking
SDK, no telemetry, and no company server that user notes are ever sent to.
The only network activity in the app is (a) Apple's own iCloud sync, if the
user chooses an iCloud Drive folder, and (b) StoreKit 2 calls to Apple's App
Store for the optional Pro purchase — both are between the user and Apple,
not PlainLog. The in-app Privacy Policy (Settings > About > Privacy policy)
states this in full.

## How to test the core flow

1. Launch the app. The Welcome screen appears (no account/login screen —
   there is none).
2. Tap "Choose your PlainLog folder" and pick (or create) any folder via the
   system folder picker — an on-device folder ("On My iPhone") is simplest
   for testing and avoids any iCloud download wait.
3. Confirm the folder on the confirmation screen that follows.
4. The Today Screen opens with an empty editor. Type any text.
5. The text autosaves automatically after a brief pause (about half a
   second) — no explicit "Save" button exists. A file named
   `YYYY-MM-DD.md` (today's date) is created inside the chosen folder only
   once meaningful (non-blank) text has been typed — this is expected
   behavior, not a bug: PlainLog intentionally does not create a blank file
   until there is something to save.
6. The created file can be inspected directly in the Files app, confirming
   it is a plain, ordinary `.md` text file with no hidden metadata alongside
   it.
7. Tap the Preview/Edit toggle at the top of the editor to see the same text
   rendered as Markdown.

## How to test PlainLog Pro (StoreKit)

PlainLog Pro (`com.plainlog.ios.pro`) is a single non-consumable,
one-time-purchase product via StoreKit 2 — no subscription.

1. From the Today Screen's top bar, tap the star icon (or the "Weekly
   export" icon while not yet Pro) to open the paywall, or go to
   Settings (gearshape icon) > Pro.
2. Tap "Buy PlainLog Pro" and complete the purchase using a StoreKit
   sandbox tester account.
3. On success, the paywall dismisses automatically and Settings > Pro shows
   "PlainLog Pro — Active."
4. Pro-gated features become available: the weekly export icon in the top
   bar now generates and shares a report instead of opening the paywall, and
   Settings > Appearance > Theme allows selecting "Sepia" (the only
   Pro-gated theme).
5. "Restore purchase" (Settings > Pro, or the paywall) can be tested by
   reinstalling the app (or using a fresh sandbox session) and tapping
   Restore — no re-purchase is required, and no account or sign-in is
   involved beyond the sandbox Apple ID already used to purchase.

All free features (daily capture, Edit/Preview, autosave, date navigation,
task/tag/expense summary, basic appearance settings) remain fully usable
without purchasing Pro, and remain usable even if StoreKit fails to load
(e.g. no network) — StoreKit errors never block free features.

## Contact

No support contact is included in this submission draft; see
`launch-checklist.md` item 3.
