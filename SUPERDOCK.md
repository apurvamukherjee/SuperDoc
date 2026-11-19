# SuperDock — Build Spec & Handoff

> This is the source of truth for building SuperDock. Read all of it before writing code.
> Build in the phase order in §9. Don't start a phase until the previous one meets its acceptance criteria.

---

## 1. What SuperDock is

SuperDock is a **free, native macOS app** that adds a **companion bar attached to the system Dock**. The bar sits to the left of, right of, or above the native Dock (the user chooses), follows it as it resizes or moves, and is packed with live widgets, AI-agent tracking, window switching and productivity tools.

- **Inspiration:** Dockspace (getdock.space), which charges for Pro. SuperDock gives **every feature away for free**.
- **Main selling point:** AI usage limits plus a live coding-agents board (Claude Code, Codex, Cursor, Antigravity) next to the Dock. None of the other dock apps reviewed have this except Dockspace, which keeps it behind Pro.
- **Secondary selling points:** free, local-first, privacy-respecting, and extensible through a plugin API.

### Owner
Apurva Mukherjee. Comfortable with React/TypeScript/Node, newer to Swift. **Keep code readable, well-commented and idiomatic.** Prefer simple SwiftUI patterns over clever ones.

---

## 2. Hard rules

1. **Native only:** Swift 5.10+/Swift 6, SwiftUI with AppKit where needed. No Electron, no web views for the core UI.
2. **Minimum OS:** macOS 14 Sonoma. Liquid Glass styling on macOS 26+, with graceful fallback.
3. **Everything is free.** No paywalls, license checks or Pro flags.
4. **Local-first:** no accounts, no analytics, no crash reporting that sends data off the Mac. Network calls only for widgets that need them (weather, feeds, prices), and only when that widget is enabled.
5. **Never read AI prompts or generated code.** The AI features read only metadata: status, timestamps, token counts, limit percentages, project folder name.
6. **Own branding.** Do not reuse Dockspace's names, mascot (Tilo), copy, icons or assets. Use our own names: "Cache Cleaner", not "Disk Doctor", and our own buddy character (name TBD; use the placeholder `Buddy`).
7. **Permissions on demand.** Ask for Accessibility, Screen Recording, Calendar and similar only when the user enables a feature that needs them, with a clear explanation screen first.
8. **Never delete user files directly.** The cache cleaner moves files to the Trash (`FileManager.trashItem`).
9. **Restore the system.** If SuperDock changes Dock settings (replacement mode), it must restore the originals when the user quits or turns the mode off, and on next launch after a crash.
10. **Distribution outside the App Store:** Developer ID signing, notarization, Sparkle auto-updates. No App Sandbox, since Accessibility control isn't allowed inside it.

---

## 3. Tech stack

| Concern | Choice |
|---|---|
| Language/UI | Swift, SwiftUI, AppKit (`NSPanel`, `NSHostingView`, `NSVisualEffectView`) |
| Dock geometry | Accessibility API (`AXUIElement`, `AXObserver`) on `com.apple.dock` |
| Window list/control | Accessibility API + `CGWindowListCopyWindowInfo` |
| Window previews | ScreenCaptureKit (`SCShareableContent`, `SCScreenshotManager`) |
| App tracking | `NSWorkspace` notifications |
| Persistence | `UserDefaults` for settings, JSON in `~/Library/Application Support/SuperDock/` for layouts/profiles/clipboard |
| File watching | `DispatchSource.makeFileSystemObjectSource` / FSEvents |
| System stats | `host_statistics64`, IOKit (battery, thermal), `getifaddrs` (network), `proc_pidinfo` |
| Media | MediaRemote (private framework; isolate it behind a protocol so it can be swapped out) |
| Weather | Open-Meteo (no key) |
| Updates | Sparkle 2 (Swift Package) |
| Login item | `SMAppService.mainApp` |
| Hotkeys | `KeyboardShortcuts` package (sindresorhus) or Carbon `RegisterEventHotKey` |
| Packaging | Swift Package dependencies only; no CocoaPods |

