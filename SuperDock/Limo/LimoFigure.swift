import SwiftUI

// Plotting code: x/y/dx/dy are the clearest names for coordinates.
// swiftlint:disable identifier_name

/// Limo, drawn as vector paths in one Canvas: the app icon's ink D-face with tiny arms and feet.
/// A pure function of its inputs, so it costs nothing until one of them changes.
struct LimoFigure: View {
    var pose: LimoPose = .idle
    /// Overrides the pose's cheek, e.g. flushed while the CPU runs hot whatever Limo is doing.
    var mood: LimoLook.Mood?
    /// Where the pupils look, each axis −1…1 (+x right, +y down).
    var gaze: CGVector = .zero
    var blinking = false
    /// Cream outline around the silhouette, for dark surfaces (the app icon's cream ground).
    var outlined = true
    /// Face only (empty states, small glyphs): no arms, feet or props.
    var faceOnly = false

    var body: some View {
        Canvas { context, size in
            var look = pose.look
            if let mood { look.mood = mood }
            LimoPainter(context: context, size: size, look: look, gaze: gaze, blinking: blinking,
                        outlined: outlined, faceOnly: faceOnly).draw()
        }
        .accessibilityHidden(true)
    }
}

/// Body-relative drawing: every coordinate is a fraction of the body's width, measured from its top-left corner.
struct LimoPainter {
    static let creamInk = Palette.cream
    static let bodyAspect: CGFloat = 0.96

    let context: GraphicsContext
    let look: LimoLook
    let gaze: CGVector
    let blinking: Bool
    let outlined: Bool
    let faceOnly: Bool
    /// Body origin and width.
    let origin: CGPoint
    let unit: CGFloat
    let bodyHeight: CGFloat

