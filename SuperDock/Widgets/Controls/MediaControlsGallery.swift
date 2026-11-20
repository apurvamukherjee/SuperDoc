#if DEBUG
import SwiftUI

extension GallerySheets {
    /// Now Playing and Controls.
    /// Compare with design/mockups/02-catalog-media-controls-files-productivity-dev-fun-plugins.png.
    static var mediaControls: AnyView? { AnyView(MediaControlsSheet()) }
}

@MainActor
private enum MediaFixtures {
    static let nightDrive = NowPlayingTrack(title: "Night Drive", artist: "Sora Vale", album: "Low Tide", isPlaying: true,
                                            art: Samples.art, progress: 0.38, time: "1:24 / 3:41")
    static let glasshouse = NowPlayingTrack(title: "Glasshouse", artist: "Milo Ferren", album: "Green Room", isPlaying: false,
                                            art: [Color(rgb: 0x5FE3B0), Color(rgb: 0x2E9BD6), Color(rgb: 0x2850D8)],
                                            progress: 0.5, time: "2:08 / 4:12")
    static let noArt = NowPlayingTrack(title: "Untitled Demo", artist: "", album: "", isPlaying: true,
                                       art: NowPlayingTrack.fallbackArt)

    static let actions: [QuickActionsView.Item] = [
        .init(id: "lock", symbol: "lock", label: "Lock Screen"),
        .init(id: "screenshot", symbol: "camera", label: "Screenshot"),
        .init(id: "darkMode", symbol: "circle.lefthalf.filled", label: "Toggle Dark Mode", isOn: true)
    ]
    static let allActions: [QuickActionsView.Item] = [
        .init(id: "lock", symbol: "lock", label: "Lock Screen"),
        .init(id: "sleep", symbol: "display", label: "Sleep Displays"),
        .init(id: "screenshot", symbol: "camera", label: "Screenshot"),
        .init(id: "trash", symbol: "trash", label: "Empty Trash"),
        .init(id: "hidden", symbol: "eye", label: "Show/Hide Hidden Files"),
        .init(id: "darkMode", symbol: "circle.lefthalf.filled", label: "Toggle Dark Mode", isOn: true)
    ]
}

private struct MediaControlsSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach([SurfaceStyle.glassDark, .solidLight, .paper], id: \.self) { StylePanel(style: $0) }
            ScalePanel()
        }
        .padding(40)
        .background(Palette.inkDeep)
    }
}

private struct Caption: View {
    let text: String
    let style: SurfaceStyle
    var size: CGFloat = 13
    var weight = Font.Weight.semibold

    var body: some View {
        Text(text).font(.system(size: size, weight: weight))
            .foregroundStyle(style.isDark ? Color.white.opacity(0.75) : Palette.ink.opacity(0.75))
    }
}

/// Every tile and state in one style at 85 pt.
private struct StylePanel: View {
    let style: SurfaceStyle
    var unit: CGFloat = 73

    private var surface: SurfaceTokens { SurfaceTokens(style) }

