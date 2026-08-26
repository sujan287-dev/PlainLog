# PlainLog Production Plan

Product: PlainLog
Version: 1.0-production
Status: Approved for production build
Platform: iOS first
Last Updated: 2026-08-26
Owner: Founder / Product / Engineering
Document Type: Final Production Specification

---

# 1. Executive Summary

PlainLog is a local-first, plain-text Markdown daily capture app.

Every day becomes one normal Markdown file:

    2026-08-26.md

The user chooses a folder on their device. PlainLog writes plain .md files into that folder.

PlainLog is intentionally not a bloated notes app.

It is built for:

- daily capture
- journaling
- task logging
- expense logging
- lightweight tagging
- plain-text ownership

Core promise:

    Your life as plain files.
    One Markdown file per day.
    No account.
    No database.
    No lock-in.

---

# 2. Production Verdict

This plan is approved for production development.

Only the features listed in this document are approved for v1.

Anything not listed here is deferred.

---

# 3. Final Product Positioning

## App Store positioning

PlainLog is not marketed as a generic notes app.

It is positioned as:

    Local-first daily Markdown log

Alternate positioning:

    Plain-text daily journal
    Anti-bloat Markdown journal
    No-subscription daily log

## Primary marketing message

    Your notes are files.
    Your files are yours.

## Secondary marketing message

    One file per day.
    No account.
    No database.
    No lock-in.

---

# 4. Locked Production Constraints

These constraints are final and must not be violated during production development.

| Constraint | Rule |
|---|---|
| No account | No login, email, or profile creation. |
| No database for user content | Notes must remain standard .md files. |
| No analytics | No usage analytics or event tracking. |
| No tracking SDKs | No third-party trackers. |
| No cloud backend | No company server storing user notes. |
| No subscription for core features | Core daily capture is available without subscription. |
| No hidden marker files | Do not create .plainlog, folder.json, or similar inside user folder. |
| No shadow draft cache | Do not create hidden draft copies when folder access is lost. |
| No merge engine | No CRDT or automatic merging. |
| No custom UITextView in v1 | Use SwiftUI TextEditor only. |
| No live syntax highlighting in v1 | Edit Mode is raw Markdown. Preview Mode renders Markdown. |
| No blind iCloud file creation | Never overwrite or duplicate cloud-only files. |
| No folder pollution | PlainLog must keep the user folder clean. |

---

# 5. Approved Production Scope

## 5.1 In scope for production v1

The following features are approved for production.

### Core product

- Folder selection on first launch
- Folder confirmation screen
- Security-scoped bookmark persistence
- Folder access recovery
- Daily Markdown file capture
- Pending new file behavior
- SwiftUI TextEditor
- Edit Mode
- Preview Mode
- Autosave
- Safe coordinated file writes
- iCloud download awareness
- Offline iCloud warning
- Explicit offline capture confirmation
- External change detection
- Deleted file detection
- Conflict handling via reload or save-as-copy
- Date navigation
- Basic calendar/history browser
- Task parsing
- Tag parsing
- Expense parsing
- Summary bar
- Settings
- Folder Health screen
- PlainLog Pro one-time purchase
- Restore purchase
- Weekly summary export

---

## 5.2 Deferred from production v1

The following are not approved for v1.

- Custom UITextView editor
- Live Markdown highlighting
- Interactive checkbox tapping
- Tap-to-filter tags
- Encrypted files
- Automatic folder routing
- Template folder creation
- Full-text search across all files
- Built-in sync engine
- Collaboration
- AI features
- Plugin system
- Android version
- Cloud account sync
- Database-backed indexing
- Automatic report folders

---

# 6. Target Users

## Primary user

Plain-text minimalist.

Wants:

- speed
- simplicity
- offline access
- no account
- no subscription
- no bloated features

## Secondary user

Markdown power user.

May point PlainLog at an existing Markdown folder or Obsidian-style vault.

Expects:

- no folder pollution
- standard .md files
- no hidden metadata
- no broken file structure

## Tertiary user

Anti-subscription journaler.

Wants a simple daily journal without cloud lock-in.

---

# 7. Core Product Principles

## 7.1 Files over databases

User content must live in plain .md files.

PlainLog may store app settings privately, but not user note content.

## 7.2 Speed over features

The app must open quickly and let the user type immediately.

## 7.3 Ownership over convenience

Users must be able to leave PlainLog and keep their files.