App type: menu-bar agent app (`LSUIElement = YES`) with a Settings window.

---

## 4. Project structure

```
SuperDock/
├── SuperDock.xcodeproj
├── SuperDock/
│   ├── App/
│   │   ├── SuperDockApp.swift          # @main, menu bar extra, settings scene
│   │   ├── AppDelegate.swift           # lifecycle, crash-safe Dock restore
│   │   └── Permissions.swift           # AX / Screen Recording checks + onboarding
│   ├── Dock/
│   │   ├── NativeDockTracker.swift     # reads Dock frame/orientation/autohide via AX, publishes changes
│   │   ├── BarPanel.swift              # NSPanel subclass (borderless, non-activating)
│   │   ├── BarPlacement.swift          # left/right/above/floating math + coordinate flipping
│   │   ├── BarController.swift         # owns panel, reacts to tracker, profiles, displays
│   │   └── DockReplacement.swift       # optional mode: hide system Dock, own app strip
│   ├── Widgets/
│   │   ├── Core/
│   │   │   ├── SuperWidget.swift       # protocol (see §6)
│   │   │   ├── WidgetRegistry.swift
│   │   │   ├── WidgetHost.swift        # lays out tiles, drag-to-reorder
│   │   │   └── WidgetPicker.swift
│   │   ├── AI/  System/  Time/  Weather/  Productivity/  Dev/  Media/  Finance/  News/  Fun/
│   ├── Services/                       # shared data sources used by many widgets
│   │   ├── SystemStatsService.swift
│   │   ├── AIUsageService.swift
│   │   ├── AgentSessionService.swift
│   │   ├── ClipboardService.swift
│   │   ├── NowPlayingService.swift
│   │   ├── WeatherService.swift
│   │   └── WindowService.swift
│   ├── Windows/                        # previews, Alt+Tab switcher
│   ├── Launchpad/
│   ├── Profiles/
│   ├── Theming/
│   ├── Plugins/                        # plugin API (Phase 8)
│   ├── Settings/
│   └── Resources/
├── SuperDockTests/
└── docs/
```

---

## 5. Core mechanics (how the hard parts work)

### 5.1 Finding the native Dock
The Dock's icon strip is an `AXList` child of the Dock process.

```swift
func nativeDockFrame() -> CGRect? {
    guard let dock = NSRunningApplication
        .runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
    let app = AXUIElementCreateApplication(dock.processIdentifier)
    var children: CFTypeRef?
    AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &children)
    guard let list = (children as? [AXUIElement])?.first(where: { role(of: $0) == kAXListRole }) else { return nil }
    // read kAXPositionAttribute + kAXSizeAttribute → CGRect (top-left origin, global coords)
}
```
- Convert from AX coordinates (top-left origin) to AppKit coordinates (bottom-left origin) using the **primary screen's** height.
- Orientation: `UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation")` (`bottom`/`left`/`right`).
- Auto-hide: `autohide` key. When hidden, the AX frame moves off-screen or shrinks, so treat "frame not intersecting any screen's visible area" as hidden.

### 5.2 Following the Dock
- Register an `AXObserver` on the list for `kAXResizedNotification` and `kAXMovedNotification`.
- Fallbacks: `NSWorkspace.didLaunchApplication` / `didTerminateApplication` (the Dock grows and shrinks), `NSApplication.didChangeScreenParametersNotification`, and a light 250 ms poll **only while** the Dock is auto-hidden and the cursor is near its edge.
- If the Dock process restarts (`killall Dock`), re-acquire the AX element.
- Animate the bar's frame changes (`NSAnimationContext`, ~0.2 s) so it moves with the Dock.

