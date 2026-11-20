# SuperDock — Design Brief

> A complete brief for redesigning SuperDock's whole UI: the bar, all 57 widgets, and every surface around them.
> Everything below reflects what the app does **today** (v0.1.1). Where the current UI is a placeholder, it says so.

---

## 1. The product in one paragraph

SuperDock is a free, native macOS app (Swift/SwiftUI, macOS 14+) that adds a **companion bar attached to the real macOS Dock**. The bar sits left of, right of, or above the Dock (or beside a vertical Dock), grows and shrinks with it, hides with it, and is filled with **live widget tiles**. Its headline features are **AI usage limits** (Claude Code and Codex, 5-hour and weekly) and a **live coding-agents board** that shows every Claude Code / Codex session as working, needs input, done or idle. Around the bar there are window previews, an ⌥Tab switcher, clipboard history, a notch shelf, a Launchpad, profiles, themes and live wallpapers. No accounts, no analytics, MIT licensed.

**Positioning line:** "Everything the paid dock apps charge for, free. Plus live AI limits and a coding-agents board."

**Who uses it:** Mac power users and developers, most of them running AI coding agents all day. They live in the terminal and the editor and glance at the Dock dozens of times an hour.

---

## 2. What we want from the redesign

The current UI is functional stock SwiftUI: system fonts, SF Symbols, `.quaternary` tile backgrounds, default progress bars. It works and it looks generic.

We want:

- **Modern macOS.** It should feel like it shipped with macOS 26 (Liquid Glass era): native materials, continuous corners, SF Pro / SF Mono, vibrancy, depth. It should never look like a web app.
- **Fun.** Personality and small delights: a mascot (Buddy), playful empty states, satisfying micro-animations, colour used with intent.
- **Impressive at a glance.** Someone screenshots their Dock and people ask what that is. The AI Limits and Agents tiles are the hero shots.
- **Glanceable.** Every tile has to be readable in under a second at Dock size. Beauty never costs legibility.
- **A system, not 57 one-offs.** A small set of tile archetypes (stat, gauge, ring, list, control, media, calendar) that every widget maps onto, so the bar looks like one product.

---

## 3. Hard constraints (read before designing)

### 3.1 Tile geometry — the most important constraint

Tiles are **square per column** and **fill the bar's thickness**, and the bar's thickness **equals the user's Dock height**. The design has to scale.

```
tileSpacing = 6pt                       (gap between tiles, and bar edge padding)
unit        = barThickness − 2 × 6pt    (side of a 1-column tile)
tile width  = columns × unit + (columns − 1) × 6pt
tile inner padding = 6pt on every side
```

| Size | Columns | At a typical 85pt bar (unit = 73pt) | Content area after padding |
|---|---|---|---|
| Compact | 1 | 73 × 73 | 61 × 61 |
| Medium | 2 | 152 × 73 | 140 × 61 |
| Wide | 3 | 231 × 73 | 219 × 61 |
| Large | 4 | 310 × 73 | 298 × 61 |

- Real Dock heights run roughly **50pt (tiny Dock) to 130pt (huge Dock)**. Design at 85pt, then show the tiles at **56pt** and **120pt** too.
- **Height is always one unit.** "Large" means wider, never taller. A Large tile is a 4:1 strip.
- **Vertical bar:** with a left/right Dock, the bar is vertical and tiles stack top to bottom: width = 1 unit, height = columns × unit. Every non-compact tile needs a **portrait variant** (e.g. Medium = 73 × 152).
- Text currently shrinks to fit (down to 50%) instead of truncating. Prefer layouts that don't rely on that.

### 3.2 Bar & theming