    private func tile(_ view: some View, _ size: TileSize, portrait: Bool = false) -> some View {
        view.asTile(TileContext(unit: unit, size: size, isPortrait: portrait, surface: surface))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Caption(text: "\(style.rawValue) · \(Int(unit + 12)) pt", style: style, size: 22, weight: .bold)
                Caption(text: "Media · Now Playing C · M · W · L — no artwork — nothing playing C · M · W", style: style)
                GalleryBar(surface: surface) {
                    tile(NowPlayingView(track: MediaFixtures.nightDrive), .compact)
                    tile(NowPlayingView(track: MediaFixtures.nightDrive), .medium)
                    tile(NowPlayingView(track: MediaFixtures.glasshouse), .wide)
                    tile(NowPlayingView(track: MediaFixtures.nightDrive), .large)
                }
                GalleryBar(surface: surface) {
                    tile(NowPlayingView(track: MediaFixtures.noArt), .medium)
                    tile(NowPlayingView(track: nil), .compact)
                    tile(NowPlayingView(track: nil), .medium)
                    tile(NowPlayingView(track: nil), .wide)
                }
                Caption(text: "Controls · Quick Actions C · M · W — none chosen", style: style)
                GalleryBar(surface: surface) {
                    tile(QuickActionsView(items: MediaFixtures.actions), .compact)
                    tile(QuickActionsView(items: MediaFixtures.actions), .medium)
                    tile(QuickActionsView(items: MediaFixtures.allActions), .wide)
                    tile(QuickActionsView(items: []), .medium)
                }
                Caption(text: "Volume C · M · W — muted W — Brightness M · W — not adjustable M · W — Wi-Fi on · off", style: style)
                GalleryBar(surface: surface) {
                    tile(VolumeView(level: 0.5), .compact)
                    tile(VolumeView(level: 0.64), .medium)
                    tile(VolumeView(level: 0.64), .wide)
                    tile(VolumeView(level: 0.4, isMuted: true), .wide)
                }
                GalleryBar(surface: surface) {
                    tile(BrightnessView(level: 0.8), .medium)
                    tile(BrightnessView(level: 0.8), .wide)
                    tile(BrightnessView(level: nil), .medium)
                    tile(BrightnessView(level: nil), .wide)
                    tile(WiFiView(isOn: true), .compact)
                    tile(WiFiView(isOn: false), .compact)
                }
                Caption(text: "Volume no software control C · M — Wi-Fi without hardware", style: style)
                GalleryBar(surface: surface) {
                    tile(VolumeView(level: 0, isAdjustable: false), .compact)
                    tile(VolumeView(level: 0, isAdjustable: false), .medium)
                    tile(WiFiView(isOn: nil), .compact)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Caption(text: "Portrait M", style: style)
                GalleryBar(surface: surface, vertical: true) {
                    tile(NowPlayingView(track: MediaFixtures.nightDrive), .medium, portrait: true)
                    tile(NowPlayingView(track: nil), .medium, portrait: true)
                    tile(QuickActionsView(items: MediaFixtures.actions), .medium, portrait: true)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Caption(text: " ", style: style)
                GalleryBar(surface: surface, vertical: true) {
                    tile(VolumeView(level: 0.64), .medium, portrait: true)
                    tile(BrightnessView(level: 0.8), .medium, portrait: true)
                    tile(BrightnessView(level: nil), .medium, portrait: true)
                }
            }
        }
        .padding(28)
        .background(galleryWallpaper(style), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// The main sizes at a tiny (56 pt) and a huge (120 pt) Dock, glass dark.
private struct ScalePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Caption(text: "Scale · 56 pt tight · 120 pt roomy", style: .glassDark, size: 22, weight: .bold)
            ForEach([56, 120], id: \.self) { bar in
                row(unit: CGFloat(bar) - 2 * TileContext.spacing)
            }
        }
        .padding(28)
        .background(galleryWallpaper(.glassDark), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func row(unit: CGFloat) -> some View {
        let surface = SurfaceTokens(.glassDark)
        func tile(_ view: some View, _ size: TileSize) -> some View {
            view.asTile(TileContext(unit: unit, size: size, surface: surface))
        }
        return GalleryBar(surface: surface) {
            tile(NowPlayingView(track: MediaFixtures.nightDrive), .medium)
            tile(NowPlayingView(track: MediaFixtures.glasshouse), .wide)
            tile(NowPlayingView(track: nil), .medium)
            tile(QuickActionsView(items: MediaFixtures.actions), .medium)
            tile(VolumeView(level: 0.5), .compact)
            tile(VolumeView(level: 0.64), .wide)
            tile(BrightnessView(level: nil), .medium)
            tile(WiFiView(isOn: true), .compact)
        }
    }
}
#endif
