import SwiftUI

// MARK: - Moon

struct MoonPhaseView: View {
    @Environment(\.tile) private var tile
    var phase: MoonPhase

    var body: some View {
        let lit = String(localized: "\(Int((phase.illumination * 100).rounded()))% lit")
        let event = phase.isWaxing ? String(localized: "Full") : String(localized: "New")
        let next = switch phase.daysToNext {
        case 0: String(localized: "\(event) tonight")
        case 1: String(localized: "\(event) tomorrow")
        default: String(localized: "\(event) in \(phase.daysToNext) days")
        }
        Group {
            if tile.isPortrait {
                VStack(spacing: 6 * tile.scale) {
                    Spacer(minLength: 0)
                    MoonDisc(phase: phase).frame(width: tile.contentSize.width * 0.8)
                    Spacer(minLength: 0)
                    Text(phase.name).lineLimit(2).multilineTextAlignment(.center).tileStyle(.title)
                    Text(lit).tileStyle(.detail)
                    Text(next).tileStyle(.detail).minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            } else {
                GlyphTile(caption: lit, title: phase.name, details: [lit, next]) {
                    // The kit's glyph slot is sized for symbols; a disc with no padding reads small, so it grows a little.
                    MoonDisc(phase: phase).scaleEffect(1.2)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(phase.name)
        .accessibilityValue("\(lit), \(next)")
    }
}

/// The moon as it looks tonight: cream lit side, a dark limb, the terminator an ellipse that sweeps with the phase.
/// Northern-hemisphere view (waxing lit on the right).
struct MoonDisc: View {
    @Environment(\.tile) private var tile
    var phase: MoonPhase

    /// Craters in unit-disc space (centre 0,0, radius 1).
    private static let craters: [CGRect] = [
        (0.38, -0.38, 0.14), (0.5, 0.12, 0.09), (0.2, 0.5, 0.07), (-0.32, -0.12, 0.12), (-0.18, 0.42, 0.08), (0.02, -0.08, 0.06)
    ].map { CGRect(x: $0 - $2, y: $1 - $2, width: $2 * 2, height: $2 * 2) }

    var body: some View {
        let isDark = tile.surface.isDark
        let age = phase.age
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let disc = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            context.fill(disc, with: .color(isDark ? .black.opacity(0.3) : Palette.ink.opacity(0.2)))

            let lit = Self.litPath(center: center, radius: radius, age: age)
            context.fill(lit, with: .radialGradient(Gradient(colors: [Color(rgb: 0xF6EFDC), Color(rgb: 0xE2D5B5)]),
                                                    center: CGPoint(x: center.x - radius * 0.2, y: center.y - radius * 0.25),
                                                    startRadius: 0, endRadius: radius * 1.2))
            context.drawLayer { layer in
                layer.clip(to: lit)
                for crater in Self.craters {
                    let rect = CGRect(x: center.x + crater.minX * radius, y: center.y + crater.minY * radius,
                                      width: crater.width * radius, height: crater.height * radius)
                    layer.fill(Path(ellipseIn: rect), with: .color(Color(rgb: 0xCBBE9C).opacity(0.75)))
                }
            }
            if !isDark { context.stroke(disc, with: .color(Palette.ink.opacity(0.12)), lineWidth: 0.75) }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// The limb on the lit side, then back along the terminator, whose half-width is r·cos(2π·age).
    static func litPath(center: CGPoint, radius: CGFloat, age: Double) -> Path {
        let side: CGFloat = age < 0.5 ? 1 : -1
        let bulge = side * CGFloat(cos(2 * .pi * age))
        let steps = 48
        var path = Path()
        for step in 0...steps {
            let angle = CGFloat.pi * CGFloat(step) / CGFloat(steps)
            let point = CGPoint(x: center.x + side * radius * sin(angle), y: center.y - radius * cos(angle))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        for step in stride(from: steps, through: 0, by: -1) {
            let angle = CGFloat.pi * CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(x: center.x + bulge * radius * sin(angle), y: center.y - radius * cos(angle)))
        }
        path.closeSubpath()
        return path
    }
}
