#if DEBUG
import AppKit
import SwiftUI

/// `SuperDock -renderGallery <dir>` draws the kit offscreen to PNGs for side-by-side review with design/mockups,
/// then quits before any bar, Dock or onboarding work starts.
@MainActor
enum GalleryRenderer {
    enum RenderError: Error {
        case noImage(String)
        case encodeFailed(String)
    }

    static func runIfRequested() {
        guard let path = UserDefaults.standard.string(forKey: "renderGallery") else { return }
        do {
            try render(to: URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true))
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("renderGallery failed: \(error)\n".utf8))
            exit(1)
        }
    }

    static func render(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for style in SurfaceStyle.allCases {
            try write(KitSheet(style: style), name: "kit-\(style.rawValue)", to: directory)
        }
        try write(StylesSheet(), name: "styles", to: directory)
        try write(ScaleSheet(), name: "scale", to: directory)
        let owned: [(String, AnyView?)] = [
            ("ai", GallerySheets.ai), ("time", GallerySheets.time), ("system", GallerySheets.system),
            ("weather", GallerySheets.weather), ("media-controls", GallerySheets.mediaControls),
            ("files-productivity", GallerySheets.filesProductivity), ("dev-fun-plugins", GallerySheets.devFunPlugins),
            ("bar", GallerySheets.bar), ("limo", GallerySheets.limo), ("settings", GallerySheets.settings),
            ("surfaces", GallerySheets.surfaces), ("onboarding", GallerySheets.onboarding)
        ]
        for (name, sheet) in owned {
            if let sheet { try write(sheet, name: "sheet-\(name)", to: directory) }
        }
    }

    private static func write(_ view: some View, name: String, to directory: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw RenderError.noImage(name) }
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw RenderError.encodeFailed(name)
        }
        let url = directory.appending(path: "\(name).png")
        try png.write(to: url)
        print(url.path)
    }
}

/// One sheet per phase-2 owner, each defined in that owner's own `*Gallery.swift` so no two owners edit the same file.
/// nil = nothing to render yet.
enum GallerySheets {}

/// A wallpaper behind each style, chosen like the mockups: deep navy for dark kits, a bright sky for light glass.
func galleryWallpaper(_ style: SurfaceStyle) -> LinearGradient {
    let colors: [UInt32] = switch style {
    case .glassDark, .frostedDark: [0x1C1B3E, 0x2E2468, 0x123F4C]
    case .solidDark: [0x26272C, 0x1C1D21, 0x18191C]
    case .glassLight, .frostedLight: [0x9CCBF2, 0xDDEBF7, 0xF6F4F0]
    case .solidLight: [0xD9D4CA, 0xE7E3DC, 0xCFCFD3]
    case .paper: [0xEDE9E1, 0xE6E1D7, 0xD9DCE0]
    }
    return LinearGradient(colors: colors.map { Color(rgb: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// One bar strip: backdrop + 6 pt padding + 6 pt gaps, horizontal or vertical.
struct GalleryBar<Content: View>: View {
    let surface: SurfaceTokens
    var vertical = false
    @ViewBuilder let content: Content

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: TileContext.spacing))
                              : AnyLayout(HStackLayout(alignment: .top, spacing: TileContext.spacing))
        layout { content }
            .padding(TileContext.spacing)
            .background(BarBackdrop(surface: surface))
    }
}

extension View {
    /// Draws `self` as a tile in `context` (gallery and previews).
    func asTile(_ context: TileContext) -> some View {
        tileChrome().tileContext(context)
    }
}

private struct SheetText: View {
    let text: String
    let style: SurfaceStyle
    var size: CGFloat = 13
    var weight = Font.Weight.regular
    var secondary = false

    var body: some View {
        let ink = style.isDark ? Color.white : Palette.ink
        Text(text).font(.system(size: size, weight: weight)).foregroundStyle(secondary ? ink.opacity(0.6) : ink)
    }
}

private struct KitSheet: View {
    let style: SurfaceStyle

    private var surface: SurfaceTokens { SurfaceTokens(style) }

    private func context(_ size: TileSize, portrait: Bool = false) -> TileContext {
        TileContext(size: size, isPortrait: portrait, surface: surface)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SheetText(text: "KIT · 10 ARCHETYPES × 4 SIZES · \(style.rawValue.uppercased()) · 85 PT", style: style,
                      size: 12, weight: .semibold, secondary: true)
            SheetText(text: "Every widget is one of these", style: style, size: 44, weight: .bold)
                .padding(.bottom, 24)
            HStack(alignment: .top, spacing: 36) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Archetype.allCases) { row($0) }
                }
                VStack(alignment: .leading, spacing: 12) {
                    SheetText(text: "Portrait (vertical bar)", style: style, size: 17, weight: .semibold)
                    GalleryBar(surface: surface) {
                        ForEach(Samples.portraits.indices, id: \.self) { Samples.portraits[$0].asTile(context(.medium, portrait: true)) }
                    }
                    SheetText(text: "Shared states", style: style, size: 17, weight: .semibold).padding(.top, 24)
                    ForEach(Samples.states) { sample in
                        HStack(spacing: 22) {
                            GalleryBar(surface: surface) {
                                TileStateView(state: sample.state).asTile(context(.compact))
                                TileStateView(state: sample.state).asTile(context(.medium))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                SheetText(text: sample.title, style: style, weight: .semibold)
                                SheetText(text: sample.note, style: style, secondary: true)
                            }
                            .frame(width: 260, alignment: .leading)
                        }
                    }
                }
            }
        }
        .padding(60)
        .background(galleryWallpaper(style))
    }

    private func row(_ archetype: Archetype) -> some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                SheetText(text: "\(archetype.rawValue) · \(archetype.title)", style: style, size: 17, weight: .semibold)
                SheetText(text: archetype.subtitle, style: style, secondary: true)
            }
            .frame(width: 220, alignment: .leading)
            GalleryBar(surface: surface) {
                ForEach(TileSize.allCases) { size in
                    if let tile = archetype.sample(size) { tile.asTile(context(size)) }
                }
            }
        }
    }
}