    init(context: GraphicsContext, size: CGSize, look: LimoLook, gaze: CGVector, blinking: Bool, outlined: Bool,
         faceOnly: Bool) {
        let side = min(size.width, size.height)
        let width = faceOnly ? side * 0.86 : side * 0.54
        let height = width * Self.bodyAspect
        let top = faceOnly ? (size.height - height) / 2 : (size.height - side) / 2 + side * 0.24
        (self.context, self.look, self.gaze, self.blinking, self.outlined, self.faceOnly) =
            (context, look, gaze, blinking, outlined, faceOnly)
        origin = CGPoint(x: (size.width - width) / 2, y: top)
        unit = width
        bodyHeight = height
    }

    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * unit, y: origin.y + y * unit) }
    func len(_ value: CGFloat) -> CGFloat { value * unit }
    /// Feature point nudged toward the gaze, so the whole face turns a little, not just the pupils.
    func face(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        pt(x + gaze.dx * 0.03, y + gaze.dy * 0.02)
    }

    var halo: CGFloat { len(0.045) }
    var armWidth: CGFloat { len(0.075) }

    func draw() {
        let arms = faceOnly ? [] : [(look.left, true), (look.right, false)].map { arm($0.0, mirrored: $0.1) }
        if outlined {
            for arm in arms where !arm.front { strokeLine(arm.path, width: armWidth + 2 * halo, color: Self.creamInk) }
            if !faceOnly { context.fill(feet, with: .color(Self.creamInk)); strokeLine(feet, width: 2 * halo, color: Self.creamInk) }
            context.stroke(bodyPath, with: .color(Self.creamInk), lineWidth: 2 * halo)
        }
        for arm in arms where !arm.front { strokeLine(arm.path, width: armWidth, color: Palette.inkDeep) }
        if !faceOnly { context.fill(feet, with: .color(Palette.inkDeep)) }
        let body = bodyPath
        context.fill(body, with: .linearGradient(Gradient(colors: [Color(rgb: 0x2C2F37), Palette.inkDeep]),
                                                 startPoint: pt(0, 0), endPoint: pt(0, bodyHeight / unit)))
        drawCheek()
        drawEyes()
        drawBrows()
        drawMouth()
        for arm in arms where arm.front {
            strokeLine(arm.path, width: armWidth + 2 * halo, color: Self.creamInk)
            strokeLine(arm.path, width: armWidth, color: Palette.inkDeep)
        }
        drawProps()
    }

    private var bodyPath: Path {
        let rect = CGRect(origin: origin, size: CGSize(width: unit, height: bodyHeight))
        return UnevenRoundedRectangle(topLeadingRadius: len(0.15), bottomLeadingRadius: len(0.15),
                                      bottomTrailingRadius: bodyHeight * 0.49, topTrailingRadius: bodyHeight * 0.49,
                                      style: .continuous).path(in: rect)
    }

    private var feet: Path {
        var path = Path()
        let top = bodyHeight / unit - 0.04
        for x in [0.2, 0.58] as [CGFloat] {
            path.addRoundedRect(in: CGRect(origin: pt(x, top), size: CGSize(width: len(0.22), height: len(0.1))),
                                cornerSize: CGSize(width: len(0.05), height: len(0.05)))
        }
        return path
    }

    func strokeLine(_ path: Path, width: CGFloat, color: Color) {
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    // MARK: Face

    private func drawCheek() {
        let (color, radius): (Color, CGFloat) = switch look.mood {
        case .calm: (Palette.coral, 0.068)
        case .bright: (Color(rgb: 0xFF4A3D), 0.075)
        case .dim: (Palette.coral.opacity(0.45), 0.065)
        case .flushed: (Color(rgb: 0xFF3B30), 0.088)
        case .hidden: (.clear, 0)
        }
        let center = face(0.84, 0.64)
        let size = len(radius)
        context.fill(Path(ellipseIn: CGRect(x: center.x - size, y: center.y - size, width: 2 * size, height: 2 * size)),
                     with: .color(color))
    }

    private func drawEyes() {
        for x in [0.37, 0.64] as [CGFloat] {
            let center = face(x, 0.42)
            switch look.eyes {
            case .open where !blinking:
                let radius = len(0.088)
                context.fill(circle(center, radius), with: .color(Self.creamInk))
                let reach = len(0.04)
                let pupil = CGPoint(x: center.x + gaze.dx * reach, y: center.y + gaze.dy * reach)
                context.fill(circle(pupil, len(0.046)), with: .color(Palette.inkDeep))
            case .dots where !blinking:
                context.fill(circle(center, len(0.058)), with: .color(Self.creamInk))
            case .open, .dots, .flat:
                var dash = Path()
                dash.move(to: CGPoint(x: center.x - len(0.06), y: center.y))
                dash.addLine(to: CGPoint(x: center.x + len(0.06), y: center.y))
                strokeLine(dash, width: len(blinking ? 0.04 : 0.055), color: Self.creamInk)
            case .happy:
                var chevron = Path()
                chevron.move(to: CGPoint(x: center.x - len(0.065), y: center.y + len(0.035)))
                chevron.addLine(to: CGPoint(x: center.x, y: center.y - len(0.03)))
                chevron.addLine(to: CGPoint(x: center.x + len(0.065), y: center.y + len(0.035)))
                strokeLine(chevron, width: len(0.05), color: Self.creamInk)
            case .content, .sleepy:
                let bend: CGFloat = look.eyes == .content ? -0.075 : 0.075
                var arc = Path()
                arc.move(to: CGPoint(x: center.x - len(0.065), y: center.y))
                arc.addQuadCurve(to: CGPoint(x: center.x + len(0.065), y: center.y),
                                 control: CGPoint(x: center.x, y: center.y + len(bend)))
                strokeLine(arc, width: len(0.048), color: Self.creamInk)
            }
        }
    }

    private func drawBrows() {
        var brows = Path()
        switch look.brows {
        case .none: return
        case .angry:
            brows.move(to: face(0.26, 0.25)); brows.addLine(to: face(0.44, 0.31))
            brows.move(to: face(0.75, 0.25)); brows.addLine(to: face(0.57, 0.31))
        case .curious:
            brows.move(to: face(0.56, 0.29)); brows.addLine(to: face(0.73, 0.23))
        }
        strokeLine(brows, width: len(0.048), color: Self.creamInk)
    }

    private func drawMouth() {
        var mouth = Path()
        switch look.mouth {
        case .none: return
        case .smile:
            mouth.move(to: face(0.35, 0.62))
            mouth.addQuadCurve(to: face(0.63, 0.62), control: face(0.49, 0.76))
            strokeLine(mouth, width: len(0.062), color: Self.creamInk)
        case .flat:
            mouth.move(to: face(0.43, 0.65)); mouth.addLine(to: face(0.57, 0.65))
            strokeLine(mouth, width: len(0.05), color: Self.creamInk)
        case .wobble:
            mouth.move(to: face(0.34, 0.66))
            mouth.addQuadCurve(to: face(0.43, 0.66), control: face(0.385, 0.6))
            mouth.addQuadCurve(to: face(0.52, 0.66), control: face(0.475, 0.72))
            mouth.addQuadCurve(to: face(0.61, 0.66), control: face(0.565, 0.6))
            strokeLine(mouth, width: len(0.045), color: Self.creamInk)
        case .gasp:
            let center = face(0.5, 0.66)
            mouth.addEllipse(in: CGRect(x: center.x - len(0.045), y: center.y - len(0.065), width: len(0.09), height: len(0.13)))
            context.fill(mouth, with: .color(Self.creamInk))
        case .dot:
            context.fill(circle(face(0.48, 0.66), len(0.035)), with: .color(Self.creamInk))
        case .grin: drawGrin()
        case .teeth: drawTeeth()
        }
    }

    private func drawGrin() {
        var grin = Path()
        grin.move(to: face(0.3, 0.57))
        grin.addLine(to: face(0.68, 0.57))
        grin.addCurve(to: face(0.49, 0.83), control1: face(0.69, 0.75), control2: face(0.6, 0.83))
        grin.addCurve(to: face(0.3, 0.57), control1: face(0.38, 0.83), control2: face(0.29, 0.75))
        grin.closeSubpath()
        context.fill(grin, with: .color(Self.creamInk))
        var clipped = context
        clipped.clip(to: grin)
        let tongue = face(0.49, 0.79)
        clipped.fill(Path(ellipseIn: CGRect(x: tongue.x - len(0.13), y: tongue.y - len(0.06), width: len(0.26), height: len(0.12))),
                     with: .color(Palette.coral))
    }

    private func drawTeeth() {
        let topLeft = face(0.36, 0.6)
        let rect = CGRect(origin: topLeft, size: CGSize(width: len(0.28), height: len(0.085)))
        context.fill(Path(roundedRect: rect, cornerRadius: len(0.03)), with: .color(Self.creamInk))
        var gaps = Path()
        for step in 1...3 {
            let x = rect.minX + rect.width * CGFloat(step) / 4
            gaps.move(to: CGPoint(x: x, y: rect.minY)); gaps.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        context.stroke(gaps, with: .color(Palette.inkDeep), lineWidth: len(0.022))
    }

    func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
    }
}
// swiftlint:enable identifier_name
