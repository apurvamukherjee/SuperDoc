#if DEBUG
import AppKit
import SwiftUI

extension GallerySheets {
    /// Files & Apps and Productivity tiles.
    /// Compare with design/mockups/02-catalog-media-controls-files-productivity-dev-fun-plugins.png.
    static var filesProductivity: AnyView? { AnyView(FilesProductivitySheet()) }
}

@MainActor
private enum FPFixtures {
    static let thumbs = [
        thumb(0x7AA8FF, 0x4A6CF0, lines: true),
        thumb(0xFFC27A, 0xF0843C, lines: false),
        thumb(0xE9ECF2, 0xB9C0CC, lines: false)
    ]
    static let shelfThumbs = [thumb(0xFFC58A, 0xF59A4C, lines: false), thumb(0xEEF0F4, 0xC9CFD9, lines: false),
                              thumb(0x86A8FF, 0x4F70F0, lines: false)]

    static let todos = [TodoItem(title: "Rotate API keys"), TodoItem(title: "Review PR #212"),
                        TodoItem(title: "Book dentist"), TodoItem(title: "Reply to design review")]
    static let todosChecked = [TodoItem(title: "Reply to design review", isDone: true), TodoItem(title: "Rotate API keys")]
    static let todosLarge = [TodoItem(title: "Design review", isDone: true), TodoItem(title: "Rotate API keys"),
                             TodoItem(title: "Review PR #212"), TodoItem(title: "Book dentist")]
    static let noteShort = "Ship the onboarding copy before Fri"
    static let noteLong = "Ship the onboarding copy before Fri. Ask about the notch shelf hover delay (feels slow at 400ms)."

    /// A stand-in file preview: a gradient card, optionally with document lines.
    private static func thumb(_ top: UInt32, _ bottom: UInt32, lines: Bool) -> FileThumbnail {
        let image = NSImage(size: NSSize(width: 64, height: 76), flipped: true) { rect in
            NSGradient(starting: NSColor(Color(rgb: top)), ending: NSColor(Color(rgb: bottom)))?.draw(in: rect, angle: 90)
            if lines {
                NSColor.white.withAlphaComponent(0.85).setFill()
                for (top, width) in [(14.0, 40.0), (26.0, 26.0)] {
                    NSBezierPath(roundedRect: NSRect(x: 10, y: top, width: width, height: 6), xRadius: 3, yRadius: 3).fill()
                }
            }
            return true
        }
        return FileThumbnail(id: URL(fileURLWithPath: "/gallery/\(top)"), image: Image(nsImage: image))
    }
}

private struct FilesProductivitySheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach([SurfaceStyle.glassDark, .solidLight, .paper], id: \.self) { StylePanel(style: $0) }
            ScalePanel()
        }
    }
}

private struct Caption: View {
    let text: String
    let style: SurfaceStyle
    var size: CGFloat = 13
    var weight = Font.Weight.regular

    var body: some View {
        Text(text).font(.system(size: size, weight: weight))
            .foregroundStyle(style.isDark ? Color.white.opacity(0.75) : Palette.ink.opacity(0.75))
    }
}

/// Everything at 85 pt in one surface style: every size and state, plus the vertical-bar variants.
private struct StylePanel: View {
    let style: SurfaceStyle
    var unit: CGFloat = 73

    private var surface: SurfaceTokens { SurfaceTokens(style) }

    private func ctx(_ size: TileSize, portrait: Bool = false) -> TileContext {
        TileContext(unit: unit, size: size, isPortrait: portrait, surface: surface)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Caption(text: "FILES & PRODUCTIVITY · \(style.rawValue.uppercased()) · 85 PT", style: style, size: 12, weight: .semibold)
            row("Files & Apps · Stack C · M — Shelf C · M · drop target — Launchpad C") { files }
            row("States · stack loading · empty · needs permission · shelf empty") { fileStates }
            row("Productivity · Pomodoro idle · running · done — Timer idle · running — Stopwatch C · M — Water") { productivity }
            row("Stopwatch paused · lap — Water empty · goal") { productivityStates }
            row("Quick Note M · W · L") { notes }
            row("To-Do M · W · L (check-off pops, then fades out) · empty") { todos }
            row("Portrait (vertical bar) · M") { portraits }
        }
        .padding(48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(galleryWallpaper(style))
    }