## 7.4 Honesty over magic

PlainLog must not silently sync, merge, transform, or hide data.

If something is risky, PlainLog must ask.

## 7.5 Minimal footprint

PlainLog must not create unnecessary files inside the user folder.

---

# 8. Information Architecture

## Main screens

| Screen | Purpose |
|---|---|
| Welcome / Onboarding | First-launch folder selection. |
| Folder Confirmation | Confirm selected folder before use. |
| Today Screen | Main daily capture screen. |
| Editor Pane | Raw Markdown editing. |
| Preview Pane | Rendered Markdown preview. |
| Summary Bar | Tasks, tags, expenses overview. |
| Calendar / History | Browse daily files. |
| Settings | Folder, appearance, billing, privacy. |
| Folder Health | Folder access status and recovery. |
| Pro Paywall | One-time upgrade screen. |
| Recovery Modal | Folder access lost flow. |
| iCloud Download Modal | Waiting for iCloud file download. |
| Conflict Modal | External change/conflict resolution. |
| Deleted File Modal | Active file was deleted externally. |

---

# 9. Global App States

## Folder access states

    NoFolderSelected
    ResolvingBookmark
    FolderReady
    BookmarkStale
    AccessLost
    FolderUnwritable

## File states

    Idle
    CheckingFile
    DownloadingFromCloud
    FileReady
    NewPendingFile
    DownloadFailed
    LoadFailed
    ConflictDetected
    FileDeletedExternally
    OfflineCaptureRequested

## Save states

    Idle
    WaitingToSave
    Saving
    Saved
    SaveFailed
    AccessLostDuringSave
    ConflictDetectedDuringSave
    TargetFileAlreadyExists

## Editor states

    Editing
    Previewing
    Locked
    ReadOnly

---

# 10. Production Feature Specifications

---

## Feature 01: Onboarding and Folder Selection

### Purpose

Allow the user to choose where PlainLog stores Markdown files.

This is the only required setup step.

### Requirements

1. First launch shows a welcome screen.
2. No account creation is required.
3. Primary action is: Choose your PlainLog folder.
4. iOS folder picker opens.
5. No hidden metadata files are created.
6. Security-scoped bookmark is stored privately.
7. A private folder display-name hint may be stored.
8. If the folder appears to be in iCloud Drive, show iCloud warning.
9. Show helper text for creating a new folder in Files if needed.
10. Show folder confirmation before proceeding.
11. If selected folder already contains Markdown files, show non-blocking notice.

### Onboarding flow

    App opens
    ↓
    Welcome screen appears
    ↓
    User taps Choose your PlainLog folder
    ↓
    System folder picker opens
    ↓
    User selects folder
    ↓
    Folder confirmation screen appears
    ↓
    PlainLog stores bookmark privately
    ↓
    Today Screen opens

### Folder confirmation copy

    Use this folder?

    Selected folder:
    PlainLog

    PlainLog will store daily Markdown files here.
    No hidden files will be added.

Buttons:

    Use this folder
    Choose a different folder

### iCloud warning copy

    You selected an iCloud Drive folder.

    PlainLog can use it, but iCloud may need to download files before opening them.

    For the fastest offline experience, choose a folder in On My iPhone.

Buttons:

    Use iCloud folder
    Choose a different folder

### Acceptance criteria

- Folder picker works.
- Bookmark stored privately.
- No hidden files created.
- iCloud warning appears when appropriate.
- Folder confirmation appears.
- App proceeds to Today Screen after success.

---

## Feature 02: Folder Access Persistence and Recovery

### Purpose

Restore folder access on future launches and recover gracefully if iOS invalidates access.

### Requirements

1. Resolve stored bookmark on launch.
2. Do not crash if bookmark is stale, invalid, or unresolved.
3. Show recovery screen if access cannot be restored.
4. Do not use hidden marker files.
5. Allow user to reselect folder.
6. If unsaved edits exist, lock editing and warn before switching folders.
7. Offer Copy current text escape hatch.
8. If bookmark is stale but resolvable, refresh bookmark.
9. Manage security-scoped access responsibly.
10. If selected folder name differs from last known hint and unsaved edits exist, show stronger warning.
11. If unsaved edits exist, require explicit confirmation before saving into selected folder.
12. If today file already exists in selected folder, warn before replacing it.