### 5.3 The bar panel
```swift
final class BarPanel: NSPanel {
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
    }
    override var canBecomeKey: Bool { true }   // allows text fields in widgets
}
```
- Background: `NSVisualEffectView` (`.hudWindow`, `.behindWindow`) or Liquid Glass on macOS 26. Corner radius matches the Dock (about 16–18 pt).
- Placement options: `.left`, `.right`, `.above`, and `.floating` (user drags it; position saved per display). Gap is configurable (default 8 pt). When the Dock is vertical, offer `.top`/`.bottom` of the Dock instead.
- Full-screen apps: hide the bar by default. Show alerts as a small non-activating "pill" at the bottom edge.

### 5.4 Dock replacement mode (optional, off by default)
- Save the current values of `autohide` and `autohide-delay` first, then set `autohide=true` and `autohide-delay=1000`, then `killall Dock`.
- Draw our own app strip: pinned apps (bundle URLs) and running apps (`NSWorkspace.runningApplications`, filtered to `.regular`), plus Trash.
- On quit, crash recovery (a flag file checked at launch) or toggle-off: restore the saved values and `killall Dock`.

### 5.5 AI usage & agents (key differentiator; verify data sources first)
**Before building, inspect the real files on the dev machine and document their exact formats in `docs/ai-data-sources.md`.** The starting points below need to be checked:
- **Claude Code:** session transcripts in `~/.claude/projects/<encoded-path>/*.jsonl` (per-message `usage` token counts, timestamps, cwd). Work out where session and weekly limit percentages can be read from locally: logs, the status line payload, or any local cache. If they can't be read, estimate from token totals against plan limits the user sets, and label the number "estimated".
- **Codex:** `~/.codex/sessions/**/*.jsonl`. Look for token-count / rate-limit events with primary (5-hour) and secondary (weekly) usage percentages.
- **Antigravity:** data is only available while the app runs. Investigate local state/log files; if there's nothing reliable, ship it marked "experimental".
- **Cursor:** session activity only (for the agents board), from its local logs/state. Investigate.

Agents board status rules:
- **Working:** the session file was written within the last N seconds and the last event is an assistant or tool event
- **Needs input:** the last event is a permission or approval request, or the assistant finished its turn and is waiting for the user
- **Done:** the turn finished
- **Idle:** no writes for more than X minutes

Parse only the fields listed in rule 5. Use `FileHandle` to tail files incrementally and never load whole transcripts into memory.

### 5.6 Window previews & switcher
- Window list: AX `kAXWindowsAttribute` per app, plus `CGWindowListCopyWindowInfo` for IDs and titles.
- Thumbnails: `SCScreenshotManager.captureImage` per `SCWindow`, cached and refreshed on hover.
- Hover over native Dock icons: read the hovered `AXDockItem` under the cursor (AX hit test on the Dock list) and show a preview panel above it.
- Alt+Tab: global hotkey opens a panel of windows; Tab/Shift-Tab to cycle, release to focus (`AXRaise` + `NSRunningApplication.activate`).
- Actions per window: focus, minimize, close, quit app, drag out.

### 5.7 Frozen-app detection
Every few seconds, send an AX attribute request to each running app with a short timeout (`AXUIElementSetMessagingTimeout`). Mark an app as unresponsive after repeated timeouts, show a badge, and offer Force Quit (`forceTerminate()`).

---

## 6. Widget system (build this before any widgets)

```swift
protocol SuperWidget: Identifiable {
    static var id: String { get }              // "system.cpu"
    static var name: String { get }
    static var category: WidgetCategory { get }
    static var symbol: String { get }          // SF Symbol for the picker
    static var supportedSizes: [TileSize] { get }  // .compact, .medium, .wide, .large
    static var requiredPermissions: [Permission] { get }
    static var usesNetwork: Bool { get }

    associatedtype Settings: Codable & Equatable
    associatedtype Body: View
    @MainActor func view(size: TileSize, settings: Settings) -> Body
    func settingsView(_ settings: Binding<Settings>) -> AnyView?
}
```
- **Tile sizes:** Compact (1 col), Medium (2), Wide (3), Large (4). All share the bar's height.
- **Services, not widgets, own data.** Widgets subscribe to shared `ObservableObject` services such as `SystemStatsService`, so ten CPU-related tiles still mean one sampler. Services start when the first subscriber appears and stop when the last one leaves.
- **Registry:** every widget registers in `WidgetRegistry`. The picker groups widgets by category with search, and the user drags tiles to reorder.
- **Layout:** saved per profile per display as JSON: `[{widgetId, instanceId, size, settings}]`.
- **Budget:** a simple widget should be 30–80 lines. If one grows past 200, the logic belongs in a service.
- **Plugins (Phase 8):** third-party widgets as bundles loaded from `~/Library/Application Support/SuperDock/Plugins/`. Define a stable `SuperDockKit` Swift package with the protocol. Investigate safe options for loading code: XPC out-of-process rendering vs a declarative JSON/JS widget format. Decide and document in `docs/plugins.md` before implementing.

