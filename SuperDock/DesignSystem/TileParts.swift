import SwiftUI

extension Double {
    var unitClamped: Double { Swift.min(Swift.max(self, 0), 1) }
}

/// Label top-left (with an optional trailing badge), hero on the baseline, detail at the bottom: the slot grammar every
/// archetype follows.
struct SlotStack<Hero: View, Bottom: View>: View {
    @Environment(\.tile) private var tile
    var label: String?
    var badge: String?
    var badgeColor: Color?
    @ViewBuilder var hero: Hero
    @ViewBuilder var bottom: Bottom

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label, tile.showsLabel || tile.isCompact {
                HStack(spacing: 4) {
                    Text(label).tileStyle(.label)
                    if let badge {
                        Spacer(minLength: 0)
                        Text(badge).font(tile.font(.label)).foregroundStyle(badgeColor ?? tile.surface.good)
                    }
                }
            }
            Spacer(minLength: 0)
            hero
            Spacer(minLength: 0)
            bottom
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// A hero number with its smaller unit on the same baseline: "11.2 GB".
struct HeroText: View {
    var value: String
    var unit: String?
    var style = TileTextStyle.hero
    var color: Color?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1.5) {
            Text(value).tileStyle(style, color: color)
            if let unit { Text(unit).tileStyle(.heroUnit) }
        }
    }
}

/// A rounded progress track. Horizontal by default; vertical fills from the bottom.
struct Meter: View {
    @Environment(\.tile) private var tile
    var fraction: Double
    var color: Color?
    var thickness: CGFloat = 4
    var axis = Axis.horizontal

    var body: some View {
        let side = thickness * tile.scale
        GeometryReader { geo in
            let fill = color ?? tile.accent
            if axis == .horizontal {
                ZStack(alignment: .leading) {
                    Capsule().fill(tile.surface.track)
                    Capsule().fill(fill).frame(width: max(side, geo.size.width * fraction.unitClamped))
                }
            } else {
                ZStack(alignment: .bottom) {
                    Capsule().fill(tile.surface.track)
                    Capsule().fill(fill).frame(height: max(side, geo.size.height * fraction.unitClamped))
                }
            }
        }
        .frame(width: axis == .vertical ? side : nil, height: axis == .horizontal ? side : nil)
        .tileAnimation(value: fraction)
        .accessibilityHidden(true)
    }
}

/// Concentric arcs, outermost first, starting at 12 o'clock.
struct RingGauge: View {
    struct Ring: Equatable {
        var fraction: Double
        var color: Color
    }

    @Environment(\.tile) private var tile
    var rings: [Ring]
    var lineWidth: CGFloat = 5

    var body: some View {
        let width = lineWidth * tile.scale
        ZStack {
            ForEach(rings.indices, id: \.self) { index in
                let inset = CGFloat(index) * (width + 1.5 * tile.scale) + width / 2
                Circle().stroke(tile.surface.track, lineWidth: width).padding(inset)
                Circle().trim(from: 0, to: rings[index].fraction.unitClamped)
                    .stroke(rings[index].color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(inset)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .tileAnimation(value: rings)
        .accessibilityHidden(true)
    }
}

/// A line over a soft area fill; series drawn together share one scale.
struct AreaChart: View {
    struct Series: Equatable {
        var values: [Double]
        var color: Color
        var filled = true
    }

    var series: [Series]

    var body: some View {
        let top = max(series.flatMap(\.values).max() ?? 1, .ulpOfOne) * 1.15
        Canvas { context, size in
            for line in series where line.values.count > 1 {
                let step = size.width / CGFloat(line.values.count - 1)
                let points = line.values.enumerated().map { index, value in
                    CGPoint(x: CGFloat(index) * step, y: size.height * (1 - CGFloat(value / top)))
                }
                var stroke = Path()
                stroke.addLines(points)
                if line.filled {
                    var area = stroke
                    area.addLine(to: CGPoint(x: size.width, y: size.height))
                    area.addLine(to: CGPoint(x: 0, y: size.height))
                    area.closeSubpath()
                    context.fill(area, with: .linearGradient(
                        Gradient(colors: [line.color.opacity(0.5), line.color.opacity(0.22)]),
                        startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                }
                context.stroke(stroke, with: .color(line.color), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

/// A row container inside a tile: list rows, ports, agents. `alert` is the coral needs-you treatment.
struct TileChip<Content: View>: View {
    @Environment(\.tile) private var tile
    var alert = false
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: tile.innerRadius * 0.8, style: .continuous)
        content
            .padding(.horizontal, 4 * tile.scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(alert ? Palette.coral.opacity(0.22) : tile.surface.chipFill, in: shape)
            .overlay { if alert { shape.strokeBorder(Palette.coral.opacity(0.8), lineWidth: 1) } }
    }
}

/// The partial ring that means "working". Pulses while active instead of spinning, so it costs one layer animation.
struct ActivityArc: View {
    var color: Color

    var body: some View {
        Circle().trim(from: 0.08, to: 0.78)
            .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .padding(1)
    }
}

/// What sits before a row's title.
enum RowGlyph: Equatable {
    case none
    case symbol(String, Color)
    case activity(Color)

    @MainActor @ViewBuilder func view(size: CGFloat) -> some View {
        switch self {
        case .none:
            EmptyView()
        case let .symbol(name, color):
            Image(systemName: name).font(.system(size: size * 0.85, weight: .bold)).foregroundStyle(color)
                .frame(width: size, height: size)
        case let .activity(color):
            ActivityArc(color: color).frame(width: size, height: size).workingPulse(true)
        }
    }
}

/// A round icon button: plain glyph, a tinted disc, the white "primary" disc used for play, or a dark scrim over art.
struct TileIconButton: View {
    enum Style { case glyph, disc, primary, scrim }

    @Environment(\.tile) private var tile
    var symbol: String
    var label: String
    var style = Style.disc
    var diameter: CGFloat = 26
    var action: () -> Void = {}

    var body: some View {
        let side = diameter * tile.scale
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: side * (style == .glyph ? 0.5 : 0.36), weight: .bold))
                .foregroundStyle(style == .primary ? tile.surface.controlOnInk : style == .scrim ? .white : tile.surface.primary)
                .frame(width: side, height: side)
                .background {
                    switch style {
                    case .glyph: Color.clear
                    case .disc: Circle().fill(tile.surface.controlFill)
                    case .primary: Circle().fill(tile.surface.controlOn)
                    case .scrim: Circle().fill(Color.black.opacity(0.28))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(TilePressStyle())
        .accessibilityLabel(label)
    }
}

struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .tileAnimation(Motion.press, value: configuration.isPressed)
    }
}