### Normal launch flow

    App launches
    ↓
    Load private bookmark
    ↓
    Resolve bookmark
    ↓
    If stale but resolvable:
        Refresh bookmark
    ↓
    Start security-scoped access
    ↓
    Verify folder is reachable
    ↓
    Enter FolderReady

### Failure flow

    App launches
    ↓
    Bookmark resolution fails
    ↓
    Enter AccessLost
    ↓
    Show recovery screen
    ↓
    User selects folder again
    ↓
    Save new bookmark
    ↓
    Enter FolderReady

### Recovery screen copy without unsaved edits

    We lost access to your PlainLog folder

    Please reconnect your folder to open your notes.

Button:

    Choose folder

### Recovery screen copy with unsaved edits

    Folder access lost

    PlainLog cannot save to your folder right now.
    Please reconnect to save your changes safely.

    Your current edits are only in memory.
    Do not force-close the app if you want to keep them.

Buttons:

    Choose folder
    Copy current text

### Reselection warning with unsaved edits

    You have unsaved edits.

    PlainLog cannot verify that this is the original folder.
    Saving will write your current text to the selected folder.

    If you are unsure, copy your text instead.

Buttons:

    Save to selected folder
    Copy text
    Cancel

### Existing target file warning

    A file for today already exists in this folder.

    Saving may overwrite it.
    If you are unsure, save as a copy instead.

Buttons:

    Save as copy
    Replace existing file
    Cancel

### Acceptance criteria

- Bookmark resolves on launch.
- Stale bookmark refresh is attempted.
- Invalid bookmark does not crash app.
- Recovery screen appears when access is lost.
- Editor locks when access is lost.
- User can copy current text.
- Explicit confirmation appears when unsaved edits exist.
- Existing target file warning appears when needed.
- No hidden marker files are used.

---

## Feature 03: Daily File Opening and Creation

### Purpose

Open the correct daily Markdown file for the selected date.

### Requirements

1. Daily filename format is YYYY-MM-DD.md.
2. Use device local time zone.
3. Do not create blank file until meaningful content exists.
4. If file exists, load it.
5. If file is cloud-only, request download before opening.
6. Do not blindly create new file if iCloud version may exist.
7. If pending new file is about to save but target file now exists, trigger conflict flow.
8. If user leaves empty pending file, do not create file.

### File opening flow

    Determine selected date
    ↓
    Build filename: YYYY-MM-DD.md
    ↓
    Check if file exists
    ↓
    If file exists:
        Check iCloud download state
        If downloaded:
            Load file
        If cloud-only:
            Request download
    ↓
    If file does not exist:
        Show empty editor as pending new file
        Create file only after first meaningful save

### Empty file policy

| Situation | Behavior |
|---|---|
| File exists and is empty | Open it. |
| File does not exist | Show empty editor but do not create file yet. |
| User types meaningful content | Create file on first successful save. |
| User leaves without typing | Do not create file. |
| User types only spaces or newlines | Do not create file. |

### Acceptance criteria

- Correct date file opens.
- Existing file loads.
- Cloud-only file triggers download.
- Blank file is not created unnecessarily.
- Empty pending files are discarded safely.
- iCloud duplicate creation is avoided.
- Conflict prompt appears if target file appears unexpectedly.

---

## Feature 04: Editor — Edit Mode

### Purpose

Provide a fast, plain-text Markdown editing experience.

### Requirements

1. Use SwiftUI TextEditor.
2. Do not use custom UITextView in v1.
3. Do not apply live syntax highlighting in v1.
4. Edit Mode displays raw Markdown.
5. Support standard text input.
6. Show subtle save state.
7. Lock editor if folder access is lost.
8. Warn for very large files.
9. Show placeholder when file is empty.
10. Show read-only state when file cannot be edited safely.

### Editor layout

    Top Bar:
    ← Previous Day | Date | Next Day
    Today Button
    Edit / Preview Toggle

    Main Area:
    TextEditor

    Bottom Bar:
    Expenses | Tasks | Tags
    Save status

### Placeholder

    Write today’s log…

### Save status indicators

    Saved
    Saving…
    Waiting to save
    Save failed
    Folder access lost
    Waiting for iCloud

### Large file warning

    This file is large.
    Editing may be slower than usual.

Threshold:

    250 KB

Do not block editing by default.

### Acceptance criteria

