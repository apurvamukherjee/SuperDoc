<div align="center">

<img src="design/logo/icon.svg" width="128" alt="SuperDock icon">

# SuperDock

**A companion bar for your Mac's Dock. Live widgets, your AI limits and a coding-agents board, sitting right next to the Dock.**

Everything the paid dock apps charge for, free.

[![Download](https://img.shields.io/github/v/release/apurvamukherjee/SuperDoc?label=Download&style=for-the-badge&color=26282E&labelColor=FBF9F4&logo=apple&logoColor=26282E)](https://github.com/apurvamukherjee/SuperDoc/releases/latest)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-26282E?style=for-the-badge&labelColor=FBF9F4)](#install)
[![MIT](https://img.shields.io/badge/license-MIT-26282E?style=for-the-badge&labelColor=FBF9F4)](LICENSE)

![57 widgets](https://img.shields.io/badge/widgets-57-F97316?style=flat-square)
![Apple silicon + Intel](https://img.shields.io/badge/universal-Apple%20silicon%20%2B%20Intel-3B82F6?style=flat-square)
![No accounts](https://img.shields.io/badge/accounts-none-22C55E?style=flat-square)
![No analytics](https://img.shields.io/badge/analytics-none-22C55E?style=flat-square)

<br>

<img src="docs/images/ui/hero-bar.jpg" alt="The SuperDock bar: AI limits for Claude and Codex, a coding-agents board with one session needing input, a clock and the weather" width="900">

</div>

---

## Why SuperDock

|  |  |
|---|---|
| 🧠 **Your AI limits, always visible** | Claude Code's 5-hour and weekly usage and Codex's limits as rings or bars, with reset countdowns. Anything at 80 % or more turns coral. |
| 🤖 **A live coding-agents board** | Every Claude Code and Codex session: working, needs your input, or done. Limo, SuperDock's mascot, pops up when an agent finishes or is waiting on you. |
| 🧲 **Sits on the real Dock** | It isn't a second dock floating somewhere else. The bar attaches to the left, right or top of the macOS Dock, follows it as it grows or shrinks, and hides along with it. |
| 💸 **Free. All of it.** | No Pro tier, no trial, no account. MIT licensed. |
| 🔒 **Local-first** | No analytics, no accounts. Prompts and code are never read, and clipboard history never leaves your Mac. |

## Install

1. Download the DMG from the [latest release](https://github.com/apurvamukherjee/SuperDoc/releases/latest).
2. Drag **SuperDock** into **Applications**.
3. Open it. Limo walks you through placement, Accessibility access (needed to attach the bar to the Dock) and a starter set of widgets.

> [!NOTE]
> Releases aren't notarized yet. The first time you open SuperDock, go to **System Settings → Privacy & Security** and click **Open Anyway**, or run:
> ```sh
> xattr -dr com.apple.quarantine /Applications/SuperDock.app
> ```

**Requires macOS 14 Sonoma or later.** Universal: runs natively on Apple silicon and Intel.

---

# The UI book

Every screen in SuperDock is built from one small design system: a few surface styles, one type scale, ten tile layouts and five shared states, plus a mascot. This section walks through each part. Each chapter shows **what shipped**, then the **design mockup** it was built from (expand it underneath).

> [!NOTE]
> The pictures of the app are drawn by the app itself: `SuperDock -renderGallery <folder>` renders the real SwiftUI views offscreen with sample data. Liquid Glass and Frosted materials can't be captured offscreen, so those panels use a close colour match; on your Mac they're real glass.

**Chapters:** [The bar](#1-the-bar) · [AI limits & agents](#2-ai-limits--coding-agents) · [Widgets](#3-the-widget-catalog) · [Tile kit](#4-the-tile-kit) · [Limo](#5-limo) · [Onboarding](#6-onboarding) · [Settings](#7-settings) · [Around the bar](#8-around-the-bar) · [Design rules](#9-design-rules)

## 1. The bar

The bar sits beside the Dock and matches its height. It comes in four styles, each in light and dark: **Liquid Glass**, **Frosted**, **Solid** and the cream-and-ink **Paper**. With Reduce Transparency on, the glass styles turn solid. Tiles scale with the Dock: a tiny Dock (56 pt) drops labels, a huge one (120 pt) adds a detail line. Beside a left or right Dock the bar turns vertical.

Drag a tile to reorder it: it lifts, its neighbours slide aside, and you feel a tick when it drops. Right-click for sizes, settings and Remove. In Dock replacement mode the system Dock hides and the bar starts with your apps.

<img src="docs/images/ui/bar.jpg" alt="The bar in every style, at three Dock sizes, vertical, in Dock replacement mode, while dragging, and empty" width="100%">

<details><summary>Design mockup: styles, scale, orientation and interactions</summary>

<img src="docs/images/mockups/01-bar-styles-scale-interactions.jpg" alt="Bar mockup" width="100%">
</details>

## 2. AI limits & coding agents

The two headline tiles. **AI Limits** shows Claude and Codex as concentric rings when compact, and as fuel-gauge bars with reset countdowns when wider. Each bar has a hairline at 80 %; past it the number turns coral and gets a warning triangle. Providers are told apart by colour and a monogram badge, never by logo.

**Coding Agents** shows every session as a chip. "Needs input" is a filled coral chip that sorts first and nudges the tile when it appears; "working" breathes only while the agent is actually working.

<img src="docs/images/ui/ai.jpg" alt="AI Limits and Coding Agents at every size and state" width="100%">

<details><summary>Design mockup: AI limits and coding agents</summary>

<img src="docs/images/mockups/04-hero-ai-limits-coding-agents.jpg" alt="AI tiles mockup" width="100%">
</details>

## 3. The widget catalog

57 widgets, each in up to four sizes (compact, medium, wide, large), all on the same tile kit.

### Time
Clock, Date, World Clock with a day or night sky, Analog, Day/Week/Month/Year progress, Week number, Unix time and a Moon drawn with its real lit fraction.

<img src="docs/images/ui/time.jpg" alt="Time widgets" width="100%">

### System
CPU with a chart that warms as load rises, memory pressure, a two-tone network graph, disk, battery, uptime and thermal state. Status is never shown by colour alone.

<img src="docs/images/ui/system.jpg" alt="System widgets" width="100%">

### Weather
Skies matched to the condition and time of day, 7-day range bars on one scale, a sun arc, and detail tiles for feels-like, wind, UV and rain.

<img src="docs/images/ui/weather.jpg" alt="Weather widgets" width="100%">

<details><summary>Design mockup: time, system and weather</summary>

<img src="docs/images/mockups/03-catalog-time-system-weather.jpg" alt="Time, system and weather mockup" width="100%">
</details>

### Media & controls
Now Playing tinted by the album art, Quick Actions, and Control Center–style volume, brightness and Wi-Fi.

<img src="docs/images/ui/media-controls.jpg" alt="Media and controls widgets" width="100%">

### Files & productivity
A fanned stack of your newest files, a shelf you can drop files on, Launchpad, Pomodoro and timers, a stopwatch with laps, a water tracker, notes and to-dos.

<img src="docs/images/ui/files-productivity.jpg" alt="Files and productivity widgets" width="100%">

### Developer, fun and plugins
Git status, local ports, UUIDs and passwords that copy on tap (a shown password hides again after a minute), dice, coin and Magic 8 Ball, and the four plugin templates (value, gauge, text, list) that every JSON plugin uses.

<img src="docs/images/ui/dev-fun-plugins.jpg" alt="Developer, fun and plugin widgets" width="100%">

<details><summary>Design mockup: media, controls, files, productivity, developer, fun and plugins</summary>

<img src="docs/images/mockups/02-catalog-media-controls-files-productivity-dev-fun-plugins.jpg" alt="Catalog mockup" width="100%">
</details>

## 4. The tile kit

Every widget is one of ten layouts (stat, ring, bars, chart, list, media, control, glyph, calendar/time, input), each at four sizes, with the same slots: **label** top-left, **hero** on the baseline, **detail** at the bottom. Five shared states look the same everywhere: loading skeleton, empty (a sleeping Limo), offline (last value dimmed, with its age), needs permission, and needs setup.

<img src="docs/images/ui/kit-glass-dark.jpg" alt="The tile kit in Liquid Glass dark" width="100%">

<details><summary>The same kit in Solid light and Paper</summary>

<img src="docs/images/ui/kit-solid-light.jpg" alt="The tile kit in Solid light" width="100%">
<img src="docs/images/ui/kit-paper.jpg" alt="The tile kit in Paper" width="100%">
</details>

<details><summary>Design mockup: archetypes and shared states</summary>

<img src="docs/images/mockups/05-kit-archetypes-states.jpg" alt="Kit mockup" width="100%">
</details>

## 5. Limo

Limo grew out of the app icon's face. Their eyes follow your cursor when you come near the bar, they blink and breathe (sparingly), and the coral cheek changes with their mood. They have twelve reactions, from celebrating a finished agent to fanning themselves when the CPU runs hot.

When something needs you, Limo springs out of the bar with a pill: an agent is done or waiting, an app froze (with Force Quit), a limit is close. In Settings → Limo you choose **Lively**, **Calm** (no bouncing or gaze) or **Hidden** (plain pills, no character).

<img src="docs/images/ui/limo.jpg" alt="Limo's character sheet, reactions, alert pills and presence levels" width="100%">

<details><summary>Design mockup: Limo</summary>

<img src="docs/images/mockups/06-limo-character.jpg" alt="Limo mockup" width="100%">
</details>

## 6. Onboarding

Four Paper-themed steps, about 40 seconds, hosted by Limo: a welcome, where the bar should sit (with a live preview), the one Accessibility permission (the step moves on by itself once you switch it on), and a starter set. Finish throws confetti and the window shrinks into the bar, where the tiles land one at a time.

<img src="docs/images/ui/onboarding.jpg" alt="The four onboarding steps, plus placement options, access granted and the empty starter set" width="100%">

<details><summary>Design mockup: onboarding</summary>

<img src="docs/images/mockups/09-onboarding.jpg" alt="Onboarding mockup" width="100%">
</details>

## 7. Settings

A sidebar window. The Widgets pane shows your bar as a strip you can reorder, category chips, search, and a card for every widget with a live preview and size pills. Placement has a live Dock-and-bar diagram; Appearance previews your own tiles in each style.

<table>
<tr>
<td><img src="docs/images/ui/settings-widgets-light.jpg" alt="Widgets pane, light"></td>
<td><img src="docs/images/ui/settings-widgets-dark.jpg" alt="Widgets pane, dark"></td>
</tr>
<tr>
<td><img src="docs/images/ui/settings-widgets-tile-light.jpg" alt="Editing a tile in the Widgets pane"></td>
<td><img src="docs/images/ui/settings-placement-dark.jpg" alt="Placement pane with the live diagram"></td>
</tr>
<tr>
<td><img src="docs/images/ui/settings-appearance-light.jpg" alt="Appearance pane"></td>
<td><img src="docs/images/ui/settings-limo-light.jpg" alt="Limo pane: Lively, Calm, Hidden"></td>
</tr>
<tr>
<td><img src="docs/images/ui/settings-ai-dark.jpg" alt="AI and Agents pane"></td>
<td><img src="docs/images/ui/settings-plugins-light.jpg" alt="Plugins pane"></td>
</tr>
</table>

<details><summary>Design mockup: Settings and the widget gallery</summary>

<img src="docs/images/mockups/07-settings-widgets.jpg" alt="Settings mockup" width="100%">
</details>

## 8. Around the bar

The panels that open from the bar, the notch and your keyboard, in the same style as the bar: clipboard history (⌥⌘V), Copy Peek after ⌘C, the notch shelf, the ⌥Tab switcher, Dock hover previews, the ⌃⌥1–9 HUD, Launchpad, the menu bar extra, and the Stack and Shelf popovers. Password-manager copies are never stored; a "Protected" row shows one happened.

<img src="docs/images/ui/surfaces.jpg" alt="Clipboard panel, Copy Peek, notch shelf, switcher, Dock previews, HUD, Launchpad, menu and popovers" width="100%">

<details><summary>Design mockup: windows, clipboard, notch and popovers</summary>

<img src="docs/images/mockups/08-around-the-bar-windows-clipboard-notch-popovers.jpg" alt="Around-the-bar mockup" width="100%">
</details>

## 9. Design rules

The rules every screen follows. The code lives in [`SuperDock/DesignSystem/`](SuperDock/DesignSystem/).

| Rule | What it means |
|---|---|
| **Tokens, not raw colours** | Tiles read colours from the surface tokens for the current style, so one layout works on glass, solid and paper, light or dark, over any wallpaper. |
| **One type scale** | Thirteen text styles tuned for a 61 pt tall tile, scaled with the Dock. Numbers use monospaced digits so they don't jitter. |
| **Square tiles, one row** | A tile is one unit tall and 1–4 units wide (`unit = bar height − 12`); vertical bars turn the same tiles portrait. |
| **Fixed slots** | Label top-left, hero on the baseline, detail at the bottom. Widgets fill slots; they don't invent layout. |
| **Colour never alone** | Status always pairs colour with a glyph or a word (a check, a warning triangle, "Hot"). |
| **Animate on change, then rest** | Idle CPU stays under 1 %: nothing loops unless something is happening (an agent working, a timer running), and Reduce Motion turns every move into a fade. |
| **One mascot, used sparingly** | Limo appears for moments that matter (empty states, alerts, onboarding) and stays out of the way otherwise. |

The full brief is [design/DESIGN_BRIEF.md](design/DESIGN_BRIEF.md); full-resolution mockups are in [design/mockups/](design/mockups/), and the build log in [design/REDESIGN_LOG.md](design/REDESIGN_LOG.md).

---

## Features

### 🧩 57 widgets

| | |
|---|---|
| **AI** | AI Limits · Coding Agents |
| **Time** | Clock · Date · Analog Clock · World Clock · Month Calendar · Week Number · Day/Month/Year Progress · Unix Time · Moon Phase |
| **System** | CPU · Memory · Network · Disk · Battery · Thermal · Uptime |
| **Weather** | Weather · 7-Day Forecast · Sunrise & Sunset · Feels Like / Wind / UV / Rain |
| **Media & controls** | Now Playing (with cover art) · Quick Actions · Volume · Brightness · Wi-Fi |
| **Files & apps** | Folder / Smart Stack · File Shelf · Launchpad |
| **Focus** | Pomodoro · Timer · Stopwatch · Water Tracker · Quick Note · To-Do |
| **Developer** | Git Status · Local Ports · UUID · Password Generator |
| **Plugins** | Bitcoin · Ethereum · Crypto · Currency · Hacker News · Lobsters · DEV · GitHub Stars · npm · Public IP · xkcd · Quote · Random Fact · Cat Fact · ISS Tracker |
| **Fun** | Dice / Coin Flip · Magic 8 Ball |

### 🪟 Windows & switching
- **Window previews** when you hover over Dock icons
- **⌥Tab switcher** that works across Spaces
- **⌃⌥1–9** opens the app in that Dock position, with a small confirmation
- **Alerts** from Limo when an app stops responding, with Force Quit

### 📋 Clipboard & notch
- **History** on ⌥⌘V, filterable by text, links, colors, images and files
- **Pinned slots** on ⌃⌥⌘1–9: paste with one keystroke
- **Copy Peek** shows what you just copied
- **Notch shelf**: hover over the notch for your recent copies
- Anything a password manager marks as concealed is never read or stored

### 🎨 Make it yours
- **Profiles**, with a separate one for the laptop screen and each external display (⌃⌥⌘P cycles them)
- **Styles**: Liquid Glass, Frosted, Solid or Paper, plus corner radius, opacity and accent color
- **Launchpad** (⌃⌥⌘L) with custom icons
- **Live wallpapers**: an animated aurora or your own video
- **Dock replacement mode**: hide the system Dock and let SuperDock take its place. Your Dock settings come back when you turn it off.

### 🔌 Plugins
A plugin is a single JSON file: an `https` URL, plus which values to show from the response. Plugins can't run code. Browse the [community gallery](gallery/) from **Settings → Plugins**, or [write your own](docs/plugins.md).

## Privacy

| SuperDock reads | It never |
|---|---|
| The Dock's position, through Accessibility | reads your prompts or code |
| AI limit percentages and session status | sends analytics or telemetry |
| Clipboard items, stored only on this Mac | stores concealed or password items |
| Weather from Open-Meteo, for your chosen city | asks for an account |

Each permission is only requested when a feature that needs it is turned on. Screen Recording is only for window previews; Automation is only for Quick Actions and Now Playing cover art.

## Performance

Measured on 0.1.2 with 10 widgets on the bar: **0.68 % idle CPU, 101 MB of memory.** Tiles stop updating while the bar is hidden, the screen is locked or the displays are asleep. CPU, memory, network and disk share one sampler, and battery, volume and Now Playing are event-driven. In 1.0, animations run only while something is changing.

---

## For developers

<details>
<summary><b>Build from source</b></summary>

Requires macOS 14+ and Xcode 16+.

```sh
brew install xcodegen swiftlint
xcodegen            # generates SuperDock.xcodeproj from project.yml
open SuperDock.xcodeproj
```

The `.xcodeproj` is generated and isn't checked in. Edit `project.yml` for targets, settings and packages, then re-run `xcodegen`.

During development, launch the binary from a terminal that has Accessibility access (`build/Build/Products/Debug/SuperDock.app/Contents/MacOS/SuperDock`). Ad-hoc signed builds lose their own grant on every rebuild.

Releases: see [docs/releasing.md](docs/releasing.md).
</details>

<details>
<summary><b>Render the UI book</b></summary>

Debug builds can draw every screen offscreen, without touching the Dock:

```sh
xcodebuild -project SuperDock.xcodeproj -scheme SuperDock -configuration Debug -derivedDataPath build/dd build
build/dd/Build/Products/Debug/SuperDock.app/Contents/MacOS/SuperDock -renderGallery build/gallery
```

That writes the tile kit in all seven surface styles (`kit-*.png`) and one sheet per area (`sheet-ai.png`, `sheet-limo.png`, `sheet-onboarding.png`, …). Each area's sheet is defined next to its code in a `*Gallery.swift` file, using the same views the app shows.
</details>

<details>
<summary><b>How it works</b></summary>

**Design system.** Widgets read only `@Environment(\.tile)`: the tile's size, the Dock's scale and the surface tokens for the current style. They never read preferences directly, which is what lets the gallery and the Settings previews draw any widget in any style. See [`SuperDock/DesignSystem/`](SuperDock/DesignSystem/).

**Dock tracking.** The Dock's Accessibility list doesn't post `AXMoved`/`AXResized` (`kAXErrorNotificationUnsupported` on macOS 26). `NativeDockTracker` listens for `AXCreated`/`AXUIElementDestroyed`, cursor proximity (auto-hide only) and screen changes, plus a 1 s safety check. Each of these starts a short burst of reads that follows the Dock's animation.

**Spaces.** The bar lives in its own window-server space ([StickySpace.swift](SuperDock/Dock/StickySpace.swift), private SkyLight calls), the way the Dock does. That keeps one bar that doesn't slide when you switch Spaces.

**Widgets.** A widget is a type conforming to `SuperWidget` ([SuperWidget.swift](SuperDock/Widgets/Core/SuperWidget.swift)), listed in `WidgetRegistry`. Data comes from shared services in `SuperDock/Services/`, which only run while a tile that uses them is on screen. The layout is saved to `~/Library/Application Support/SuperDock/layout.json`.

**AI & agents.** Data sources and formats are in [docs/ai-data-sources.md](docs/ai-data-sources.md). Claude Code's limit percentages come from an opt-in status line bridge (Settings → AI & Agents → Connect Claude Code). Codex works with no setup. Cursor and Antigravity aren't supported yet.

**Windows.** Window lists come from CGWindowList, matched to Accessibility windows through the private `_AXUIElementGetWindow` ([AX.swift](SuperDock/Dock/AX.swift)). Thumbnails use ScreenCaptureKit. Global shortcuts use Carbon `RegisterEventHotKey`.

**Clipboard.** The pasteboard's `changeCount` is checked twice a second. Items marked `org.nspasteboard.ConcealedType`, `TransientType` or `AutoGeneratedType` are skipped before any content is read. The newest 200 unpinned items are kept, along with every pinned one.

**Dock replacement.** Your `autohide` and `autohide-delay` values are saved to `dock-replaced.json` before anything changes. They're restored when the mode is turned off, when SuperDock quits (including on SIGTERM), and on the next launch after a crash.

The full build spec is [SUPERDOCK.md](SUPERDOCK.md).
</details>

## License

MIT. See [LICENSE](LICENSE).
