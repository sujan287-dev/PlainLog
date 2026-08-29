# Launch Checklist — Work Requiring a Mac / Apple Developer Program

Everything in this file requires a Mac, an active Apple Developer Program
membership, App Store Connect (ASC), and/or a physical iOS device — none of
it can be done from this Windows machine or GitHub Actions CI. CI only
verifies that the app builds and its unit tests pass on `macos-latest`; it
cannot submit, configure StoreKit sandbox products, take screenshots, or run
on real hardware.

Each item below is explicitly marked with what it requires.

---

## 1. Apple Developer Program enrollment + App Store Connect app record

**Requires: Apple Developer Program membership + App Store Connect.**

- Enroll in the Apple Developer Program (if not already enrolled).
- Create the app record in App Store Connect for bundle ID
  `com.plainlog.ios` (must match `project.yml`'s
  `PRODUCT_BUNDLE_IDENTIFIER`).
- Set up code signing / provisioning (automatic signing is simplest for a
  solo developer).

## 2. StoreKit product setup

**Requires: App Store Connect + Mac (for local sandbox testing) + device.**

- Create the non-consumable in-app purchase product
  `com.plainlog.ios.pro` in App Store Connect, matching
  `BillingKit.productID`.
- Set pricing per PLAN.md Feature 12 ("Pricing"): recommended $9.99
  one-time, or the $6.99 one-time launch option — pick one, do not invent a
  different price.
- Create a Sandbox Apple ID tester (Users and Access > Sandbox testers).
- Verify purchase + restore end-to-end using the sandbox account, following
  `app-review-notes.md`'s "How to test PlainLog Pro" steps.

## 3. Hosted Privacy Policy URL, Support URL, and support email

**Requires: a hosting location (GitHub Pages suggested) + App Store Connect.**

App Store Connect requires a Privacy Policy URL, and generally expects a
Support URL and a support/contact email, before an app can be submitted.

- Suggested: enable GitHub Pages on this repository and publish the policy
  text from `PlainLog/Features/Settings/PrivacyPolicyCopy.swift` (the hosted
  page's content must match the in-app policy — copy it verbatim, don't
  paraphrase a second version).
- Support URL: could be as simple as a GitHub repository README/issues page,
  once one exists for this purpose.
- **FLAGGED: no support email or contact has been supplied yet.** Per
  Piece 5.10's scope, no support contact was invented anywhere in the app or
  in this AppStore/ folder. The founder needs to supply a real support email
  (and decide on a Support URL) before this item can be completed and before
  submission is possible — App Store Connect will not accept a placeholder.

## 4. App Store privacy label (App Privacy questionnaire)

**Requires: App Store Connect.**

- Target label per PLAN.md §15: **"Data Not Collected."**
- PlainLog itself does not collect user content, identifiers, analytics, or
  tracking data — answer the App Privacy questionnaire accordingly.
- Note per §15: payment processing is handled by Apple (StoreKit/App Store),
  which may itself collect data under Apple's own privacy practices,
  separate from PlainLog's — review Apple's current App Privacy guidance for
  how in-app purchase is expected to be declared at submission time, since
  Apple's own requirements here can change between App Store Connect
  releases.

## 5. Screenshots

**Requires: Mac + Xcode Simulator (or a device).**

- Capture screenshots for each required device size class using the six
  themes in `metadata.md` / PLAN.md §16:
  1. One file per day.
  2. Your notes are actual files.
  3. No account. No database.
  4. Tasks, tags, and expenses.
  5. Works offline. Bring your own sync.
  6. One-time Pro. No subscription.
- Overlay the corresponding headline/caption from `metadata.md`'s
  "Screenshot Captions" section on each image (design tooling of your
  choice — not part of this repo).

## 6. Device QA pass

**Requires: a real physical iOS device (not just the simulator).**

Reproduce PLAN.md §14's full QA Production Checklist on-device — this
session (Windows, CI-only) has never been able to run the app interactively,
so none of the following have been manually verified beyond what unit tests
cover:

- **Folder access**: folder picker, folder confirmation, bookmark
  persistence across relaunch, recovery from an invalid/stale bookmark, no
  crash when the folder is moved or renamed on-device, no hidden files
  created, reselection-with-unsaved-edits confirmation, existing-target-file
  warning.
- **File IO**: new-file-on-first-meaningful-save behavior, empty pending
  file discarded safely, autosave, atomic save, external change detection
  (both on save and on foreground return), conflict modal, save-as-copy,
  deleted-file handling.
- **iCloud**: iCloud warning on folder selection, cloud-only file triggering
  download, download-failure retry, offline state explained, offline
  capture requiring explicit confirmation, no duplicate blank file created.
- **Editor**: Edit/Preview modes, empty-file placeholder, text preserved
  across mode switches, large-file warning, editor lock on lost access,
  read-only state.
- **Parser**: task/tag/expense counts, invalid syntax ignored, tags with
  spaces ignored, thousands separators ignored, parser never modifies the
  file.
- **Billing**: purchase, restore, Pro features unlocking, free features
  remaining usable, StoreKit errors not blocking free features.
- **Weekly export**: correct report generated, share sheet opens, missing
  days handled, future end date handled, iCloud-missing-files handled, Pro
  gate enforced.

## 7. TestFlight → beta → App Store submission

**Requires: Mac + App Store Connect + at least one device for final
verification.**

- Archive and upload a build to App Store Connect (via Xcode or
  `xcodebuild` archive/export, run on a Mac).
- Distribute via TestFlight to at least one internal/external tester; use
  this to re-run the Device QA pass (item 6) on a device other than the
  founder's own, if possible.
- Fill in the remaining App Store Connect submission fields using
  `metadata.md` and `app-review-notes.md`.
- Submit for App Review once items 1–6 above are complete and item 3's
  flagged support-contact gap is resolved.