- TextEditor displays raw Markdown.
- No live syntax highlighting.
- Editor is fast for typical daily files.
- Placeholder appears for empty files.
- Save status is visible.
- Editor locks when folder access is lost.
- Large files show warning.

---

## Feature 05: Markdown Preview Mode

### Purpose

Allow the user to see rendered Markdown without changing the file.

### Requirements

1. Provide Edit/Preview toggle.
2. Render Markdown locally.
3. Do not modify file.
4. Support headings, bullets, numbered lists, checkboxes, bold, italic, inline code, code blocks, tags, expenses.
5. Preview is read-only in v1.
6. Preview does not require internet.
7. If rendering fails, fall back to raw text.

### Preview limitations in v1

- No interactive checkboxes.
- No tap-to-toggle tasks.
- No live sync with typing.
- No rich editing.

### Acceptance criteria

- Edit/Preview toggle works.
- Preview renders locally.
- Preview does not modify file.
- Markdown basics render correctly.
- Rendering failure falls back to raw text.
- Returning to Edit preserves text.

---

## Feature 06: Autosave and Safe Writing

### Purpose

Save user content safely without corruption or hidden drafts.

### Requirements

1. Autosave after user stops typing.
2. Debounce autosave by 500ms.
3. Save when app moves to background.
4. Save when user switches days.
5. Use coordinated writes.
6. Avoid leaving temporary files in user folder.
7. Do not write shadow drafts.
8. Check external changes before saving.
9. Show save errors clearly.
10. Do not save empty pending file.
11. If pending new file target appears unexpectedly, trigger conflict flow.

### Autosave flow

    User types
    ↓
    Text model updates
    ↓
    Autosave debounce restarts
    ↓
    500ms idle
    ↓
    Check folder access
    ↓
    Check file state
    ↓
    Check external modification
    ↓
    Coordinate write
    ↓
    Save file
    ↓
    Update save status

### Save error copy

    PlainLog could not save this file

    Your current edits are still in memory.
    Try saving again or copy your text.

Buttons:

    Retry
    Copy current text

### Acceptance criteria

- Autosave works after typing pause.
- Save occurs on background.
- Save occurs on date switch.
- Empty pending files are not saved.
- No hidden draft files are created.
- Save failures are visible.
- Folder loss locks editor.
- Conflict flow triggers when target file appears unexpectedly.

---

## Feature 07: iCloud Drive Handling

### Purpose

Prevent sync-related data loss when user chooses iCloud Drive.

### Requirements

1. Detect iCloud-based folder where technically feasible.
2. Check download state before opening file.
3. Do not open or overwrite cloud-only file without download or explicit user action.
4. Show download progress or status.
5. Allow retry if download fails.
6. Do not create duplicate files blindly.
7. If iCloud state cannot be determined, require explicit user action before creating file.
8. If user creates offline file in iCloud folder, warn about possible future conflict.

### iCloud states

    NotiCloud
    LocalReady
    CloudDownloaded
    CloudDownloading
    CloudNotDownloaded
    DownloadFailed
    Offline
    OfflineCaptureRequested

### iCloud download UI

    Fetching today’s file from iCloud

    PlainLog is waiting for iCloud Drive to download today’s file.

Buttons:

    Retry
    Cancel

### Offline copy warning

    You are offline.

    Creating a new file now may cause a conflict later if iCloud already contains today’s file.

Buttons:

    Create offline file
    Cancel

### Acceptance criteria

- iCloud download state is checked.
- Cloud-only file is not overwritten.
- Download UI appears.
- Retry works.
- Offline state is explained.
- Duplicate creation is avoided.
- Offline capture requires explicit confirmation.

---

## Feature 08: External Change Detection and Conflict Resolution

### Purpose

Handle cases where the file changes outside PlainLog.

### Requirements

1. Store last known modification state after loading.
2. Check external changes before saving.
3. Check external changes when app returns to foreground.
4. If no unsaved edits, reload silently or show subtle notice.
5. If unsaved edits exist, show conflict prompt.
6. Do not merge changes.
7. Handle deleted active file.

### Conflict modal copy

    This file changed outside PlainLog

    You have unsaved edits.

    Reload the file, or save your edits as a copy.

Buttons:

    Reload
    Save as copy

### Deleted file modal copy with unsaved edits

    This file was deleted outside PlainLog

    You have unsaved edits.
    You can recreate the file with your current text, or discard your edits.

Buttons:

    Recreate file
    Discard edits

