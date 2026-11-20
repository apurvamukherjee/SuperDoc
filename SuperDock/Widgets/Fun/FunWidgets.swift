import SwiftUI

struct DiceWidget: SuperWidget {
    enum Mode: String, Codable, CaseIterable { case dice, coin }
    struct Settings: Codable, Equatable {
        var mode = Mode.dice
        var sides = 6
    }
    static let id = "fun.dice"
    static var name: String { String(localized: "Dice / Coin Flip") }
    static let category = WidgetCategory.fun
    static let symbol = "dice"
    static let supportedSizes: [TileSize] = [.compact]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        RollTile(settings: settings)
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(VStack(alignment: .leading) {
            Picker("Mode", selection: settings.mode) {
                Text("Dice").tag(Mode.dice)
                Text("Coin").tag(Mode.coin)
            }
            .pickerStyle(.segmented).fixedSize()
            if settings.wrappedValue.mode == .dice {
                Stepper("Sides: \(settings.wrappedValue.sides)", value: settings.sides, in: 2...100)
            }
        })
    }
}

private struct RollTile: View {
    let settings: DiceWidget.Settings
    @State private var result: Int?
    @State private var rolls = 0

    var body: some View {
        Button {
            result = settings.mode == .coin ? Int.random(in: 0...1) : Int.random(in: 1...max(settings.sides, 2))
            rolls += 1
        } label: {
            Group {
                if settings.mode == .coin {
                    CoinView(heads: result.map { $0 == 1 } ?? true, flips: rolls)
                } else {
                    DieView(face: result ?? 5, flips: rolls)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(TilePressStyle())
        .accessibilityLabel(label)
    }

    private var label: String {
        guard let result else { return settings.mode == .coin ? "Tap to flip" : "Tap to roll" }
        let text = settings.mode == .coin ? (result == 1 ? String(localized: "Heads") : String(localized: "Tails")) : "\(result)"
        return "Result \(text). Tap again."
    }
}

/// Drives one throw: hop, spin and squash, ending where it started so the tile rests on a still frame.
private struct Throw {
    var angle = 0.0
    var lift = 0.0
    var scale = 1.0
}

/// Plays the throw each time `flips` changes; under Reduce Motion the face just crossfades. `flipsOver` turns the
/// view over its horizontal axis (a coin) instead of spinning it flat (a die).
private struct ThrowModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let flips: Int
    let turns: Double
    let flipsOver: Bool
    let travel: CGFloat

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: Throw(), trigger: reduceMotion ? 0 : flips) { view, value in
            view.rotation3DEffect(.degrees(value.angle), axis: flipsOver ? (x: 1, y: 0, z: 0) : (x: 0, y: 0, z: 1),
                                  perspective: flipsOver ? 0.4 : 0)
                .scaleEffect(value.scale)
                .offset(y: value.lift * travel)
        } keyframes: { _ in
            KeyframeTrack(\.angle) { CubicKeyframe(360 * turns, duration: 0.6) }
            KeyframeTrack(\.lift) {
                SpringKeyframe(-1, duration: 0.25)
                SpringKeyframe(0, duration: 0.35, spring: .bouncy)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.82, duration: 0.2)
                SpringKeyframe(1, duration: 0.45, spring: .bouncy)
            }
        }
    }
}

/// A white die tipped a few degrees, ink pips, the centre pip coral like the app icon's cheek. Above six sides it shows
/// the number instead.
struct DieView: View {
    @Environment(\.tile) private var tile
    var face: Int
    var flips = 0

