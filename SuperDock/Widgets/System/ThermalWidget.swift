import SwiftUI

struct ThermalWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "system.thermal"
    static var name: String { String(localized: "Thermal") }
    static let category = WidgetCategory.system
    static let symbol = "thermometer.medium"
    static let supportedSizes: [TileSize] = [.compact]

    static func view(size: TileSize, settings: Settings) -> some View {
        ThermalTile()
    }
}

/// macOS only exposes a coarse thermal state publicly (no temperatures), which is what this shows.
private struct ThermalTile: View {
    @State private var state = ProcessInfo.processInfo.thermalState

    var body: some View {
        ThermalTileView(state: state)
            .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
                state = ProcessInfo.processInfo.thermalState
            }
    }
}

/// 8 · Glyph. Each state has its own word and glyph (thermometer level, then Limo fanning itself at Hot), so colour is
/// never the only cue. Hot warms the tile; Critical adds the coral needs-you outline.
struct ThermalTileView: View {
    @Environment(\.tile) private var tile
    var state: ProcessInfo.ThermalState

    var body: some View {
        let look = look
        GlyphTile(caption: look.word, title: look.word, captionColor: look.color) {
            if state == .serious {
                LimoFace(snoring: false, pose: .fansItself).scaleEffect(1.25)
            } else {
                TileSymbol(name: look.symbol, color: look.color)
            }
        }
        .tileTint(state == .serious ? Palette.hot : state == .critical ? Palette.coral : nil, opacity: 0.18)
        // A second `.preference` on the same view would replace the tint, so the outline rides on a background.
        .background { if state == .critical { Color.clear.tileOutline(.alert) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Thermal state")
        .accessibilityValue(look.word)
    }

    private struct Look {
        let word: String
        let symbol: String
        let color: Color
    }

    private var look: Look {
        switch state {
        case .nominal: Look(word: String(localized: "Cool"), symbol: "thermometer.low", color: tile.surface.good)
        case .fair: Look(word: String(localized: "Warm"), symbol: "thermometer.medium",
                         color: tile.surface.isDark ? Palette.note : tile.surface.warning)
        case .serious: Look(word: String(localized: "Hot"), symbol: "thermometer.high", color: Palette.hot)
        case .critical: Look(word: String(localized: "Critical"), symbol: "thermometer.high", color: tile.surface.danger)
        @unknown default: Look(word: String(localized: "Unknown"), symbol: "thermometer.medium", color: tile.surface.secondary)
        }
    }
}
