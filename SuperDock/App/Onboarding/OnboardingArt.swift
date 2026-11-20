import SwiftUI

// Plotting code: x/y are the clearest names for coordinates.
// swiftlint:disable identifier_name

/// Limo for onboarding: any `LimoLook` (the steps need looks that aren't app-wide poses), or holding the
/// Accessibility key. Static, with no blink timer, so a step that's just sitting there costs nothing.
struct OnboardingLimo: View {
    let look: LimoLook
    var gaze: CGVector = .zero
    var outlined = true
    var holdsKey = false

    var body: some View {
        Canvas { context, size in
            guard holdsKey else {
                LimoPainter(context: context, size: size, look: look, gaze: gaze, blinking: false, outlined: outlined,
                            faceOnly: false).draw()
                return
            }
            // Face-only geometry skips the side arms, which would stick out past the hands holding the key.
            // Scaled and moved so the body lands exactly where the full figure's would.
            let box = size.width * 0.54 / 0.86
            var layer = context
            layer.translateBy(x: (size.width - box) / 2, y: size.width * 0.24 - box * (1 - 0.86 * LimoPainter.bodyAspect) / 2)
            let painter = LimoPainter(context: layer, size: CGSize(width: box, height: box), look: look, gaze: gaze,
                                      blinking: false, outlined: outlined, faceOnly: true)
            painter.drawFeet()
            painter.draw()
            painter.drawKeyInHands()
        }
        .accessibilityHidden(true)
    }
}

private extension LimoPainter {
    func drawFeet() {
        var feet = Path()
        for x in [0.2, 0.58] as [CGFloat] {
            feet.addRoundedRect(in: CGRect(origin: pt(x, bodyHeight / unit - 0.04), size: CGSize(width: len(0.22), height: len(0.1))),
                                cornerSize: CGSize(width: len(0.05), height: len(0.05)))
        }
        context.fill(feet, with: .color(Palette.inkDeep))
    }

    func drawKeyInHands() {
        let width = len(0.075)
        let haloWidth = width + len(0.09)
        let center = pt(0.5, 0.84)
        let ring = len(0.12)
        var stem = Path()
        stem.move(to: CGPoint(x: center.x, y: center.y + ring * 0.6))
        stem.addLine(to: pt(0.5, 1.13))
        stem.move(to: pt(0.5, 1.07))
        stem.addLine(to: pt(0.59, 1.07))
        strokeLine(stem, width: haloWidth, color: Self.creamInk)
        context.fill(circle(center, ring + len(0.045)), with: .color(Self.creamInk))
        strokeLine(stem, width: width, color: Palette.claude)
        context.fill(circle(center, ring), with: .color(Palette.claude))
        context.fill(circle(center, len(0.045)), with: .color(Palette.inkDeep))
        var arms = Path()
        for mirrored in [false, true] {
            let at = { (x: CGFloat, y: CGFloat) in pt(mirrored ? 1 - x : x, y) }
            arms.move(to: at(0.96, 0.5))
            arms.addCurve(to: at(0.62, 0.86), control1: at(1.0, 0.72), control2: at(0.8, 0.86))
        }
        strokeLine(arms, width: haloWidth, color: Self.creamInk)
        strokeLine(arms, width: width, color: Palette.inkDeep)
    }
}

/// The dark "desktop" behind the live previews: navy with the coral and violet glows of the app's wallpaper.
struct OnboardingHeroPanel: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(rgb: 0x262257), Color(rgb: 0x1E2B55), Color(rgb: 0x183150)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(rgb: 0xFF6A6A).opacity(0.9), Color(rgb: 0xFF6A6A).opacity(0)],
                           center: UnitPoint(x: 0.08, y: 0.06), startRadius: 0, endRadius: 200)
            RadialGradient(colors: [Color(rgb: 0x7C5CFF), Color(rgb: 0x7C5CFF).opacity(0)],
                           center: .bottomTrailing, startRadius: 0, endRadius: 170)
        }
    }
}

