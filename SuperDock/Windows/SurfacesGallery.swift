#if DEBUG
import SwiftUI

extension GallerySheets {
    /// Surfaces around the bar.
    /// Compare with design/mockups/08-around-the-bar-windows-clipboard-notch-popovers.png.
    @MainActor static var surfaces: AnyView? {
        SurfaceFixtures.registerClipImages()
        return AnyView(VStack(spacing: 0) {
            SurfacesSheet(style: .glassDark)
            SurfacesSheet(style: .glassLight)
        })
    }
}

/// Every surface in one appearance. Materials are drawn as token fills (`surfaceSnapshot`), since ImageRenderer
/// can't draw NSVisualEffectView / NSGlassEffectView, and the menu bar extra is a facsimile of its NSMenu.
private struct SurfacesSheet: View {
    let style: SurfaceStyle

    private var ink: Color { style.isDark ? .white : Palette.ink }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("AROUND THE BAR · \(style.rawValue.uppercased())")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(ink.opacity(0.6))
            HStack(alignment: .top, spacing: 28) {
                section("Notch shelf") { notch }
                VStack(alignment: .leading, spacing: 28) {
                    section("Copy Peek · after ⌘C") {
                        VStack(alignment: .leading, spacing: 10) {
                            PeekView(item: SurfaceFixtures.clips[0])
                            PeekView(item: SurfaceFixtures.clips[2])
                            PeekView(item: nil)
                        }
                    }
                    HStack(alignment: .top, spacing: 28) {
                        section("⌃⌥3 HUD") {
                            DockNumberHUD(number: 3, name: "Terminal", icon: SurfaceFixtures.appIcon("Terminal"))
                        }
                        section("Menu bar extra") { MenuFacsimile() }
                    }
                }
            }
            HStack(alignment: .top, spacing: 28) {
                section("Clipboard") {
                    let model = ClipboardPanel.Model(items: { SurfaceFixtures.clips }, protectedAt: { SurfaceFixtures.now })
                    ClipboardHistoryView(model: model, now: SurfaceFixtures.now) { _ in }
                }
                VStack(alignment: .leading, spacing: 28) {
                    section("⌥Tab switcher · all Spaces") { switcher }
                    section("Dock hover preview") {
                        PreviewsView(appName: "Safari", windows: SurfaceFixtures.previewWindows, frozen: false,
                                     fixtureImages: SurfaceFixtures.windowImages, onPick: { _ in }, onQuit: {}, onForceQuit: {})
                    }
                    section("Dock hover preview · not responding") {
                        PreviewsView(appName: "Safari", windows: Array(SurfaceFixtures.previewWindows.prefix(1)), frozen: true,
                                     fixtureImages: SurfaceFixtures.windowImages, onPick: { _ in }, onQuit: {}, onForceQuit: {})
                    }
                }
            }
            HStack(alignment: .top, spacing: 28) {
                if style.isDark {
                    section("Launchpad · ⌃⌥⌘L") {
                        LaunchpadView(model: SurfaceFixtures.launchpadModel, size: CGSize(width: 980, height: 560),
                                      icon: { SurfaceFixtures.appIcon($0.deletingPathExtension().lastPathComponent) },
                                      onPick: { _ in })
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
                section("Stack popover · grid / list / empty") { stacks }
                section("Shelf popover") {
                    ShelfListView(files: SurfaceFixtures.shelfFiles(), onRemove: { _ in }, onClear: {}, onDrop: { _ in }).popoverBackdrop()
                }
            }
        }
        .padding(60)
        .frame(width: 2100, alignment: .leading)
        .background(galleryWallpaper(style))
        .environment(\.surfaceSnapshot, style)
        .environment(\.colorScheme, style.isDark ? .dark : .light)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased()).font(.system(size: 12, weight: .semibold)).tracking(1.2).foregroundStyle(ink.opacity(0.6))
            content()
        }
    }

    private var notch: some View {
        ZStack(alignment: .top) {
            HStack {
                Text("Terminal").fontWeight(.bold)
                Text("Shell")
                Text("Edit")
                Spacer()
                Text("10:55 PM")
            }
            .font(.system(size: 13))
            .foregroundStyle(ink)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(ink.opacity(0.08))
            NotchPocket(items: Array(SurfaceFixtures.clips.prefix(5)), notchWidth: 200, notchHeight: 32,
                        now: SurfaceFixtures.now) { _ in }
        }
        .frame(width: 880, height: 300, alignment: .top)
        .background(galleryWallpaper(style).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var switcher: some View {
        let model = WindowSwitcher.Model()
        model.windows = SurfaceFixtures.switcherWindows
        model.selection = 1
        return SwitcherView(model: model, frozen: [], fixtureImages: SurfaceFixtures.windowImages) { _ in }
    }

    private var stacks: some View {
        VStack(alignment: .leading, spacing: 16) {
            StackPopover(title: "Downloads", items: SurfaceFixtures.stackItems, style: .grid, folder: URL(fileURLWithPath: "/tmp"))
                .popoverBackdrop()
            HStack(alignment: .top, spacing: 16) {
                StackPopover(title: "Recent Files", items: Array(SurfaceFixtures.stackItems.prefix(4)), style: .list, folder: nil)
                    .popoverBackdrop()
                StackPopover(title: "Screenshots", items: [], style: .grid, folder: nil).popoverBackdrop()
            }
        }
    }
}

private extension View {
    /// Stands in for the NSPopover chrome the tile owner presents these in.
    func popoverBackdrop() -> some View {
        fixedSize().surfacePanel(radius: 16).surfaceContext()
    }
}

/// A drawing of the menu bar extra's NSMenu: the real one can't be rendered offscreen.
private struct MenuFacsimile: View {
    var body: some View {
        MenuRows().surfaceContext()
    }
}

private struct MenuRows: View {
    @Environment(\.tile) private var tile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(SurfaceFixtures.menuTitle).font(.system(size: 11, weight: .semibold)).foregroundStyle(tile.surface.secondary)
                .padding(.vertical, 4)
            row("Profile: Laptop", trailing: "›")
            row("Launchpad", trailing: nil)
            divider
            row("Settings…", trailing: "⌘,")
            row("Check for Updates…", trailing: nil)
            divider
            row("Quit SuperDock", trailing: "⌘Q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 280)
        .surfacePanel(radius: 12)
    }

    private var divider: some View {
        Rectangle().fill(tile.surface.divider).frame(height: 1).padding(.vertical, 5)
    }

    private func row(_ title: String, trailing: String?) -> some View {
        HStack {
            Text(title).foregroundStyle(tile.surface.primary)
            Spacer()
            if let trailing { Text(trailing).foregroundStyle(tile.surface.tertiary) }
        }
        .font(.system(size: 13))
        .padding(.vertical, 3)
    }
}
#endif