    var body: some View {
        let side = tile.contentSize.height * 0.64
        let shape = RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [.white, Color(rgb: 0xE3E3E8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.35), radius: 3 * tile.scale, y: 2 * tile.scale)
            shape.strokeBorder(.white.opacity(0.9), lineWidth: 0.75)
            if (1...6).contains(face) {
                pips(side: side)
            } else {
                Text("\(face)").font(.system(size: side * 0.48, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.ink).minimumScaleFactor(0.5).padding(side * 0.08)
            }
        }
        .frame(width: side, height: side)
        .rotationEffect(.degrees(-9))
        .modifier(ThrowModifier(flips: flips, turns: 1, flipsOver: false, travel: side * 0.25))
        .tileAnimation(value: face)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pips(side: CGFloat) -> some View {
        let layout: [Int: [(Int, Int)]] = [
            1: [(1, 1)], 2: [(0, 0), (2, 2)], 3: [(0, 0), (1, 1), (2, 2)], 4: [(0, 0), (2, 0), (0, 2), (2, 2)],
            5: [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)], 6: [(0, 0), (2, 0), (0, 1), (2, 1), (0, 2), (2, 2)]
        ]
        let pip = side * 0.17
        let step = side * 0.27
        return ZStack {
            ForEach(Array((layout[face] ?? []).enumerated()), id: \.offset) { _, spot in
                Circle().fill(spot == (1, 1) ? Palette.coral : Palette.inkDeep)
                    .frame(width: pip, height: pip)
                    .offset(x: CGFloat(spot.0 - 1) * step, y: CGFloat(spot.1 - 1) * step)
            }
        }
    }
}

/// A gold coin; the flip turns it over on its horizontal axis three times.
struct CoinView: View {
    @Environment(\.tile) private var tile
    var heads: Bool
    var flips = 0

    var body: some View {
        let side = tile.contentSize.height * 0.66
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(rgb: 0xFFE08A), Color(rgb: 0xF2B632), Color(rgb: 0xC98A12)],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: side * 0.7))
                .shadow(color: .black.opacity(0.35), radius: 3 * tile.scale, y: 2 * tile.scale)
            Circle().strokeBorder(Color(rgb: 0xB37A0C).opacity(0.55), lineWidth: side * 0.05).padding(side * 0.08)
            Text(heads ? "H" : "T").font(.system(size: side * 0.42, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(rgb: 0x7A4A05))
        }
        .frame(width: side, height: side)
        .modifier(ThrowModifier(flips: flips, turns: 3, flipsOver: true, travel: side * 0.3))
        .tileAnimation(value: heads)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EightBallWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "fun.eightBall"
    static var name: String { String(localized: "Magic 8 Ball") }
    static let category = WidgetCategory.fun
    static let symbol = "8.circle"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    struct Answer: Equatable {
        enum Kind { case positive, neutral, negative }
        var text: String
        var kind: Kind

        /// What fits on the die's triangle in a compact tile.
        var short: String {
            switch kind {
            case .positive: String(localized: "Yes")
            case .neutral: String(localized: "Later")
            case .negative: String(localized: "No")
            }
        }
    }

    /// The classic twenty: ten yes, five noncommittal, five no.
    static let answers: [Answer] = [
        "It is certain", "It is decidedly so", "Without a doubt", "Yes, definitely", "You may rely on it",
        "As I see it, yes", "Most likely", "Outlook good", "Yes", "Signs point to yes"
    ].map { Answer(text: $0, kind: .positive) } + [
        "Reply hazy, try again", "Ask again later", "Better not tell you now", "Cannot predict now",
        "Concentrate and ask again"
    ].map { Answer(text: $0, kind: .neutral) } + [
        "Don't count on it", "My reply is no", "My sources say no", "Outlook not so good", "Very doubtful"
    ].map { Answer(text: $0, kind: .negative) }

    static func view(size: TileSize, settings: Settings) -> some View {
        EightBallTile()
    }
}

private struct EightBallTile: View {
    @State private var answer: EightBallWidget.Answer?
    @State private var asks = 0

    var body: some View {
        Button {
            answer = EightBallWidget.answers.randomElement()
            asks += 1
        } label: {
            EightBallView(answer: answer, asks: asks).contentShape(Rectangle())
        }
        .buttonStyle(TilePressStyle())
    }
}

