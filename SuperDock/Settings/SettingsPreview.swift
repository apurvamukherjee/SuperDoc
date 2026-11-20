import SwiftUI

/// One tile to draw in a settings preview. A nil widget is a layout entry this build doesn't know.
struct PreviewTile: Identifiable {
    let id: UUID
    let widget: WidgetDescriptor?
    let size: TileSize
    var settings: Data?

    @MainActor init(_ tile: Tile) {
        self.init(id: tile.id, widget: WidgetRegistry.widget(tile.widgetId), size: tile.size, settings: tile.settings)
    }

    init(id: UUID = UUID(), widget: WidgetDescriptor?, size: TileSize, settings: Data? = nil) {
        (self.id, self.widget, self.size, self.settings) = (id, widget, size, settings)
    }
}

/// The real widgets on a small bar, drawn with the user's current appearance prefs over a wallpaper, so a preview
/// looks like the bar will. Previews are live views: they update with their data and rest otherwise.
struct PreviewBar: View {
    let tiles: [PreviewTile]
    var unit: CGFloat = 60

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(AppearancePrefs.styleKey) private var style = BarStyle.glass
    @AppStorage(AppearancePrefs.tileBackgroundsKey) private var tileBackgrounds = true
    @AppStorage(AppearancePrefs.cornerRadiusKey) private var cornerRadius = AppearancePrefs.defaultCornerRadius
    @AppStorage(AppearancePrefs.opacityKey) private var opacity = 1.0
    @AppStorage(AppearancePrefs.accentKey) private var accent = ""

    var body: some View {
        let surface = SurfaceTokens(SurfaceStyle.resolve(style, isDark: colorScheme == .dark,
                                                         reduceTransparency: reduceTransparency),
                                    tileBackgrounds: tileBackgrounds)
        // The real bar's radius is set at Dock size; scale it with the preview so the corners read the same.
        let barRadius = cornerRadius * (unit + 2 * TileContext.spacing) / 85
        let accentColor = Color(hex: accent) ?? .accentColor
        HStack(spacing: TileContext.spacing) {
            ForEach(tiles) { tile in
                let context = TileContext(unit: unit, size: tile.size, surface: surface, accent: accentColor,
                                          radius: max(barRadius - TileContext.spacing, 4))
                Group {
                    if let widget = tile.widget {
                        widget.tileView(size: tile.size, settings: tile.settings)
                    } else {
                        TileStateView(state: .empty(title: String(localized: "Unknown"),
                                                    detail: String(localized: "Not in this version")))
                    }
                }
                .tileChrome()
                .tileContext(context)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(TileContext.spacing)
        .background(BarBackdrop(surface: surface, radius: barRadius).opacity(opacity))
        .tint(accentColor)
        // A preview is for looking at; clicks belong to the card around it, not to the widget's controls, and
        // a page of previews shouldn't keep looping animations running.
        .allowsHitTesting(false)
        .environment(\.tileIsStill, true)
    }
}

/// The wallpaper behind previews, matched to the bar style like the design gallery's.
struct PreviewWallpaper: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(AppearancePrefs.styleKey) private var style = BarStyle.glass
    var cornerRadius: CGFloat = 10

    var body: some View {
        let resolved = SurfaceStyle.resolve(style, isDark: colorScheme == .dark, reduceTransparency: reduceTransparency)
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LinearGradient(colors: Self.colors(resolved).map { Color(rgb: $0) },
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    static func colors(_ style: SurfaceStyle) -> [UInt32] {
        switch style {
        case .glassDark, .frostedDark: [0x2A1F5E, 0x1E2D52, 0x123F4C]
        case .solidDark: [0x26272C, 0x1C1D21, 0x18191C]
        case .glassLight, .frostedLight: [0x9CCBF2, 0xDDEBF7, 0xF6F4F0]
        case .solidLight: [0xD9D4CA, 0xE7E3DC, 0xCFCFD3]
        case .paper: [0xEDE9E1, 0xE6E1D7, 0xD9DCE0]
        }
    }
}