    private func row(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Caption(text: title, style: style, weight: .semibold)
            GalleryBar(surface: surface) { content() }
        }
    }

    @ViewBuilder private var files: some View {
        StackFace(title: "Downloads", thumbnails: FPFixtures.thumbs, count: 12).asTile(ctx(.compact))
        StackFace(title: "Downloads", thumbnails: FPFixtures.thumbs, count: 12, newest: "Newest 2m ago").asTile(ctx(.medium))
        ShelfFace(count: 3, thumbnails: FPFixtures.shelfThumbs, isTargeted: false).asTile(ctx(.compact))
        ShelfFace(count: 3, thumbnails: FPFixtures.shelfThumbs, isTargeted: false).asTile(ctx(.medium))
        ShelfFace(count: 3, thumbnails: FPFixtures.shelfThumbs, isTargeted: true).asTile(ctx(.compact))
        ShelfFace(count: 3, thumbnails: FPFixtures.shelfThumbs, isTargeted: true).asTile(ctx(.medium))
        LaunchpadFace().asTile(ctx(.compact))
    }

    @ViewBuilder private var fileStates: some View {
        TileStateView(state: .loading).asTile(ctx(.compact))
        StackFace(title: "Downloads", thumbnails: [], count: 4, newest: "Newest just now").asTile(ctx(.medium))
        TileStateView(state: .empty(title: "Screenshots", detail: "Nothing here yet")).asTile(ctx(.compact))
        TileStateView(state: .empty(title: "Screenshots", detail: "Nothing here yet")).asTile(ctx(.medium))
        TileStateView(state: .needsPermission(detail: "Open Settings →")).asTile(ctx(.compact))
        TileStateView(state: .needsPermission(detail: "Open Settings →")).asTile(ctx(.medium))
        ShelfFace(count: 0, thumbnails: [], isTargeted: false).asTile(ctx(.compact))
        ShelfFace(count: 0, thumbnails: [], isTargeted: false).asTile(ctx(.medium))
    }

    @ViewBuilder private var productivity: some View {
        CountdownFace(label: "Focus", total: 1500, phase: .idle, tint: Palette.coral).asTile(ctx(.compact))
        CountdownFace(label: "Focus", total: 1500, phase: .running(remaining: 1104), tint: Palette.coral).asTile(ctx(.compact))
        CountdownFace(label: "Focus", total: 1500, phase: .done, tint: Palette.coral).asTile(ctx(.compact))
        CountdownFace(label: "Timer", total: 600, phase: .idle, tint: Palette.progress).asTile(ctx(.compact))
        CountdownFace(label: "Timer", total: 600, phase: .running(remaining: 270), tint: Palette.progress).asTile(ctx(.compact))
        StopwatchFace(elapsed: 84.6, isRunning: true).asTile(ctx(.compact))
        StopwatchFace(elapsed: 84.6, isRunning: true).asTile(ctx(.medium))
        WaterFace(glasses: 3, goal: 8).asTile(ctx(.compact))
    }

    @ViewBuilder private var productivityStates: some View {
        StopwatchFace(elapsed: 0, isRunning: false).asTile(ctx(.compact))
        StopwatchFace(elapsed: 84.6, isRunning: false).asTile(ctx(.compact))
        StopwatchFace(elapsed: 0, isRunning: false).asTile(ctx(.medium))
        StopwatchFace(elapsed: 126.2, isRunning: true, lastLap: "Lap 2 · 0:41.3").asTile(ctx(.medium))
        StopwatchFace(elapsed: 3723, isRunning: false).asTile(ctx(.medium))
        WaterFace(glasses: 0, goal: 8).asTile(ctx(.compact))
        WaterFace(glasses: 6, goal: 8).asTile(ctx(.compact))
        WaterFace(glasses: 8, goal: 8).asTile(ctx(.compact))
    }

    @ViewBuilder private var notes: some View {
        NoteTile(text: .constant(FPFixtures.noteShort)).asTile(ctx(.medium))
        NoteTile(text: .constant(FPFixtures.noteShort)).asTile(ctx(.wide))
        NoteTile(text: .constant(FPFixtures.noteLong), edited: "4m ago").asTile(ctx(.large))
        NoteTile(text: .constant("")).asTile(ctx(.medium))
    }

    @ViewBuilder private var todos: some View {
        TodoListTile(items: FPFixtures.todos).asTile(ctx(.medium))
        TodoListTile(items: FPFixtures.todosChecked).asTile(ctx(.wide))
        TodoListTile(items: FPFixtures.todosLarge).asTile(ctx(.large))
        TodoListTile(items: []).asTile(ctx(.medium))
    }

    @ViewBuilder private var portraits: some View {
        HStack(alignment: .top, spacing: TileContext.spacing) {
            StackFace(title: "Downloads", thumbnails: FPFixtures.thumbs, count: 12).asTile(ctx(.medium, portrait: true))
            ShelfFace(count: 3, thumbnails: FPFixtures.shelfThumbs, isTargeted: false).asTile(ctx(.medium, portrait: true))
            StopwatchFace(elapsed: 84.6, isRunning: true).asTile(ctx(.medium, portrait: true))
            NoteTile(text: .constant(FPFixtures.noteShort)).asTile(ctx(.medium, portrait: true))
            TodoListTile(items: FPFixtures.todos).asTile(ctx(.medium, portrait: true))
            TodoListTile(items: FPFixtures.todos).asTile(ctx(.large, portrait: true))
        }
    }
}