### Deleted file modal copy without unsaved edits

    This file was deleted outside PlainLog

Button:

    OK

### Conflict copy naming

Example:

    2026-08-26-copy-1530.md

or:

    2026-08-26-copy-1.md

PlainLog must avoid overwriting existing copy files.

### Acceptance criteria

- External modification is detected.
- External changes are checked on foreground return.
- Conflict prompt appears when needed.
- Reload works.
- Save-as-copy works.
- Deleted file handling works.
- No merge logic is attempted.

---

## Feature 09: Date Navigation and Calendar Browser

### Purpose

Let users move between daily files.

### Requirements

1. Show current selected date.
2. Allow previous day and next day navigation.
3. Provide Today action.
4. Provide calendar or list browser.
5. Calendar indicators are based on file existence where available.
6. If navigating to cloud-only file, use iCloud download flow.
7. If navigating away from empty pending file, discard silently.

### Navigation layout

    ←   2026-08-26   →
            Today

### Date switch behavior

    User taps previous/next day
    ↓
    If current file has unsaved meaningful changes:
        Attempt save
    ↓
    If save succeeds:
        Switch date
    If save fails:
        Show error/conflict flow
    If current file is empty pending:
        Discard silently and switch

### Acceptance criteria

- Previous/next day works.
- Today button works.
- Calendar shows file existence.
- Date switching saves current file first.
- Empty pending files do not block navigation.
- iCloud download flow triggers when needed.
- Errors block unsafe switching.

---

## Feature 10: Structured Syntax Parsing and Summary Bar

### Purpose

Give PlainLog lightweight structure without using a database.

### Requirements

1. Parse tasks from raw text.
2. Parse tags from raw text.
3. Parse expenses from raw text.
4. Parsing happens in memory.
5. Parsing does not modify file.
6. Parsing is debounced by 300ms.
7. Summary bar shows tasks, expenses, and tags.
8. Expense parsing supports simple decimals only.
9. Tags with spaces are invalid.
10. Expense totals display using chosen currency symbol, but parsing does not require currency symbol.

### Supported task syntax

    - [ ] Task
    - [x] Task
    * [ ] Task
    * [x] Task

Rules:

- Case-insensitive for x.
- Leading whitespace allowed.
- Hyphen or asterisk allowed.

### Supported tag syntax

    [tag:name]

Allowed characters:

    a-z
    A-Z
    0-9
    -
    _

Valid examples:

    [tag:idea]
    [tag:work]
    [tag:follow-up]
    [tag:home_1]

Invalid examples:

    [tag:]
    [tag:idea extra]
    [tag:work meeting]

### Supported expense syntax

    [expense: AMOUNT DESCRIPTION]

Valid examples:

    [expense: 15.50 lunch]
    [expense: 4 coffee]
    [expense: 12,50 snack]
    [expense: $99 gym]

Rules:

- Amount required.
- Description optional.
- Decimal point or comma allowed.
- Currency symbol ignored.
- Thousands separators not supported in v1.

### Summary bar example

    Expenses: 118.75
    Tasks: 2/6
    Tags: idea, health

### Acceptance criteria

- Task count correct.
- Tag list correct.
- Expense total correct.
- Invalid syntax ignored.
- Tags with spaces ignored.
- Thousands separators ignored.
- Parser does not modify file.
- Parser is debounced.

---

## Feature 11: Settings and Folder Health

### Purpose

Provide minimal configuration and transparency.

### Settings sections

    Folder
    Appearance
    Summary
    Pro
    About

### Folder section

    Current folder: PlainLog
    Status: Connected
    Last successful save: 09:41
    Reconnect folder

### Appearance section

    Theme: System / Light / Dark / Sepia
    Font: System / Monospaced
    Font size

### Summary section

    Default currency symbol
    Show expense total
    Show task count
    Show tags

### Pro section

    PlainLog Pro
    Restore purchase

### About section

    Version
    Privacy policy
    Support

### Acceptance criteria

- Folder status visible.
- Reconnect folder works.
- Appearance settings persist.
- Restore purchase exists.
- Privacy policy accessible.
- Last successful save time shown where available.

---

## Feature 12: PlainLog Pro Monetization

### Purpose

Support development without harming the free core experience.

### Requirements

1. PlainLog Pro is a one-time purchase.
2. Use StoreKit 2.
3. No server-side purchase profile.
4. No third-party billing SDKs.
5. Support restore purchases.
6. Store entitlement locally.
7. StoreKit loading errors must not block free features.