| Setting | Values today |
|---|---|
| Bar style | **Liquid Glass** (macOS 26, `NSGlassEffectView`), **Frosted** (`NSVisualEffectView` .hudWindow), **Solid dark** (white 0.12), **Solid light** (white 0.96) |
| Corner radius | User slider, default **18pt** (matches the Dock). Tile radius = bar radius − 6 (min 4) |
| Opacity | 0–100% |
| Accent colour | System accent, or any custom hex. Used as the SwiftUI `tint` for the whole bar |
| Tile backgrounds | On (subtle `.quaternary` fill at 60%) or off (content floats directly on the bar) |
| Reduce Transparency | Forces Glass/Frosted down to solid dark/light |

Every design has to work across **all four styles × light and dark mode × any accent colour**, over any wallpaper. Glass over a bright photo wallpaper is the hardest case. Show it.

### 3.3 Implementation reality

- Has to be buildable in **SwiftUI + AppKit**. Gradients, materials, `Canvas`, shapes, SF Symbols (including multicolor and variable symbols), `TimelineView` and spring animations are all fine. Custom fonts are possible but should be justified; SF Pro Rounded and SF Mono are already available.
- **Performance budget: under 1% idle CPU** with 10 tiles. No constantly running animations. Animate on change, then rest. Respect **Reduce Motion**.
- **Accessibility:** every tile has a VoiceOver label; contrast has to hold on glass. Don't encode status in colour alone (pair it with a symbol or shape).
- **Privacy is a brand value.** Nothing in the UI should suggest the app reads prompts or code (it doesn't; it reads only status and percentages).

### 3.4 Brand assets that already exist

- **App icon** (`design/logo/icon.svg`): a warm cream rounded square (`#FBF9F4 → #E4DFD3`) holding a dark ink "D"-shaped face (`#26282E → #0E0F12`) with two closed happy-arc eyes, a big smile with a coral tongue, and a coral dot (`#FF5A4E`), like a cheek or a notification badge. This character is the seed for **Buddy**.
- **Menu bar icon:** `design/logo/menubar.svg` (template image).
- **README badges:** ink `#26282E` on cream `#FBF9F4`; feature accents orange `#F97316`, blue `#3B82F6`, green `#22C55E`, purple `#A855F7`.
- **Landing page** (`site/index.html`): neutral greys with an indigo accent (`#5B5BD6` light / `#8B8BFF` dark). It doesn't match the icon yet; feel free to unify.

### 3.5 Semantic colours already in use (keep the meaning; restyling is fine)

| Meaning | Colour |
|---|---|
| Agent **working** | blue |
| Agent **needs input** | orange |
| Agent **done** | green |
| Agent **idle** | grey |
| AI limit ≥ 80% | orange (otherwise accent) |
| AI ring order (outer → inner) | orange, blue, green |
| Thermal | Cool green · Warm yellow · Hot orange · Critical red |
| UV ≥ 6 orange, ≥ 8 red · Rain ≥ 60% blue · Git dirty orange · Water cyan | |

---

## 4. Surfaces to design

### 4.1 The bar (primary surface)
- Horizontal, beside a bottom Dock; vertical beside a side Dock; above the Dock.
- Gap to the Dock is configurable (default 8pt). It should look like a **sibling** of the Dock, not a foreign object.
- **Empty state:** a single "+" tile today. Make it inviting.
- **Interactions:** drag a tile to reorder (needs a lift and drop affordance); right-click a tile for a menu: Size ▸ (Compact/Medium/Wide/Large), Widget Settings…, Add Widget…, Remove.
- **Dock replacement mode:** the system Dock hides and the bar starts with SuperDock's own **app strip** (pinned and running app icons with running dots, then a divider, then tiles). Design the app strip so it feels like a Dock.

### 4.2 Buddy (mascot + alert pill) — placeholder today, a big opportunity
- **Today:** a capsule of `.regularMaterial` above the bar for 5s: an SF Symbol (`hand.raised.fill` orange / `checkmark.seal.fill` green) and text such as *"superdock needs your input (Claude Code)"* or *"api is done (Codex)"*. Tap to dismiss. Some alerts carry a button (e.g. **Force Quit** for a frozen app).
- **Wanted:** Buddy as a real character derived from the app icon's face. Expressions for: *agent done* (celebrate), *needs input* (raised hand / waving), *frozen app* (worried), *idle / nothing running* (sleeping), *hydration nudge*, *connect Claude* (curious). It should pop up and spring out of the bar, then tuck back in. Keep it small: at most about 1.5× the bar's thickness.
- When the bar is hidden, the pill appears at the bottom centre of the screen.

### 4.3 Widget picker (Settings → Widgets)
Categories: AI & Agents · Time · System · Weather · Media · Controls · Files & Apps · Productivity · Developer · Finance · News & Reading · Fun · Community Plugins. Each widget has a name, an SF Symbol, supported sizes and a "uses network" flag. Search. Wanted: **live previews** of each tile at each size, an "add to bar" interaction, and the current layout shown as a mini bar.

### 4.4 Settings window — 10 tabs
General · Placement · Widgets · Plugins · Profiles · Appearance · Windows · Clipboard · AI · About.
- **Placement:** left/right/above, gap. A live diagram of Dock + bar would be ideal.
- **Appearance:** style, corner radius, opacity, accent, tile backgrounds, live wallpaper (animated aurora or the user's own video). Needs a live preview.
- **AI:** "Connect Claude Code" (installs a status-line bridge), Codex status, Buddy alerts toggle.
- **Plugins:** installed list, load errors, Browse Gallery, Open Plugins Folder, Reload.
- **Profiles:** named layouts, one per display (laptop vs external), ⌃⌥⌘P cycles.
- **About:** version, update check, licence, GitHub.

### 4.5 Onboarding (4 steps)
Welcome → choose placement → grant **Accessibility** (required to attach to the Dock; explain why, with the System Settings handoff) → pick starter widgets. This is the first impression, so make it delightful and introduce Buddy here.

### 4.6 Windows
- **Dock hover previews:** hover a native Dock icon and a panel above it shows live window thumbnails (ScreenCaptureKit) with per-window close / minimize / quit.
- **⌥Tab switcher:** a centred panel of window thumbnails across Spaces. Tab / ⇧Tab cycles, release to focus.
- **⌃⌥1–9** opens the app in that Dock position (a small HUD confirmation is optional).
- **Frozen-app alert:** an app stopped responding, offer Force Quit (via the Buddy pill).

### 4.7 Clipboard & notch
- **History panel (⌥⌘V):** a searchable list with filter chips: All · Text · Links · Colors · Images · Files. Rows show a type icon, preview, source app and age. Hex colours show a swatch, images a thumbnail. Pinned slots 1–9 (⌃⌥⌘1–9).
- **Copy Peek:** a tiny transient preview right after ⌘C.
- **Notch shelf:** hover the MacBook notch and recent copies fan out beneath it. It should feel like the notch is opening.
- Concealed/password items are never stored. A subtle "protected" affordance is welcome.

### 4.8 Launchpad (⌃⌥⌘L)
A full-screen app grid with search and custom icons. Opened from a compact Launchpad tile.

### 4.9 Popovers from tiles
- **Folder / Smart Stack popover:** title, then a grid (48pt icons with 2-line names) or list (20pt icons). Sources: Downloads, Screenshots, Recent Files, any folder. Empty state: "Nothing here yet".
- **File Shelf popover:** "Shelf" title, "Drag files out to use them.", a list of files with remove buttons.
- **Widget settings sheets** (per widget; see §5).

### 4.10 Peripheral
- Menu bar extra (icon + menu).
- Live wallpaper (animated aurora).
- DMG background, landing page, README hero screenshots (the bar next to a Dock).

---

## 5. Every widget

**42 native widgets + 15 built-in JSON plugins = 57.** Sizes: C = compact, M = medium, W = wide, L = large. "Today" describes the current rendering. The design column is a prompt, not a rule.

### 5.1 AI & Agents — hero widgets

| Widget | Sizes | Data | Today | Design goal |
|---|---|---|---|---|
| **AI Limits** `ai.limits` | C M W L | Per provider (Claude, Codex) and per window (5-hour, weekly): % used, reset time. Settings: providers (all / Claude / Codex), show used vs remaining | **C:** up to 3 concentric rings (orange, blue, green, 5pt strokes). **M:** 2 rows of `label · bar · %`. **W/L:** up to 4 rows plus a reset countdown ("2h 14m"). Unconnected: link icon + "Connect Claude". No data: empty gauge symbol | The signature tile. Think Apple Watch activity rings meets fuel gauge. Make danger (≥80%) feel urgent but calm, and the countdown legible. Provider identity without logos (we can't use brand marks): colour + monogram/glyph |
| **Coding Agents** `ai.agents` | C M W L | Sessions: project folder name, tool (Claude Code / Codex), status (working / needs input / done / idle) | **C:** one coloured dot + count per status. **M:** 3 rows `● project  Tool`. **W/L:** a grid of 2–3 columns, "+N more". Empty: `moon.zzz` | Mission-control board. "Working" should feel alive (subtle pulse or shimmer, animated only while working). "Needs input" must catch the eye from across the screen. Empty state = sleeping Buddy |

### 5.2 Time

| Widget | Sizes | Today | Design goal |
|---|---|---|---|
| Clock `time.clock` | C M | Time (optional seconds), weekday below | Big, beautiful numerals. Consider SF Pro Rounded / thin weights |
| Date `time.date` | C M | C: "THU" + big day number. M: weekday + "19 November" | Classic tear-off calendar feel |
| World Clock `time.worldClock` | C M | City + time for a chosen time zone | Day/night tint per city |
| Analog Clock `time.analog` | C | `Canvas` face with hands | Beautiful watch face, smooth second hand optional |
| Day/Week/Month/Year Progress `time.progress` | C M | Period label + big %, M adds a bar | Filling glass / hourglass metaphor |
| Week Number `time.weekNumber` | C | "W47" | |
| Unix Time `time.unix` | M | Epoch seconds, monospaced | Hacker aesthetic, SF Mono |
| Moon Phase `time.moon` | C M | SF Symbol moon, M adds the phase name | Rendered moon with real illumination |
| Month Calendar `time.monthCalendar` | W L | Mini month grid, 8pt digits, today bold | Hard at 61pt tall: 6 rows × 7 cols. Get creative (e.g. horizontal week strip on W) |

### 5.3 System

| Widget | Sizes | Today | Design goal |
|---|---|---|---|
| CPU `system.cpu` | C M W | "CPU" + %; M/W add a sparkline | Live sparkline/area chart, colour shifting with load |
| Memory `system.memory` | C M | Stat tile: label, value, detail | Memory-pressure colour |
| Network `system.network` | C M | ↑ / ↓ rates, monospaced | Two-tone up/down micro-graph |
| Disk `system.disk` | C M | Free / used | Capacity ring or bar |
| Battery `system.battery` | C M | Battery symbol + %, M adds detail (charging, time left). Desktop: plug icon | Charging animation, low-battery state |
| Uptime `system.uptime` | C M | "3d 4h" | |
| Thermal `system.thermal` | C | Thermometer + Cool/Warm/Hot/Critical | Fun: Buddy sweating at Hot? |

All system stats share one sampler. Shared archetype: **Stat tile** (label · big value · detail).

### 5.4 Weather (Open-Meteo, user picks a city and °C/°F)

| Widget | Sizes | Today | Design goal |
|---|---|---|---|
| Weather `weather.current` | C M W | Multicolor SF condition symbol + temp; M/W add city and H/L | Sky-gradient background matched to condition and time of day |
| 7-Day Forecast `weather.sevenDay` | W L | Per day: weekday, symbol, high/low | Temperature range bars like iOS Weather |
| Sunrise & Sunset `weather.sun` | C M | Times | Sun arc with current position |
| Weather Detail `weather.detail` | C | One metric: Feels Like / Wind / UV / Rain Soon | Per-metric visual (wind arrow, UV scale) |
| States | | Loading spinner; `exclamationmark.icloud` on error | |

### 5.5 Media & Controls

| Widget | Sizes | Today | Design goal |
|---|---|---|---|
| Now Playing `media.nowPlaying` | M W | Cover art (10pt rounded corners, app icon fallback) + play/pause, next; W adds previous. Title/artist only in the tooltip. "Nothing playing" | Album-art-tinted background, tiny progress, optional waveform |
| Quick Actions `controls.quickActions` | C M W | Icon buttons: Lock, Sleep Displays, Screenshot, Empty Trash, Show/Hide Hidden Files, Toggle Dark Mode (user picks which) | Control Center button style |
| Volume `controls.volume` | C M W | Mute button + slider | Control Center slider |
| Brightness `controls.brightness` | M W | Sun icon + slider; "Not adjustable" on external displays | Control Center slider |
| Wi-Fi `controls.wifi` | C | `wifi` / `wifi.slash` toggle | Control Center toggle |

### 5.6 Files & Apps

| Widget | Sizes | Today | Design goal |
|---|---|---|---|
| Folder / Smart Stack `files.stack` | C M | Stack icon (M adds source name); click opens the popover (grid/list) | Fanned stack of the actual newest file thumbnails |
| File Shelf `files.shelf` | C M | Tray icon + count badge; drop files on it; click opens the list | Visible drop-target state, files "landing" |
| Launchpad `files.launchpad` | C | Grid symbol | |

### 5.7 Productivity

| Widget | Sizes | Today | Design goal |
|---|---|---|---|
| Pomodoro `productivity.pomodoro` | C | Ring countdown + time, "Tap to stop" | Tomato-warm progress ring, a celebration on completion |
| Timer `productivity.timer` | C | Same countdown ring | |
| Stopwatch `productivity.stopwatch` | C M | mm:ss.t, start/stop/reset | |
| Water Tracker `productivity.water` | C | Drop icon (fills at goal) + "3/8", tap +1 | Liquid filling up, playful |
| Quick Note `productivity.note` | M W L | Inline plain text field, "Note…" | Sticky-note warmth |
| To-Do `productivity.todo` | M W L | Circle-bullet list + add field | Satisfying check-off animation |

### 5.8 Developer

| Widget | Sizes | Today | Design goal |
|---|---|---|---|
| Git Status `dev.gitStatus` | M W | Branch label + "3 changed · ↑1" (orange if dirty). States: choose repo, not a repo, loading | Terminal-chic |
| Local Ports `dev.ports` | M W | List ":3000  node" | |
| UUID `dev.uuid` | C M | Tap → generates + copies, shows "Copied ✓" | Copy confirmation micro-animation |
| Password Generator `dev.password` | C M | Same tap-to-copy pattern | |

### 5.9 Fun

| Widget | Sizes | Today | Design goal |
|---|---|---|---|
| Dice / Coin Flip `fun.dice` | C | Icon + "Roll"/"Flip" → result | Real 3D-ish roll / flip animation |
| Magic 8 Ball `fun.eightBall` | C M | "Ask, then tap" → answer text | The triangle-in-the-window reveal |

### 5.10 Plugins (declarative JSON, 4 templates)

Plugins can't draw. They pick one of four templates, so **design these 4 templates well** and every plugin looks good:

| Template | Content |
|---|---|
| `value` | label + big value (+ optional subtitle), formats: number, currency, percent… |
| `text` | label + a short paragraph (quotes, facts) |
| `list` | label + list of titles, each opens a link (HN, Lobsters, DEV) |
| `gauge` | label + value on a gauge |

Built-in plugins: Bitcoin · Ethereum · Crypto · Currency · Hacker News · Lobsters · DEV · GitHub Stars · npm downloads · Public IP · xkcd · Quote · Random Fact · Cat Fact · ISS Tracker. Plugins provide an SF Symbol and can open a URL on click.

---

## 6. Tile archetypes to define

Map all 57 onto a small kit. Design each archetype at C / M / W / L, horizontal and vertical, in all four bar styles:

1. **Stat:** label · hero value · detail (CPU, Memory, Disk, Uptime, plugin `value`)
2. **Ring / gauge:** one or more concentric arcs (AI Limits compact, Pomodoro, Timer, Disk, plugin `gauge`)
3. **Bars:** labelled progress rows with trailing value/countdown (AI Limits M–L, Progress)
4. **Chart:** sparkline / area (CPU, Network)
5. **List:** dot or icon + text rows, "+N more" (Agents, Ports, To-Do, plugin `list`)
6. **Media:** artwork + transport controls (Now Playing)
7. **Control:** button / toggle / slider (Quick Actions, Volume, Brightness, Wi-Fi)
8. **Glyph:** one big symbol + short caption (Moon, Thermal, Wi-Fi, Launchpad, Stack, Dice)
9. **Calendar / time** (Clock, Date, Month, Analog)
10. **Input:** inline text (Note, To-Do add field)

Plus shared **states** for every tile: loading · empty · error/offline · needs permission · needs setup (e.g. "Connect Claude", "Choose a repository").

---

## 7. Deliverables

1. **Design language:** colour tokens (light/dark, per bar style), type scale tuned for 61pt-tall content, corner radii, spacing, materials, elevation, motion curves.
2. **Hero mockups:**
   - Full bar beside a bottom Dock on a colourful wallpaper, Liquid Glass, dark mode: AI Limits (W), Coding Agents (W), Now Playing (M), Weather (M), Clock (C), CPU (M).
   - The same bar in Solid light.
   - A vertical bar beside a left Dock.
   - The bar at a tiny Dock (56pt) and a huge Dock (120pt).
3. **Every widget** at every supported size (§5), including empty/loading/error states.
4. **Buddy:** character sheet + the alert pill in each state + pop-out animation storyboard.
5. **Widget picker, Settings (all 10 tabs), Onboarding (4 steps).**
6. **Clipboard panel, Copy Peek, Notch shelf, ⌥Tab switcher, Dock hover preview, Launchpad, Stack/Shelf popovers.**
7. **Motion notes:** tile reorder, size change, agent "working" pulse, needs-input attention cue, Buddy pop, Copy Peek, notch fan-out. All with a Reduce Motion fallback.
8. **SwiftUI handoff notes:** which materials, SF Symbols, fonts and gradients, so each piece maps to native APIs.

---

## 8. Mood & references

- **Yes:** macOS 26 Liquid Glass, Control Center, Apple Watch faces and activity rings, iOS 18 widgets, Dynamic Island's playful spring motion, Raycast's polish, Arc's warmth, Things 3's delight, the app icon's cream-and-ink friendliness.
- **No:** Electron/web-dashboard look, neon cyberpunk overload, dense data-terminal clutter, skeuomorphic chrome, copying Dockspace (no reuse of its names, mascot or visual identity), competitor brand logos (Claude, OpenAI) inside tiles.
- **Tone of copy:** short, friendly, plain. "superdock is done", not "Task execution completed successfully".

---

## 9. Open design questions (pick a direction and say why)

1. **Default look:** stay native (glass, system accent) or push a distinct SuperDock identity (the cream / ink / coral from the icon) as the default theme?
2. **Buddy:** name, and how much personality before it gets annoying for someone who stares at it all day?
3. **Tile backgrounds:** separated cards vs content floating on one continuous glass bar?
4. **Colour per category** (AI = orange, system = blue…) or one accent with semantic colours only?