---

## 7. Full feature list

### 7.1 Bar & placement
- Companion bar attached to the native Dock: left / right / above (or top/bottom of a vertical Dock), plus free floating
- Follows the Dock as it grows, shrinks, moves or auto-hides
- Optional full Dock replacement mode
- Vertical layout for side Docks
- Tile sizes Compact/Medium/Wide/Large, custom 1–4 column widths
- Display profiles: separate bars for laptop and external monitor, switching automatically
- Hidden over full-screen apps; alerts as a bottom-edge pill
- Live wallpapers: video, Metal shaders, custom MP4/MOV files, Lock Screen video

### 7.2 Windows & switching
- Live window previews on hover over Dock icons
- Alt+Tab window switcher; optional previews in native Cmd+Tab
- Drag windows out of previews; per-window close/minimize/quit
- Filter to the current Space
- Ctrl+Opt+1–9 jumps to the app in that position
- Trackpad gestures (e.g. swipe to open the switcher)
- Frozen-app detection with force quit

### 7.3 Profiles
- Named layouts (e.g. Code, Design, Study)
- Switch automatically with Spaces or Focus modes, or by hotkey

### 7.4 Files & launching
- Fan-out folders (stack / grid / list)
- File drop shelf for staging files between apps
- Smart Stacks (recent files, Downloads, Screenshots, auto-grouped)
- Built-in Launchpad: full-screen app grid, search, folders

### 7.5 Look & customization
- Themes, including Liquid Glass (macOS 26+) with fallback
- Custom icons for any app, including system apps (applied in our own UI)
- Corner radius, opacity, blur, spacing, accent color

### 7.6 AI & agents
- Claude Code usage: session and weekly %
- Codex limits: 5-hour and weekly
- Antigravity quota: 5-hour and weekly
- Combined AI Limits tile: wide bars or a compact 3-ring view
- Used/remaining toggle, live reset countdowns
- Coding agents board: Claude Code, Cursor, Codex, Antigravity sessions across all projects; statuses working (blue) / needs input (orange) / done (green) / idle (grey)
- Buddy mascot: notes, "Ask Buddy", pops up when an agent finishes or needs approval, plus cache-cleaner and hydration nudges

### 7.7 Clipboard & notch
- History of text, links, hex colors, images and files, with type filters (default hotkey ⌥⌘V)
- Notch shelf: recent copies fan out under the MacBook notch
- Copy Peek: small preview after ⌘C
- Pinned paste slots ⌃⌥⌘1–9
- Skips items marked concealed/transient (`org.nspasteboard.ConcealedType`, `TransientType`) by password managers

### 7.8 Media & controls
- Now Playing (Apple Music, Spotify, browser media) with controls
- Quick Actions: lock, sleep, screenshot, empty Trash, toggle hidden files, etc.
- Control Center toggles: Wi-Fi, Bluetooth, Do Not Disturb, brightness, volume

### 7.9 Productivity & focus
Pomodoro, Water tracker, Screen Notes (floating translucent notes, ⌃⌥⌘N), Quick Translate, Stand Up, Posture, Eye Break, Breathing, Habits, To-Do, Quick Note, Journal, Countdown, Stopwatch, Alarm, Timer, Focus Stats, Focus Radio, White Noise, Metronome, Meditation

