import SwiftUI

// Plotting code: x/y/dx/dy are the clearest names for coordinates, and confetti bits are plain literal rows.
// swiftlint:disable identifier_name large_tuple

// Arms and props. Coordinates are body-relative (see `LimoPainter`); arms are written for the right side and
// mirrored for the left.
extension LimoPainter {
    struct ArmStroke {
        let path: Path
        let front: Bool
    }

    func arm(_ arm: LimoLook.Arm, mirrored: Bool) -> ArmStroke {
        let at = { (x: CGFloat, y: CGFloat) in pt(mirrored ? 1 - x : x, y) }
        var path = Path()
        let curve = { (start: (CGFloat, CGFloat), c1: (CGFloat, CGFloat), c2: (CGFloat, CGFloat), end: (CGFloat, CGFloat)) in
            path.move(to: at(start.0, start.1))
            path.addCurve(to: at(end.0, end.1), control1: at(c1.0, c1.1), control2: at(c2.0, c2.1))
        }
        switch arm {
        case .rest: curve((0.9, 0.6), (1.04, 0.6), (1.1, 0.74), (1.06, 0.9))
        case .wave: curve((0.86, 0.55), (1.04, 0.52), (1.13, 0.32), (1.1, 0.0))
        case .raised: curve((0.82, 0.3), (0.98, 0.22), (1.07, 0.05), (1.04, -0.22))
        case .hip: curve((0.88, 0.7), (0.98, 0.66), (1.06, 0.64), (1.12, 0.7))
        case .hug: curve((0.97, 0.42), (1.14, 0.55), (1.1, 0.82), (0.84, 0.84))
        case .poke: curve((0.8, 0.74), (0.92, 0.74), (1.02, 0.66), (1.12, 0.54))
        case .umbrella: curve((0.86, 0.8), (1.0, 0.86), (1.14, 0.72), (1.06, 0.58))
        case .fan: curve((0.9, 0.62), (1.05, 0.58), (1.12, 0.42), (1.13, 0.3))
        case .sip: curve((0.92, 0.88), (1.08, 0.84), (1.08, 0.68), (0.9, 0.7))
        case .overhead: curve((0.97, 0.66), (1.17, 0.52), (1.14, 0.16), (0.9, 0.06))
        }
        return ArmStroke(path: path, front: ![.rest, .wave, .raised, .hip].contains(arm))
    }

    func drawProps() {
        guard !faceOnly else { return }
        for prop in look.props { draw(prop) }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func draw(_ prop: LimoLook.Prop) {
        switch prop {
        case .confetti: drawConfetti()
        case .alert:
            context.fill(circle(pt(-0.2, -0.08), len(0.12)), with: .color(Palette.coral))
            drawText("!", at: pt(-0.2, -0.08), size: 0.17, color: .white)
        case .gauge: drawGauge()
        case .drop: drawDrop(at: pt(1.1, -0.06), size: 0.075)
        case .ice: drawIce()
        case .nightcap: drawNightcap()
        case .snore: drawText("z", at: pt(1.06, -0.16), size: 0.2, color: Color(white: 0.6))
        case .headphones: drawHeadphones()
        case .note: drawText("♫", at: pt(-0.3, -0.22), size: 0.2, color: Palette.inkDeep, halo: true)
        case .umbrella: drawUmbrella()
        case .rain:
            for (x, y) in [(-0.36, 0.2), (-0.26, -0.1), (-0.04, -0.2), (0.32, -0.26)] as [(CGFloat, CGFloat)] {
                var drop = Path()
                drop.move(to: pt(x + 0.03, y - 0.06)); drop.addLine(to: pt(x, y + 0.04))
                strokeLine(drop, width: len(0.03), color: Color(rgb: 0x5AA2FF))
            }
        case .fan: drawFan()
        case .sweat:
            drawDrop(at: pt(-0.1, 0.02), size: 0.07)
            drawDrop(at: pt(-0.2, 0.26), size: 0.05)
        case .glass: drawGlass()
        case .paper: drawPaper()
        case .tile: drawTile()
        case .question: drawText("?", at: pt(1.02, -0.16), size: 0.2, color: Palette.coral, halo: true)
        }
    }

    func drawText(_ text: String, at point: CGPoint, size: CGFloat, color: Color, halo: Bool = false) {
        let label = Text(text).font(.system(size: len(size), weight: .heavy, design: .rounded))
        if halo, outlined {
            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] as [(CGFloat, CGFloat)] {
                context.draw(label.foregroundStyle(Self.creamInk),
                             at: CGPoint(x: point.x + dx * len(0.02), y: point.y + dy * len(0.02)))
            }
        }
        context.draw(label.foregroundStyle(color), at: point)
    }