### Free features

- Daily Markdown capture
- Folder selection
- Edit/Preview
- Autosave
- Date navigation
- Task/tag/expense summary
- Basic appearance settings

### Pro features

- Weekly summary export
- Custom themes
- Advanced font options
- Supporter badge

### Pricing

Recommended:

    $9.99 one-time

Launch option:

    $6.99 one-time

### Paywall copy

    PlainLog Pro

    Unlock power features and support development.

    One-time purchase.
    No subscription.
    No account.
    No data collection.

    Includes:
    - Weekly summary exports
    - Custom themes
    - Font options
    - Future Pro updates

Buttons:

    Buy PlainLog Pro
    Restore purchase

### Acceptance criteria

- Purchase unlocks Pro.
- Restore works.
- No server required.
- No third-party billing SDK used.
- Free features remain usable.
- StoreKit errors do not block free features.

---

## Feature 13: Weekly Summary Export

### Purpose

Generate a Pro report from the last seven daily files.

### Requirements

1. Generate Markdown file.
2. Use last seven days ending on selected date.
3. Do not create folders automatically.
4. Use iOS share sheet.
5. Weekly export is a Pro feature.
6. If selected end date is future, use today and show notice.
7. If some daily files are unavailable due to iCloud, skip with notice or require download.

### Weekly report structure

    # Weekly Summary: 2026-08-20 to 2026-08-26

    ## Completed Tasks
    - Task A
    - Task B

    ## Open Tasks
    - Task C
    - Task D

    ## Tags
    ### idea
    - 2026-08-21: Landing page concept
    - 2026-08-24: Newsletter idea

    ### work
    - 2026-08-22: Follow up with client

    ## Expenses
    - 2026-08-20: lunch — 15.50
    - 2026-08-21: coffee — 4.25
    - 2026-08-23: gym — 99.00

    Total expenses: 118.75

### Future date notice

    The selected date is in the future.
    PlainLog will export the week ending today.

### iCloud missing files notice

    Some files are still in iCloud and were not included in this export.

### Acceptance criteria

- Report generates correctly.
- Missing days are handled.
- Export uses share sheet.
- No folder is created automatically.
- Pro gate works.
- Future end date is handled.
- iCloud unavailable files are handled.

---

# 11. File System Specification

## User folder example

    PlainLog/
      2026-08-24.md
      2026-08-25.md
      2026-08-26.md

## Forbidden inside user folder

    .plainlog/
    folder.json
    access-test.tmp
    cache files
    hidden metadata
    automatic Reports folder
    automatic Exports folder
    automatic Templates folder

## File encoding

    UTF-8

## Filename pattern

    YYYY-MM-DD.md

## Temporary files

Temporary files must be transient and cleaned immediately.

Where possible, use system-managed temporary storage outside the user folder.

## Export behavior

Weekly exports use share sheet.

If user saves export, user chooses destination.

---

# 12. Technical Architecture

## Recommended production stack

- Swift
- SwiftUI
- Foundation
- StoreKit 2
- NSFileCoordinator
- Local Markdown parser
- No analytics SDK
- No tracking SDK
- No third-party billing SDK

## Core services

### FolderAccessService

Responsible for:

- folder selection
- bookmark persistence
- bookmark resolution
- stale bookmark refresh
- access state
- recovery flow

### FileIOService

Responsible for:

- reading files
- writing files
- iCloud download checks
- NSFileCoordinator coordination
- external change detection
- deleted file detection
- conflict detection
- safe replacement

### DocumentStore

Responsible for:

- current selected date
- current file URL
- current text
- dirty state
- save state
- load state
- pending new file state

### ParserKit

Responsible for:

- task parsing
- tag parsing
- expense parsing
- summary model creation

### BillingKit

Responsible for:

- product loading
- purchase
- restore
- entitlement state

### ExportKit

Responsible for:

- weekly summary generation
- share sheet preparation

---

# 13. Production Implementation Plan

---

## Sprint 1: Folder Foundation

Goal:

    PlainLog can safely select, remember, and recover a folder.

Tasks:

1. Build welcome/onboarding screen.
2. Build folder picker flow.
3. Build folder confirmation screen.
4. Implement security-scoped bookmark creation.
5. Implement private bookmark storage.
6. Implement bookmark resolution on launch.
7. Implement stale bookmark refresh.
8. Build AccessLost recovery screen.
9. Build folder health status.
10. Add iCloud folder warning.

