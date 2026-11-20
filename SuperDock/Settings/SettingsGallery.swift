#if DEBUG
import AppKit
import SwiftUI

extension GallerySheets {
    /// Settings window and widget gallery: every pane, light and dark.
    /// Compare with design/mockups/07-settings-widgets.png.
    @MainActor static var settings: AnyView? {
        // ImageRenderer can't draw AppKit-backed controls (lists, fields, switches), so each pane is drawn by a real
        // window offscreen and the sheet lays those bitmaps out.
        let shots = [false, true].flatMap { dark in
            SettingsTab.allCases.map { SettingsShot(tab: $0, dark: dark, image: SettingsSnapshot.image(tab: $0, dark: dark)) }
                + [SettingsShot(tab: .widgets, dark: dark, selected: true,
                                image: SettingsSnapshot.image(tab: .widgets, dark: dark, selected: true))]
        }
        SettingsSnapshot.writeEach(shots)
        return AnyView(SettingsSheet(shots: shots))
    }
}

private struct SettingsShot: Identifiable {
    let tab: SettingsTab
    let dark: Bool
    var selected = false
    let image: NSImage?
    var id: String { "\(tab.rawValue)\(selected ? "-tile" : "")-\(dark ? "dark" : "light")" }
}

@MainActor
private enum SettingsSnapshot {
    static func image(tab: SettingsTab, dark: Bool, selected: Bool = false) -> NSImage? {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 940, height: 660), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let host = NSHostingView(rootView: GalleryWindow(tab: tab, selected: selected))
        window.contentView = host
        // Let SwiftUI lay out, load the lazy grid and settle any first-frame state before the bitmap is taken.
        RunLoop.main.run(until: .now + 0.6)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        let image = NSImage(size: host.bounds.size)
        image.addRepresentation(rep)
        return image
    }

    /// One PNG per pane next to the sheet, for close comparison with the mockup.
    static func writeEach(_ shots: [SettingsShot]) {
        guard let path = UserDefaults.standard.string(forKey: "renderGallery") else { return }
        let directory = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        for shot in shots {
            guard let rep = shot.image?.representations.first as? NSBitmapImageRep,
                  let png = rep.representation(using: .png, properties: [:]) else { continue }
            do {
                try png.write(to: directory.appending(path: "settings-\(shot.id).png"))
            } catch {
                FileHandle.standardError.write(Data("settings gallery: \(error)\n".utf8))
            }
        }
    }
}

/// The settings window with a hand-drawn stand-in for the sidebar. On macOS 26 the real sidebar is a Liquid Glass
/// panel whose content is mirrored through a portal, which neither cacheDisplay nor layer rendering can capture.
/// Rows, footer and panes are the real views.
private struct GalleryWindow: View {
    let tab: SettingsTab
    /// Widgets pane with the first bar tile selected, to show the tile inspector.
    var selected = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    ForEach([0xFF5F57, 0xFEBC2E, 0x28C840] as [UInt32], id: \.self) {
                        Circle().fill(Color(rgb: $0)).frame(width: 12, height: 12)
                    }
                }
                .padding(.leading, 12)
                .padding(.top, 10)
                .padding(.bottom, 18)
                ForEach(SettingsTab.allCases) { item in
                    SettingsSidebarRow(tab: item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(item == tab ? Color.primary.opacity(0.09) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Spacer()
                SettingsSidebarFooter()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: 210)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.06)) }
            .padding(8)
            if selected {
                WidgetsSettings(selection: LayoutStore.shared.tiles.first?.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                SettingsPaneContent(tab: tab)
            }
        }
        .frame(width: 940, height: 660)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SettingsSheet: View {
    let shots: [SettingsShot]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Settings · every pane · light and dark").font(.system(size: 36, weight: .bold)).foregroundStyle(Palette.ink)
            ForEach([false, true], id: \.self) { dark in
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(940), spacing: 28), count: 3), alignment: .leading,
                          spacing: 28) {
                    ForEach(shots.filter { $0.dark == dark }) { shot in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(shot.id).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink)
                            if let image = shot.image {
                                Image(nsImage: image)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
                            } else {
                                Text("Not rendered").foregroundStyle(Palette.coral)
                            }
                        }
                    }
                }
            }
        }
        .padding(60)
        .background(LinearGradient(colors: [Color(rgb: 0xEDE9E1), Color(rgb: 0xD9DCE0)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}
#endif