/// The same small bar in every style, like the top half of mockup 01.
private struct StylesSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SheetText(text: "Styles × light/dark", style: .paper, size: 36, weight: .bold)
            Grid(horizontalSpacing: 18, verticalSpacing: 18) {
                ForEach(0..<4, id: \.self) { line in
                    GridRow {
                        ForEach(SurfaceStyle.allCases.dropFirst(line * 2).prefix(2), id: \.self) { panel($0) }
                    }
                }
            }
        }
        .padding(60)
        .background(Palette.cream)
    }

    private func panel(_ style: SurfaceStyle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(style.rawValue).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
            SampleBar(unit: 73, style: style).frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(width: 640, height: 170, alignment: .topLeading)
        .background(galleryWallpaper(style), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// The bar at a tiny (56 pt), default (85 pt) and huge (120 pt) Dock.
private struct ScaleSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SheetText(text: "Scale: 56 pt tight · 85 pt · 120 pt roomy", style: .glassDark, size: 36, weight: .bold)
            ForEach([56, 85, 120], id: \.self) { bar in
                HStack(spacing: 20) {
                    SheetText(text: "\(bar) pt", style: .glassDark, weight: .semibold).frame(width: 60, alignment: .leading)
                    SampleBar(unit: CGFloat(bar) - 2 * TileContext.spacing, style: .glassDark)
                }
            }
        }
        .padding(60)
        .background(galleryWallpaper(.glassDark))
    }
}

/// AI-style bars, the agents list, a clock and CPU: the hero bar's mix of archetypes.
private struct SampleBar: View {
    let unit: CGFloat
    let style: SurfaceStyle

    private func context(_ size: TileSize) -> TileContext {
        TileContext(unit: unit, size: size, surface: SurfaceTokens(style))
    }

    var body: some View {
        GalleryBar(surface: SurfaceTokens(style)) {
            BarsTile(rows: [BarRow(label: "Claude 5H", value: "62%", fraction: 0.62, color: Palette.claude),
                            BarRow(label: "Codex 5H", value: "86%", fraction: 0.86, color: Palette.coral)])
                .asTile(context(.medium))
            ListTile(rows: Samples.agents, counts: Samples.agentCounts).asTile(context(.medium))
            ClockTile(time: "10:55", detail: "Thu 19").asTile(context(.compact))
            ChartTile(label: "CPU", value: "23%", series: [.init(values: Samples.cpu, color: Palette.progress)])
                .asTile(context(.compact))
        }
    }
}
#endif
