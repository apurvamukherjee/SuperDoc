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

/// 8 · Glyph. Each state has its own word and glyph (thermometer level, then sweating Limo at Hot), so colour is
/// never the only cue. Hot warms the tile; Critical adds the coral needs-you outline.
struct ThermalTileView: View {
    @Environment(\.tile) private var tile
    var state: ProcessInfo.ThermalState

    var body: some View {
        let look = look
        GlyphTile(caption: look.word, title: look.word, captionColor: look.color) {
            if state == .serious {
                SweatingLimo().scaleEffect(1.25)
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

/// Limo overheating: `LimoFace`'s D-face with squiggly eyes and mouth and a sweat drop.
private struct SweatingLimo: View {
    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let rect = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2 + side * 0.07, width: side, height: side * 0.86)
            let face = UnevenRoundedRectangle(topLeadingRadius: side * 0.2, bottomLeadingRadius: side * 0.2,
                                              bottomTrailingRadius: side * 0.43, topTrailingRadius: side * 0.43,
                                              style: .continuous).path(in: rect)
            context.fill(face, with: .linearGradient(Gradient(colors: [Palette.ink, Palette.inkDeep]),
                                                     startPoint: rect.origin, endPoint: CGPoint(x: rect.minX, y: rect.maxY)))
            context.stroke(face, with: .color(.white.opacity(0.92)), lineWidth: side * 0.045)

            var features = Path()
            let squiggle = { (left: CGFloat, top: CGFloat, width: CGFloat) in
                let start = CGPoint(x: rect.minX + side * left, y: rect.minY + rect.height * top)
                let wave = side * 0.045
                features.move(to: start)
                features.addCurve(to: CGPoint(x: start.x + side * width, y: start.y),
                                  control1: CGPoint(x: start.x + side * width / 3, y: start.y - wave),
                                  control2: CGPoint(x: start.x + side * width * 2 / 3, y: start.y + wave))
            }
            squiggle(0.2, 0.4, 0.16)
            squiggle(0.45, 0.4, 0.16)
            squiggle(0.28, 0.66, 0.26)
            context.stroke(features, with: .color(Palette.cream), style: StrokeStyle(lineWidth: side * 0.045, lineCap: .round))

            let cheek = CGRect(x: rect.minX + side * 0.74, y: rect.minY + rect.height * 0.56, width: side * 0.09, height: side * 0.09)
            context.fill(Path(ellipseIn: cheek), with: .color(Palette.coral.opacity(0.9)))

            let tip = CGPoint(x: rect.minX + side * 0.84, y: rect.minY - side * 0.08)
            let radius = side * 0.055
            var drop = Path()
            drop.move(to: tip)
            drop.addQuadCurve(to: CGPoint(x: tip.x - radius, y: tip.y + radius * 2.4),
                              control: CGPoint(x: tip.x - radius, y: tip.y + radius))
            drop.addArc(center: CGPoint(x: tip.x, y: tip.y + radius * 2.4), radius: radius, startAngle: .degrees(180),
                        endAngle: .degrees(0), clockwise: true)
            drop.addQuadCurve(to: tip, control: CGPoint(x: tip.x + radius, y: tip.y + radius))
            context.fill(drop, with: .color(Palette.water))
        }
        .accessibilityHidden(true)
    }
}
