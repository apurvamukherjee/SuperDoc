# SuperDock redesign — record

Source of truth: the mockups in `design/mockups/`. The old UI is being replaced, not restyled. Services (data layer) stay; every view is rebuilt on a shared design system.

## Mockups

| File | Covers |
|---|---|
| `01-bar-styles-scale-interactions.png` | Bar in 4 styles × light/dark + Paper + Reduce Transparency; vertical bar beside a left Dock; 56pt tight / 120pt roomy; Dock replacement app strip; drag-to-reorder, right-click NSMenu, empty bar with Limo |
| `02-catalog-media-controls-files-productivity-dev-fun-plugins.png` | Now Playing, Quick Actions, Volume, Brightness, Wi-Fi, Stack, Shelf, Launchpad, Pomodoro/Timer/Stopwatch/Water, Note, To-Do, Git, Ports, UUID, Password, Dice/Coin/8 Ball, plugin templates (value, gauge, text, list) |
| `03-catalog-time-system-weather.png` | Clock, Date, World Clock, Analog, Progress, Week, Unix, Moon, Month; CPU, Memory, Network, Disk, Battery, Uptime, Thermal; Weather, 7-Day, Sun, Detail, loading/offline |
| `04-hero-ai-limits-coding-agents.png` | AI Limits (C rings, M, W, L) and Coding Agents (C, M, W, L) with states and motion rules |
| `05-kit-archetypes-states.png` | 10 archetypes × 4 sizes, portrait variants, shared states (loading, empty, offline, needs permission, needs setup) |
| `06-limo-character.png` | Limo (formerly Buddy): pupils/gaze, arms and feet, blink + breath, coral cheek mood light, 12 reactions, alert pills, presence levels, Lively/Calm/Hidden |
| `07-settings-widgets.png` | Settings window: sidebar (General, Placement, Widgets, Plugins, Profiles, Appearance, AI & Agents, Limo, Windows, Clipboard, About), widget gallery with "Your bar" strip, category chips, cards with live preview + size pills + Add |
| `08-around-the-bar-windows-clipboard-notch-popovers.png` | Notch shelf, Copy Peek, ⌃⌥N HUD, menu bar extra, clipboard panel, ⌥Tab switcher, Dock hover preview, Launchpad, Stack and Shelf popovers |

## Decisions

- The mascot is **Limo** (renamed from Buddy). Code, copy and settings use "Limo".
- Widgets read only environment surface tokens, never `@AppStorage`, so one layout renders in every style and in the offline gallery.
- Visual QA runs through a DEBUG gallery renderer (`SuperDock -renderGallery <dir>`) that draws tiles offscreen to PNG, compared against these mockups.
- Paper is a new bar style alongside Liquid Glass, Frosted, Solid dark and Solid light.
- Mockup sources: images 5 and 10 were identical, one kept. The bar sheet is the newer version that says "Limo".
- The foundation's empty-state face is `LimoFace` (sleeping pose only). Before phase 2 the old alert code was renamed to `LimoController` in `SuperDock/Limo/` (its defaults key stays `buddy.alerts` so users keep their setting).
- Before phase 2, `StackPopover`, `ShelfList` and `LaunchpadWidget` moved into their own files under `Widgets/Files/` so the tile owner and the surfaces owner never edit the same file.
- Each phase-2 owner has its own gallery sheet slot (`GallerySheets.<name>` in its own `*Gallery.swift`), rendered as `sheet-<name>.png`.
- Old widget views that clashed with kit names are now `LegacyStatTile`, `LegacyNoteTile`, `LegacyTodoTile`. Phase 2 owners delete them as they rewrite their widgets.

## Phases

1. Foundation: tokens, tile context, archetypes, shared states, tile chrome, motion, gallery renderer. *(done 2026-11-20)*
   - All in `SuperDock/DesignSystem/`: `Tokens`, `TileContext`, `TileChrome`, `TileParts` (slots, meter, ring, chart, chips, buttons), `ArchetypesMeasure` (Stat, Ring, Bars, Chart), `ArchetypesContent` (List, Media, Control, Glyph), `ArchetypesTime` (Clock, Calendar, Note, To-Do), `TileStates`, `Motion`, `GallerySamples` + `GalleryRenderer` (DEBUG only).
   - Render: build Debug, then `build/dd/Build/Products/Debug/SuperDock.app/Contents/MacOS/SuperDock -renderGallery build/gallery`. Writes `kit-<style>.png` for all 7 surface styles (compare with mockup 05), `styles.png` and `scale.png` (compare with mockup 01).
   - The bar itself (`WidgetHost`) does not use the kit yet; that is the bar-chrome owner's job in phase 2.
   **Gate:** the user reviews the foundation's rendered gallery against the mockups before phase 2 starts.
2. Rewrite in parallel, one owner per file set, each in its own worktree off the `redesign` branch *(started 2026-11-20)*: AI, Time, System, Weather, Media & Controls, Files & Productivity, Dev/Fun/Plugins, bar chrome & interactions, Limo, Settings, windows/clipboard/notch/launchpad/popovers.
   - **Limo** (one agent, owns all of it): Buddy → Limo rename, eyes that follow things, arms and feet, blink and breathing, mood cheek, the 12 reactions, alert pills, Lively/Calm/Hidden setting.
   - **Settings**: new window with sidebar, a Limo tab, widget cards with live previews.
   - **Around the bar**: notch shelf, Copy Peek, HUD, menu bar extra, clipboard panel, ⌥Tab switcher, Dock hover preview, Launchpad, Stack and Shelf popovers.
3. Integrate: one build, tests, lint.
4. Adversarial review (fidelity against the mockups, performance and jitter, correctness), fix, final verification.
