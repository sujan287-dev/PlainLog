# PlainLog — Engineering Rules (read before touching any file)

PlainLog is a local-first, plain-text Markdown daily-capture app for iOS.
One .md file per day (YYYY-MM-DD.md), written into a folder the user chooses.
"Plain Log.md" in the repo root is the final production specification.

## Environment
- Builds happen ONLY on macOS via GitHub Actions (macos-latest runners).
- Local machine is Windows. Never attempt xcodebuild, xcodegen, or
  simulator commands locally. They will fail.
- Project file is generated from project.yml via XcodeGen on CI.

## Locked constraints (NEVER violate — from production spec §4)
- No accounts, no cloud backend, no database for user content.
- No analytics, no tracking SDKs, no third-party SDKs of any kind.
- No hidden marker files in the user's folder (.plainlog, folder.json, etc.).
- No shadow draft cache. No merge engine. No CRDT.
- User content lives ONLY as standard .md files. App settings in private sandbox.
- SwiftUI TextEditor only in v1 (no custom UITextView).
- No live syntax highlighting in v1.
- All user-folder access goes through security-scoped bookmarks.
- File writes use NSFileCoordinator with atomic replacement.
- No blind iCloud file creation. Never overwrite cloud-only files.

## Stack
- Swift, SwiftUI, Foundation. Minimum iOS 17.0.
- StoreKit 2 for Pro purchase (arrives Sprint 5).
- Zero third-party runtime dependencies.
- Dev tooling only: XcodeGen (project generation), GitHub Actions (CI).

## Core services (from spec §12)
- FolderAccessService — folder selection, bookmark persistence/resolution,
  stale refresh, access state, recovery flow. (Sprint 1)
- FileIOService — coordinated reads/writes, iCloud download checks,
  external change detection, conflict detection. (Sprint 2)
- DocumentStore — selected date, file URL, text, dirty/save/load state,
  pending new file state. (Sprint 3)
- ParserKit — task/tag/expense parsing, summary model. (Sprint 4)
- BillingKit — StoreKit 2 product loading, purchase, restore, entitlement. (Sprint 5)
- ExportKit — weekly summary generation, share sheet prep. (Sprint 5)

## Code standards
- Handle EVERY error path. A local-first app must NEVER crash — especially
  around bookmark resolution and file I/O.
- No force-unwrap on I/O paths. No fatalError in user-reachable code.
- Use os.log via Support/Log.swift. NEVER log user note content.
- Services are headless and testable. Views observe services; views don't own logic.
- Use @Observable macro (iOS 17+) for services, not ObservableObject.

## Build commands (CI only — macOS)
- xcodegen generate
- xcodebuild -project PlainLog.xcodeproj -scheme PlainLog \
    -destination 'generic/platform=iOS Simulator' build

## Current status
Sprint 1 — Folder Foundation. Executing piece by piece.
Build verification: via GitHub Actions on push to main.