Definition of done:

- Folder picker works.
- Bookmark persists.
- App relaunch restores folder.
- Invalid bookmark shows recovery.
- No hidden files are created.
- No crashes on folder rename/move.

---

## Sprint 2: Safe File IO

Goal:

    PlainLog can safely read and write daily Markdown files.

Tasks:

1. Build FileIOService.
2. Implement coordinated reads.
3. Implement coordinated writes.
4. Implement atomic replacement where possible.
5. Implement external modification detection.
6. Implement deleted file detection.
7. Implement conflict modal.
8. Implement save-as-copy behavior.
9. Implement iCloud download state checks.
10. Implement iCloud download UI.

Definition of done:

- Daily file opens safely.
- iCloud cloud-only file is not overwritten.
- External changes are detected.
- Save failures are handled.
- No merge logic exists.
- Deleted file flow works.

---

## Sprint 3: Editor Core

Goal:

    PlainLog feels like a simple daily editor.

Tasks:

1. Build Today Screen.
2. Integrate SwiftUI TextEditor.
3. Add Edit/Preview toggle.
4. Add raw Markdown editing.
5. Add local Markdown preview renderer.
6. Add autosave debounce.
7. Add save status indicator.
8. Add placeholder for empty files.
9. Add large file warning.
10. Add pending new file behavior.

Definition of done:

- User can open today.
- User can type.
- App autosaves.
- Preview renders.
- Empty file is not created unnecessarily.
- No custom UITextView is used.

---

## Sprint 4: Structured Syntax and Navigation

Goal:

    PlainLog becomes more than a blank text box.

Tasks:

1. Build ParserKit.
2. Implement task parsing.
3. Implement tag parsing.
4. Implement expense parsing.
5. Build summary bar.
6. Add date navigation.
7. Add Today button.
8. Add calendar/history browser.
9. Add foreground external-change check.
10. Add deleted file modal.

Definition of done:

- Tasks counted correctly.
- Tags parsed correctly.
- Expenses summed correctly.
- Parser does not modify text.
- Date switching works.
- Calendar shows file existence.

---

## Sprint 5: Monetization, Export, Polish, Launch

Goal:

    PlainLog becomes deploy-ready.

Tasks:

1. Implement StoreKit 2.
2. Build Pro paywall.
3. Implement restore purchase.
4. Implement local Pro entitlement.
5. Build weekly summary export.
6. Add themes.
7. Add font options.
8. Polish Settings.
9. Prepare App Store metadata.
10. Prepare App Review notes.
11. Prepare screenshots.
12. Submit TestFlight build.
13. Submit App Store build.

Definition of done:

- Purchase works.
- Restore works.
- Weekly export works.
- App Store labels prepared.
- No analytics.
- No data collection.
- Ready for review.

---

# 14. QA Production Checklist

## Folder access

- Folder picker works.
- Folder confirmation appears.
- Bookmark persists.
- App relaunch restores folder.
- Invalid bookmark shows recovery.
- Stale bookmark refresh is attempted.
- No crash when folder is moved.
- No crash when folder is renamed.
- No hidden files created.
- Reselection with unsaved edits requires confirmation.
- Existing target file warning appears when needed.

## File IO

- Existing file opens.
- New file created only after meaningful save.
- Empty pending file is discarded safely.
- Autosave works.
- Atomic save works.
- External change detected.
- External change detected on foreground return.
- Conflict modal works.
- Save-as-copy works.
- Deleted file handling works.

## iCloud

- iCloud warning appears.
- Cloud-only file triggers download.
- Download failure shows retry.
- Offline state explained.
- Offline capture requires explicit confirmation.
- No duplicate blank file created.

## Editor

- Edit Mode works.
- Preview Mode works.
- Placeholder appears for empty file.
- Text preserved when switching modes.
- Large file warning appears.
- Editor locks when access lost.
- Read-only state appears when appropriate.

## Parser

- Task count correct.
- Tag list correct.
- Expense total correct.
- Invalid syntax ignored.
- Tags with spaces ignored.
- Thousands separators ignored.
- Parser does not modify file.

## Billing

- Purchase works.
- Restore works.
- Pro features unlock.
- Free features remain usable.
- StoreKit errors do not block free features.

## Weekly export