    private func drawConfetti() {
        let bits: [(CGFloat, CGFloat, CGFloat, Color)] = [
            (-0.2, -0.16, -30, Palette.claude), (0.34, -0.32, 20, Palette.good), (0.62, -0.3, 0, Palette.codex),
            (-0.32, 0.38, 0, Palette.coral)
        ]
        for (x, y, angle, color) in bits {
            let center = pt(x, y)
            if angle == 0 {
                context.fill(circle(center, len(0.03)), with: .color(color))
            } else {
                var dash = Path()
                let dx = cos(angle * .pi / 180) * len(0.04), dy = sin(angle * .pi / 180) * len(0.04)
                dash.move(to: CGPoint(x: center.x - dx, y: center.y - dy)); dash.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
                strokeLine(dash, width: len(0.035), color: color)
            }
        }
    }

    func drawDrop(at center: CGPoint, size: CGFloat) {
        let radius = len(size * 0.6)
        var drop = Path()
        drop.move(to: CGPoint(x: center.x, y: center.y - len(size * 1.1)))
        drop.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y + radius * 0.3),
                          control: CGPoint(x: center.x + radius * 0.9, y: center.y - radius * 0.6))
        drop.addArc(center: CGPoint(x: center.x, y: center.y + radius * 0.3), radius: radius,
                    startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        drop.addQuadCurve(to: CGPoint(x: center.x, y: center.y - len(size * 1.1)),
                          control: CGPoint(x: center.x - radius * 0.9, y: center.y - radius * 0.6))
        context.fill(drop, with: .color(Color(rgb: 0x6CC4FF)))
    }

    private func drawGauge() {
        let center = pt(0.52, 0.95)
        let radius = len(0.27)
        var dial = Path()
        dial.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        dial.closeSubpath()
        strokeLine(dial, width: len(0.05) + 2 * halo / 2, color: Self.creamInk)
        context.fill(dial, with: .color(Self.creamInk))
        var red = Path()
        red.addArc(center: center, radius: radius * 0.82, startAngle: .degrees(305), endAngle: .degrees(355), clockwise: false)
        strokeLine(red, width: len(0.07), color: Palette.coral)
        var needle = Path()
        needle.move(to: center)
        needle.addLine(to: CGPoint(x: center.x + radius * 0.8 * cos(.pi * 1.78), y: center.y + radius * 0.8 * sin(.pi * 1.78)))
        strokeLine(needle, width: len(0.035), color: Palette.inkDeep)
        strokeLine(dial, width: len(0.025), color: Palette.inkDeep)
    }

    private func drawIce() {
        let rect = CGRect(x: pt(1.08, 0.3).x, y: pt(1.08, 0.3).y, width: len(0.2), height: len(0.28))
        let cube = Path(roundedRect: rect, cornerRadius: len(0.05))
        strokeLine(cube, width: 2 * halo, color: Self.creamInk)
        context.fill(cube, with: .color(Color(rgb: 0xBFE6FF)))
        context.stroke(cube, with: .color(Color(rgb: 0x6CC4FF)), lineWidth: len(0.025))
        var cracks = Path()
        cracks.move(to: pt(1.14, 0.4)); cracks.addLine(to: pt(1.2, 0.42))
        cracks.move(to: pt(1.15, 0.48)); cracks.addLine(to: pt(1.22, 0.47))
        strokeLine(cracks, width: len(0.02), color: Color(rgb: 0x4C8DFF))
    }

    private func drawNightcap() {
        var cap = Path()
        cap.move(to: pt(0.04, 0.06))
        cap.addQuadCurve(to: pt(0.72, 0.04), control: pt(0.4, -0.02))
        cap.addQuadCurve(to: pt(0.04, 0.06), control: pt(0.3, -0.26))
        cap.closeSubpath()
        strokeLine(cap, width: 2 * halo, color: Self.creamInk)
        context.fill(cap, with: .color(Palette.coral))
        context.fill(circle(pt(0.02, 0.1), len(0.07)), with: .color(.white))
    }

    private func drawHeadphones() {
        var band = Path()
        band.move(to: pt(-0.04, 0.42))
        band.addCurve(to: pt(1.04, 0.42), control1: pt(-0.04, -0.2), control2: pt(1.04, -0.2))
        strokeLine(band, width: len(0.07) + 2 * halo, color: Self.creamInk)
        strokeLine(band, width: len(0.07), color: Palette.coral)
        for x in [-0.13, 0.99] as [CGFloat] {
            let cup = Path(roundedRect: CGRect(origin: pt(x, 0.3), size: CGSize(width: len(0.15), height: len(0.3))),
                           cornerRadius: len(0.06))
            strokeLine(cup, width: 2 * halo, color: Self.creamInk)
            context.fill(cup, with: .color(Palette.coral))
        }
    }

    private func drawUmbrella() {
        var pole = Path()
        pole.move(to: pt(1.08, 0.6)); pole.addLine(to: pt(1.08, -0.28))
        strokeLine(pole, width: len(0.03) + 2 * halo, color: Self.creamInk)
        strokeLine(pole, width: len(0.03), color: Palette.inkDeep)
        var canopy = Path()
        canopy.move(to: pt(0.84, -0.18))
        canopy.addQuadCurve(to: pt(1.3, -0.24), control: pt(1.02, -0.48))
        canopy.addQuadCurve(to: pt(0.84, -0.18), control: pt(1.08, -0.24))
        canopy.closeSubpath()
        context.fill(canopy, with: .color(Palette.coral))
    }

    private func drawFan() {
        let hinge = pt(1.13, 0.3)
        var fan = Path()
        fan.move(to: hinge)
        fan.addLine(to: pt(1.02, -0.06))
        fan.addQuadCurve(to: pt(1.3, 0.0), control: pt(1.18, -0.14))
        fan.closeSubpath()
        strokeLine(fan, width: 2 * halo, color: Self.creamInk)
        context.fill(fan, with: .color(Self.creamInk))
        var ribs = Path()
        for end in [pt(1.02, -0.06), pt(1.1, -0.08), pt(1.19, -0.07), pt(1.3, 0.0)] {
            ribs.move(to: hinge); ribs.addLine(to: end)
        }
        strokeLine(ribs, width: len(0.02), color: Palette.inkDeep)
        strokeLine(fan, width: len(0.025), color: Palette.inkDeep)
    }

    private func drawGlass() {
        var layer = context
        layer.translateBy(x: pt(0.72, 0.66).x, y: pt(0.72, 0.66).y)
        layer.rotate(by: .degrees(-24))
        let rect = CGRect(x: -len(0.11), y: -len(0.15), width: len(0.22), height: len(0.3))
        let glass = Path(roundedRect: rect, cornerRadius: len(0.04))
        layer.stroke(glass, with: .color(Self.creamInk), lineWidth: 2 * halo + len(0.03))
        layer.fill(glass, with: .color(Color(rgb: 0x34495E)))
        layer.fill(Path(roundedRect: rect.insetBy(dx: len(0.02), dy: len(0.02)).offsetBy(dx: 0, dy: len(0.06)),
                        cornerRadius: len(0.03)), with: .color(Palette.water))
    }

    private func drawPaper() {
        var layer = context
        layer.translateBy(x: pt(0.5, -0.1).x, y: pt(0.5, -0.1).y)
        layer.rotate(by: .degrees(6))
        let rect = CGRect(x: -len(0.28), y: -len(0.17), width: len(0.56), height: len(0.34))
        let card = Path(roundedRect: rect, cornerRadius: len(0.05))
        layer.stroke(card, with: .color(Palette.inkDeep), lineWidth: len(0.05))
        layer.fill(card, with: .color(Self.creamInk))
        var lines = Path()
        for (row, width) in [(0, 0.4), (1, 0.34), (2, 0.38)] as [(CGFloat, CGFloat)] {
            let y = rect.minY + len(0.09 + row * 0.08)
            lines.move(to: CGPoint(x: rect.minX + len(0.08), y: y))
            lines.addLine(to: CGPoint(x: rect.minX + len(0.08 + width), y: y))
        }
        layer.stroke(lines, with: .color(Color(rgb: 0xB5B1A6)), style: StrokeStyle(lineWidth: len(0.03), lineCap: .round))
        var dashes = Path()
        dashes.move(to: pt(-0.24, -0.26)); dashes.addLine(to: pt(-0.14, -0.2))
        dashes.move(to: pt(-0.26, -0.08)); dashes.addLine(to: pt(-0.14, -0.06))
        dashes.move(to: pt(1.14, -0.2)); dashes.addLine(to: pt(1.24, -0.28))
        strokeLine(dashes, width: len(0.03), color: Palette.coral)
    }

    private func drawTile() {
        let rect = CGRect(origin: pt(0.0, -0.32), size: CGSize(width: len(1.0), height: len(0.24)))
        let tile = Path(roundedRect: rect, cornerRadius: len(0.06))
        strokeLine(tile, width: 2 * halo, color: Self.creamInk)
        context.fill(tile, with: .linearGradient(Gradient(colors: [Color(rgb: 0x6FA0FF), Color(rgb: 0x4C6EF5)]),
                                                 startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        var lines = Path()
        lines.move(to: pt(0.08, -0.24)); lines.addLine(to: pt(0.4, -0.24))
        lines.move(to: pt(0.08, -0.16)); lines.addLine(to: pt(0.3, -0.16))
        strokeLine(lines, width: len(0.03), color: .white.opacity(0.85))
    }
}
// swiftlint:enable identifier_name large_tuple