struct OnboardingLivePreviewChip: View {
    var body: some View {
        Text(String(localized: "Live preview"))
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: 18)
            .background(Color(rgb: 0x141A38).opacity(0.85), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .padding(.top, 27)
            .padding(.trailing, 22.5)
    }
}

/// A mini Dock with the bar beside or above it, and Limo pointing at the bar.
struct OnboardingPlacementPreview: View {
    let position: BarPosition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let dockSize = CGSize(width: 150, height: 37.5)
    private static let barSize = CGSize(width: 113, height: 41)
    private static let dockY: CGFloat = 191.25
    /// Centre of Limo's 112 pt canvas when its feet rest on the Dock's top edge.
    private static let limoOnDockY: CGFloat = 140.9

    private struct Spots {
        let dockX: CGFloat
        let bar: CGPoint
        let limo: CGPoint
        let look: LimoLook
        let gaze: CGVector
    }

    private var spots: Spots {
        switch position {
        case .trailing:
            return Spots(dockX: 105.5, bar: CGPoint(x: 241.5, y: Self.dockY), limo: CGPoint(x: 118.5, y: Self.limoOnDockY),
                         look: LimoLook(eyes: .open, mouth: .smile, right: .hip), gaze: CGVector(dx: 0.9, dy: 0.2))
        case .leading:
            return Spots(dockX: 274.5, bar: CGPoint(x: 138.5, y: Self.dockY), limo: CGPoint(x: 261.5, y: Self.limoOnDockY),
                         look: LimoLook(eyes: .open, mouth: .smile, left: .hip), gaze: CGVector(dx: -0.9, dy: 0.2))
        case .outside:
            // Limo steps off the Dock to stand beside it and reach up at the bar.
            return Spots(dockX: 190, bar: CGPoint(x: 190, y: 149.25), limo: CGPoint(x: 300, y: 178.4),
                         look: LimoLook(eyes: .open, mouth: .smile, left: .raised), gaze: CGVector(dx: -0.7, dy: -0.7))
        }
    }

    var body: some View {
        let spots = spots
        let preview = ZStack {
            MiniDock().position(x: spots.dockX, y: Self.dockY)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(rgb: 0x222E78), Color(rgb: 0x3434B6)], startPoint: .leading, endPoint: .trailing))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.coral, lineWidth: 2))
                .frame(width: Self.barSize.width, height: Self.barSize.height)
                .position(spots.bar)
            OnboardingLimo(look: spots.look, gaze: spots.gaze)
                .frame(width: 112, height: 112)
                .position(spots.limo)
        }
        .frame(width: OnboardingTheme.windowSize.width, height: OnboardingTheme.heroHeight)
        if reduceMotion {
            preview.id(position).transition(.opacity)
        } else {
            preview
        }
    }

    private struct MiniDock: View {
        private static let icons: [UInt32] = [0x7CC3FF, 0x5EE7D0, 0x34373F, 0xFF8A8A]

        var body: some View {
            HStack(spacing: 4) {
                ForEach(Self.icons, id: \.self) { rgb in
                    RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(rgb: rgb)).frame(width: 26, height: 26)
                }
            }
            .frame(width: OnboardingPlacementPreview.dockSize.width, height: OnboardingPlacementPreview.dockSize.height)
            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.28)))
        }
    }
}

/// The starter set as it will look on the bar: one coloured block per tile, sized by columns.
struct OnboardingStarterPreview: View {
    let starter: StarterSet

    private static let unit: CGFloat = 39
    private static let gap: CGFloat = 4.5

    var body: some View {
        HStack(spacing: Self.gap) {
            if starter.items.isEmpty {
                Color.clear.frame(width: 2 * Self.unit + Self.gap, height: 42)
            }
            ForEach(starter.items, id: \.widgetId) { item in
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(item.tint)
                    .frame(width: CGFloat(item.size.columns) * Self.unit + CGFloat(item.size.columns - 1) * Self.gap, height: 42)
            }
        }
        .padding(4)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(rgb: 0x6E72E8).opacity(0.55), lineWidth: 1.5))
    }
}