### 7.10 System
- Cache Cleaner: Xcode DerivedData, Simulator caches, pnpm/npm/Homebrew caches, old disk images. Explains each item in plain language and moves files to the Trash. Doesn't need Full Disk Access.
- CPU, Disk, Battery, Network, RAM and memory pressure, GPU, Thermal, Power, Disk Activity, Top Processes, Top Apps, Uptime, Wi-Fi, Bluetooth, Display, Volumes, Battery Health, AirPods Battery, VPN, Mic Mute, Caps Lock, Dark Mode, Lock Screen, Trash size, Simulators
- Live CPU sparklines

### 7.11 Weather & time
- Weather (Open-Meteo), 7-Day, Air Quality, UV, Feels Like, Wind, Rain Soon, Sunrise & Sunset, Sun Clock
- Clock, Date, Analog, Flip and Binary clocks, World Clock, Second City, Week, Week Number, Day/Month/Year Progress, Unix Time, Time Zone Converter, Month Calendar, Next Event, Today's Events (EventKit), Moon Phase, Weekend

### 7.12 Developer tools
- Git Status, Commits Today, Pull Requests, GitHub Notifications (user-provided token stored in Keychain)
- CI Status, Local Ports, Docker, Uptime Monitor, SSL Expiry, Cron Next Run, Latency, Public IP, npm Downloads, Homebrew
- JSON Formatter, Regex Tester, UUID, Base64, Hash, JWT Decoder, Case Converter, Lorem Ipsum, Counter, URL Tools, Password Generator, QR Code
- Calculator, Unit Converter, Color Picker, Color Converter, Currency, Snippets, Bookmarks, Recent Files, Folders, App Launcher, Screenshot, Screen Recorder

### 7.13 Finance, health, news, fun
- **Finance:** Bitcoin, Ethereum, Crypto Watchlist, Budget, Expenses, Subscriptions, Currency Pairs, Tip & Split, Meeting Cost
- **Health:** Bedtime, Mood, Daily Goal, Caffeine, Keep Awake
- **News:** Hacker News, Lobsters, Reddit, RSS, DEV, Word of the Day, Quote, Picture of the Day
- **Fun:** Dice, Coin Flip, Tic-Tac-Toe, Rock Paper Scissors, Magic 8 Ball, Dad Joke, Cat Fact, Random Fact, Mirror, Soundboard, ISS Tracker

### 7.14 Platform
- Widget system + picker (§6)
- Plugin API (`SuperDockKit`) and a community widget gallery
- Settings window: General, Placement, Profiles, Widgets, AI, Clipboard, Windows, Appearance, Shortcuts, Permissions, About
- Onboarding: welcome → choose placement → grant Accessibility → pick starter widgets
- Sparkle updates, launch at login, export/import settings

---

## 8. Permissions map

| Permission | Needed for | When to ask |
|---|---|---|
| Accessibility | Dock tracking (core), window control, Alt+Tab, frozen-app detection | Onboarding (required for the bar to attach) |
| Screen Recording | Window previews, screen recorder | When previews are enabled |
| Calendars / Reminders | Events, To-Do sync | When those widgets are added |
| Location | Weather auto-location | Optional; otherwise use a manually chosen city |
| Microphone | Mic Mute widget status | When added |
| Notifications | Timers, alarms, agent alerts | First time an alert-capable widget is added |

---

## 9. Build phases & acceptance criteria

**Phase 0 — Setup**
- Xcode project, menu-bar agent app, Settings scene, Sparkle stub, SwiftLint, the folder structure from §4, a README
- ✅ App launches with a menu bar icon and opens Settings

**Phase 1 — Companion bar attached to the Dock** *(core)*
- `NativeDockTracker`, `BarPanel`, `BarPlacement`, Accessibility onboarding
- ✅ The bar appears left, right or above the Dock with a configurable gap
- ✅ It follows the Dock within ~100 ms when apps launch or quit, and when Dock size or position changes
- ✅ It hides and shows with an auto-hidden Dock, hides over full-screen apps, and survives `killall Dock`
- ✅ It works with Docks on the bottom, left and right, and on external displays