/// A tiny (56 pt) and a huge (120 pt) Dock, glass dark.
private struct ScalePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Caption(text: "SCALE · 56 PT TIGHT · 120 PT ROOMY", style: .glassDark, size: 12, weight: .semibold)
            ForEach([56, 120], id: \.self) { bar in
                let unit = CGFloat(bar) - 2 * TileContext.spacing
                let ctx = { (size: TileSize) in TileContext(unit: unit, size: size, surface: SurfaceTokens(.glassDark)) }
                GalleryBar(surface: SurfaceTokens(.glassDark)) {
                    StackFace(title: "Downloads", thumbnails: FPFixtures.thumbs, count: 12).asTile(ctx(.compact))
                    StackFace(title: "Downloads", thumbnails: FPFixtures.thumbs, count: 12, newest: "Newest 2m ago")
                        .asTile(ctx(.medium))
                    ShelfFace(count: 3, thumbnails: FPFixtures.shelfThumbs, isTargeted: false).asTile(ctx(.compact))
                    ShelfFace(count: 3, thumbnails: FPFixtures.shelfThumbs, isTargeted: false).asTile(ctx(.medium))
                    LaunchpadFace().asTile(ctx(.compact))
                    CountdownFace(label: "Focus", total: 1500, phase: .running(remaining: 1104), tint: Palette.coral)
                        .asTile(ctx(.compact))
                    CountdownFace(label: "Focus", total: 1500, phase: .done, tint: Palette.coral).asTile(ctx(.compact))
                    StopwatchFace(elapsed: 84.6, isRunning: true).asTile(ctx(.compact))
                    StopwatchFace(elapsed: 84.6, isRunning: true).asTile(ctx(.medium))
                    WaterFace(glasses: 3, goal: 8).asTile(ctx(.compact))
                    NoteTile(text: .constant(FPFixtures.noteShort)).asTile(ctx(.medium))
                    TodoListTile(items: FPFixtures.todosChecked).asTile(ctx(.wide))
                }
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(galleryWallpaper(.glassDark))
    }
}
#endif