/// An illustration of the switch to flip, not a real control (and ImageRenderer can't draw AppKit toggles).
struct OnboardingSettingsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "System Settings › Privacy & Security › Accessibility"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OnboardingTheme.label)
                .lineLimit(1)
                .padding(.top, 9)
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(rgb: 0xF5F1E8))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Palette.ink.opacity(0.12), lineWidth: 0.5))
                    .overlay {
                        UnevenRoundedRectangle(topLeadingRadius: 2, bottomLeadingRadius: 2, bottomTrailingRadius: 6,
                                               topTrailingRadius: 6, style: .continuous)
                            .fill(OnboardingTheme.ink)
                            .frame(width: 12, height: 11.5)
                            .offset(y: 2)
                    }
                    .frame(width: 26, height: 26)
                Text(verbatim: "SuperDock").font(.system(size: 13, weight: .semibold)).foregroundStyle(OnboardingTheme.ink)
                Spacer(minLength: 0)
                Capsule().fill(Palette.done)
                    .overlay(alignment: .trailing) { Circle().fill(.white).padding(2) }
                    .frame(width: 34, height: 20)
            }
            .padding(.horizontal, 6)
            .frame(height: 38)
            .background(Palette.coral.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.top, 7.5)
        }
        .padding(.horizontal, 12)
        .frame(width: 320, height: 78.5, alignment: .top)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.ink.opacity(0.06)))
        .shadow(color: Palette.ink.opacity(0.08), radius: 14, y: 5)
        .accessibilityHidden(true)
    }
}

/// Turns once per Accessibility poll, so it adds no timer; static under Reduce Motion.
struct OnboardingSpinner: View {
    let spins: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(Palette.ink.opacity(0.15), lineWidth: 1.6)
            Circle().trim(from: 0, to: 0.28)
                .stroke(Palette.coral, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .rotationEffect(.degrees(Double(spins) * 360 + 180))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: spins)
        }
        .frame(width: 11, height: 11)
    }
}

/// One burst when Finish is pressed. Under Reduce Motion the bits appear where they'd land, without flying.
struct OnboardingConfetti: View {
    let fired: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var launched = false
    @State private var faded = false

    private struct Bit {
        let angle: Double
        let distance: CGFloat
        let color: Color
        let dash: Bool
    }

    private static let colors = [Palette.claude, Palette.coral, Palette.codex, Palette.good, Palette.progress]
    private static let bits: [Bit] = (0..<18).map { (index: Int) -> Bit in
        let angle = Double(index * 20 + (index % 3) * 7)
        let distance = CGFloat(70 + (index % 4) * 22)
        return Bit(angle: angle, distance: distance, color: colors[index % colors.count], dash: index.isMultiple(of: 2))
    }

    var body: some View {
        ZStack {
            ForEach(Self.bits.indices, id: \.self) { index in
                let bit = Self.bits[index]
                let out = launched || reduceMotion ? bit.distance : 0
                Group {
                    if bit.dash { Capsule().frame(width: 9, height: 3.5) } else { Circle().frame(width: 6, height: 6) }
                }
                .foregroundStyle(bit.color)
                .rotationEffect(.degrees(launched ? bit.angle * 2 : bit.angle))
                .offset(x: cos(bit.angle * .pi / 180) * out, y: sin(bit.angle * .pi / 180) * out)
            }
        }
        .opacity(launched && !faded ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: fired) { _, isFired in
            guard isFired else { return }
            withAnimation(reduceMotion ? Motion.reduced : .easeOut(duration: 0.8)) { launched = true }
            withAnimation(.easeIn(duration: 0.3).delay(0.5)) { faded = true }
        }
    }
}
// swiftlint:enable identifier_name