**Phase 2 — Widget system**
- Protocol, registry, host, picker, persistence, shared services
- Ship 5 reference widgets: Clock, Date, CPU, Battery, Weather
- ✅ User can add, remove, reorder and resize tiles, and the layout persists across relaunches

**Phase 3 — AI & agents** *(differentiator)*
- First write `docs/ai-data-sources.md` from real files on the machine
- `AIUsageService`, `AgentSessionService`, Claude/Codex/Antigravity tiles, combined rings tile, agents board, Buddy alerts
- ✅ Numbers match what the tools themselves show, or are clearly labelled "estimated"
- ✅ Board statuses update within 2 s; no prompt or code text is ever read into memory

**Phase 4 — Windows & switching**
- Hover previews over native Dock icons, Alt+Tab, Ctrl+Opt+1–9, frozen-app detection, gestures
- ✅ Previews appear in under 300 ms; the switcher works across Spaces

**Phase 5 — Clipboard & notch**
- ✅ History, filters, notch shelf, Copy Peek, pinned slots; concealed items are never stored

**Phase 6 — System, time, weather, media, Quick Actions, Control Center widgets**
- ✅ Idle CPU usage under 1% with 10 widgets running; memory under 150 MB

**Phase 7 — Profiles, folders, file shelf, Smart Stacks, Launchpad, themes, custom icons, replacement mode, display profiles, live wallpapers**

**Phase 8 — Plugin API + remaining widgets** (productivity, dev, finance, news, fun), community gallery

**Phase 9 — Release**
- Developer ID signing, notarization, DMG, Sparkle appcast on GitHub Releases, Homebrew cask, landing page
- ✅ A clean install on a fresh Mac works end to end

---

## 10. Quality bar

- **Performance:** event-driven over polling; shared samplers; pause updates for widgets that aren't visible; no work while the screen is locked or asleep.
- **Accessibility:** VoiceOver labels on all tiles; respect Reduce Motion and Reduce Transparency.
- **Localization-ready:** all strings in `Localizable.xcstrings` (English first).
- **Tests:** unit tests for `BarPlacement` math, coordinate flipping, AI log parsers (with fixture files), status rules, and layout persistence.
- **Docs:** each phase updates `README.md` and `docs/`.
- **Commits:** small, one feature per commit, clear messages.

---

## 11. Competitor reference (what to match or beat)

| App | Price | Notes |
|---|---|---|
| Dockspace | Free + Pro | Baseline feature set; AI limits and agents board are Pro |
| CoolDock | One-time | Second dock beside the native one, 160+ widgets, per-widget permission prompts |
| DockDoor | Free, open source | Native Dock previews, Alt+Tab, previews in Cmd-Tab |
| DockDoor Pro | Paid | Replacement Dock, profiles, file tray, widget marketplace, minimize-into-icon |
| Docky | Free, GPLv3 | Replacement, Launchpad, Smart Stacks, live-preview switcher |
| uBar 4 | ~$30 | Taskbar mode, in-dock reminders, frozen-app detection, Ctrl+Opt+number |
| ActiveDock 2 | $19+ | Start menu, themes, custom icons, gestures |
| Dockish | $6.99 | Multi-monitor docks, folders |
| DockMaster Pro | Free, open source | Multi-row grid, network speed, workspaces per Space |

**Positioning:** "Everything the paid docks charge for, free — plus live AI limits and a coding-agents board."

---

## 12. Open decisions (ask Apurva before deciding)

1. Open source (and which license), or closed but free?
2. Buddy character's name and design
3. Default look: native frosted glass vs a distinct SuperDock style
4. Multi-monitor default: follow the Dock's screen, or show a bar on every screen?
5. Share widgets/code with Notchy (his notch widget app)?
6. Plugin format: native bundles via XPC vs a declarative/JS widget format