/// Compact: the die floats up into the window. Medium: the ball beside the answer text.
struct EightBallView: View {
    @Environment(\.tile) private var tile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var answer: EightBallWidget.Answer?
    var asks = 0

    var body: some View {
        Group {
            if tile.isCompact {
                ball(side: tile.contentSize.height * 0.78, showsDie: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tile.isPortrait {
                VStack(spacing: 6 * tile.scale) {
                    ball(side: tile.contentSize.width * 0.85, showsDie: true)
                    answerText(lines: 4).multilineTextAlignment(.center)
                    Spacer(minLength: 0)
                }
                .tileAnimation(Motion.settle, value: asks)
            } else {
                HStack(spacing: 9 * tile.scale) {
                    ball(side: tile.contentSize.height * 0.76, showsDie: false)
                    VStack(alignment: .leading, spacing: 2 * tile.scale) {
                        answerText(lines: 2)
                        Text(answer == nil ? "Think of a question" : "Tap to ask again").tileStyle(.detail).minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 0)
                }
                .tileAnimation(Motion.settle, value: asks)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(answer.map { "Magic 8 Ball says: \($0.text). Tap to ask again." } ?? "Magic 8 Ball. Ask, then tap.")
        .accessibilityAddTraits(.isButton)
    }

    private func answerText(lines: Int) -> some View {
        Text(LocalizedStringKey(answer?.text ?? "Ask, then tap")).lineLimit(lines).tileStyle(.title).minimumScaleFactor(0.85)
            .id(asks)
            .transition(.opacity.combined(with: .offset(y: 4 * tile.scale)))
    }

    private func ball(side: CGFloat, showsDie: Bool) -> some View {
        let window = side * 0.5
        return ZStack {
            Circle().fill(RadialGradient(colors: [Color(rgb: 0x4A4C55), Color(rgb: 0x16171B), .black],
                                         center: UnitPoint(x: 0.32, y: 0.26), startRadius: 0, endRadius: side * 0.62))
                .shadow(color: .black.opacity(0.4), radius: 3 * tile.scale, y: 2 * tile.scale)
            Circle().fill(RadialGradient(colors: [Color(rgb: 0x16205A), Color(rgb: 0x070B24)],
                                         center: .center, startRadius: 0, endRadius: window * 0.5))
                .overlay(Circle().strokeBorder(.black.opacity(0.6), lineWidth: side * 0.02))
                .frame(width: window, height: window)
            if showsDie, let answer {
                Triangle(text: answer.short, side: window * 0.82)
                    .id(asks)
                    .transition(.asymmetric(insertion: reduceMotion ? .opacity
                                                : .scale(scale: 0.3).combined(with: .opacity).animation(Motion.pop.delay(0.15)),
                                            removal: .opacity))
            }
        }
        .frame(width: side, height: side)
        .keyframeAnimator(initialValue: 0.0, trigger: reduceMotion ? 0 : asks) { view, shake in
            view.offset(x: shake * side * 0.06)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-1, duration: 0.05)
                LinearKeyframe(1, duration: 0.08)
                LinearKeyframe(-0.6, duration: 0.08)
                LinearKeyframe(0.3, duration: 0.07)
                SpringKeyframe(0, duration: 0.2)
            }
        }
        .tileAnimation(value: asks)
    }
}

/// The blue die face that surfaces in the window, point down, with the answer printed on it.
private struct Triangle: View {
    let text: String
    let side: CGFloat

    var body: some View {
        ZStack {
            DownTriangle().fill(LinearGradient(colors: [Color(rgb: 0x4F6BFF), Color(rgb: 0x2A3FD1)], startPoint: .top, endPoint: .bottom))
            Text(text.uppercased()).font(.system(size: side * 0.2, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).minimumScaleFactor(0.5).lineLimit(1)
                .frame(width: side * 0.62).offset(y: -side * 0.12)
        }
        .frame(width: side, height: side * 0.86)
        .offset(y: side * 0.04)
    }
}

private struct DownTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
