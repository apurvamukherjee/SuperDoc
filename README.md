# SuperDock

A free, native macOS companion bar for the Dock: widgets, AI usage limits and a coding-agents board. See [SUPERDOCK.md](SUPERDOCK.md) for the full spec.

## Build

Requires macOS 14+, Xcode 16+.

```sh
brew install xcodegen swiftlint
xcodegen            # generates SuperDock.xcodeproj from project.yml
open SuperDock.xcodeproj
```

The `.xcodeproj` is generated and not checked in. Edit `project.yml` for targets, settings and packages, then re-run `xcodegen`.

## Status

- [x] Phase 0: menu bar agent app, Settings window, Sparkle (dormant), SwiftLint
- [ ] Phase 1: companion bar attached to the Dock
# SuperDoc