- Export generates correct report.
- Share sheet opens.
- Missing days handled.
- Future end date handled.
- iCloud missing files handled.
- Pro gate works.

---

# 15. Privacy and App Store Compliance

## Privacy principle

PlainLog does not collect user data.

No:

- accounts
- emails
- phone numbers
- analytics
- tracking
- telemetry by default
- cloud note storage
- third-party SDK tracking

## App Store privacy label

Target:

    Data Not Collected

PlainLog itself does not collect user content, identifiers, analytics, or tracking data.

Payment processing may be handled by Apple. This should be reviewed during submission.

## Permissions

PlainLog requires:

    User-selected folder access

PlainLog should not request:

- Camera
- Photos
- Contacts
- Location
- Microphone
- Health
- Call logs
- Accessibility
- Background refresh

## App Store name

    PlainLog: Markdown Daily Log

## App Store subtitle

    Local-first daily Markdown log

## App Review notes

    PlainLog is a local-first Markdown daily log.

    It does not require an account.
    It does not use a database for user notes.
    User notes are stored as standard .md files inside a folder selected by the user.

    The app requires folder access to create and edit these Markdown files.
    No user data is collected by PlainLog.

---

# 16. Launch Positioning

## Primary App Store keywords

- markdown journal
- daily log
- plain text journal
- local first
- offline journal
- daily markdown
- no subscription
- text diary
- md notes
- plain text log

## Screenshot themes

1. One file per day.
2. Your notes are actual files.
3. No account. No database.
4. Tasks, tags, and expenses.
5. Works offline. Bring your own sync.
6. One-time Pro. No subscription.

## Community positioning

PlainLog should be presented as:

    A local-first daily Markdown log for people who hate bloated note apps.

Do not position it as:

    Another generic notes app.

---

# 17. Accepted Risks and Tradeoffs

## Risk 1: iOS bookmarks can fail

Accepted.

Mitigation:

- graceful recovery screen
- clear copy
- no crashes
- folder health screen

## Risk 2: iCloud sync can confuse users

Accepted.

Mitigation:

- download states
- retry flow
- no blind file creation
- explicit offline warning

## Risk 3: SwiftUI TextEditor has limitations

Accepted for v1.

Mitigation:

- no live styling
- Edit/Preview toggle
- large file warning
- simple daily-file focus

## Risk 4: No hidden marker files makes folder verification weaker

Accepted.

Mitigation:

- explicit user confirmation
- warning when unsaved edits exist
- save-as-copy option
- no automatic replacement without confirmation

## Risk 5: No shadow drafts may lose unsaved text if app is killed

Accepted.

Mitigation:

- clear warning
- copy current text option
- editor lock when folder access is lost

---

# 18. Production Release Gate

PlainLog v1 may be released only if all of the following are true.

## Product gate

- Folder selection works.
- Folder recovery works.
- Daily file capture works.
- Edit Mode works.
- Preview Mode works.
- Autosave works.
- Date navigation works.
- Summary bar works.
- Pro purchase works.
- Restore purchase works.
- Weekly export works.

## Safety gate

- No shadow draft cache.
- No hidden marker files.
- No merge engine.
- Folder access loss never crashes.
- Bookmark failure shows recovery flow.
- iCloud cloud-only files are not overwritten.
- External changes are detected.
- Deleted files are handled.
- Save failures are visible.

## Privacy gate

- No analytics SDK.
- No tracking SDK.
- No user content sent anywhere.
- No account system.
- App Store privacy labels prepared.
- App Review notes prepared.

---

# 19. Final Definition of Done

PlainLog v1 is production-ready when:

    The app can select and remember a folder.
    The app recovers gracefully from folder access loss.
    The app opens and creates daily Markdown files safely.
    The app edits raw Markdown with SwiftUI TextEditor.
    The app previews Markdown locally.
    The app autosaves safely.
    The app handles iCloud download states.
    The app detects external changes.
    The app handles deleted files.
    The app parses tasks, tags, and expenses.
    The app offers one-time Pro purchase.
    The app exports weekly summaries.
    The app collects no user data.
    The app creates no hidden marker files.
    The app creates no shadow drafts.
    The app is ready for App Store review.

---

# 20. Source of Truth

This document is the final production source of truth for PlainLog v1.

Any new feature, change, or scope expansion must be added as a new version of this document.

Do not implement anything outside this document without updating this file first.