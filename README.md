# PlainLog

Local-first, plain-text Markdown daily capture app for iOS.
One `.md` file per day. No account. No database. No lock-in.

## Build (requires macOS + XcodeGen)

```bash
xcodegen generate
xcodebuild -project PlainLog.xcodeproj -scheme PlainLog \
  -destination 'generic/platform=iOS Simulator' build
```
