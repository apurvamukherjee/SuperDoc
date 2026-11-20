import Foundation

/// Everything Limo can act out. The body never changes shape; only the face, arms and props do.
enum LimoPose: String, CaseIterable, Sendable {
    case idle
    /// The 12 core reactions, in the mockup's order.
    case saysHi, celebrates, handUp, checksGauge, pokesIce, naps
    case vibes, umbrella, fansItself, takesSip, catchesIt, helpsCarry
    /// "Connect Claude": one brow up, a question mark.
    case curious

    /// The pose for an alert that only names its SF Symbol (callers of `LimoController.show(message:symbol:…)`).
    init(alertSymbol symbol: String) {
        self = switch symbol {
        case "exclamationmark.triangle.fill", "snowflake": .pokesIce
        case "hand.raised.fill": .handUp
        case "checkmark.seal.fill", "checkmark.circle.fill": .celebrates
        case "drop.fill", "drop": .takesSip
        case "link", "questionmark.circle": .curious
        case "gauge.with.dots.needle.67percent", "gauge.high": .checksGauge
        default: .saysHi
        }
    }

    static let reactions: [LimoPose] = [
        .saysHi, .celebrates, .handUp, .checksGauge, .pokesIce, .naps,
        .vibes, .umbrella, .fansItself, .takesSip, .catchesIt, .helpsCarry
    ]

    /// What triggers it, as the mockup's card captions it.
    var trigger: String {
        switch self {
        case .idle: "Resting"
        case .saysHi: "Cursor nears bar"
        case .celebrates: "Agent done"
        case .handUp: "Needs input"
        case .checksGauge: "Limit ≥ 80%"
        case .pokesIce: "App frozen"
        case .naps: "Nothing running"
        case .vibes: "Music plays"
        case .umbrella: "Rain soon"
        case .fansItself: "CPU / thermal hot"
        case .takesSip: "Hydration time"
        case .catchesIt: "⌘C"
        case .helpsCarry: "Dragging a tile"
        case .curious: "Connect Claude"
        }
    }

    var title: String {
        switch self {
        case .idle: "Rests"
        case .saysHi: "Says hi"
        case .celebrates: "Celebrates"
        case .handUp: "Hand up"
        case .checksGauge: "Checks the gauge"
        case .pokesIce: "Pokes the ice"
        case .naps: "Naps"
        case .vibes: "Vibes"
        case .umbrella: "Umbrella"
        case .fansItself: "Fans itself"
        case .takesSip: "Takes a sip"
        case .catchesIt: "Catches it"
        case .helpsCarry: "Helps carry"
        case .curious: "Wonders"
        }
    }

    var look: LimoLook {
        switch self {
        case .idle: LimoLook(eyes: .open, mouth: .smile)
        case .saysHi: LimoLook(eyes: .open, mouth: .smile, right: .wave)
        case .celebrates: LimoLook(eyes: .happy, mouth: .grin, left: .raised, right: .raised, props: [.confetti])
        case .handUp: LimoLook(eyes: .open, mouth: .gasp, right: .raised, mood: .bright, props: [.alert])
        case .checksGauge:
            LimoLook(eyes: .dots, brows: .angry, mouth: .none, left: .hug, right: .hug, mood: .flushed, props: [.gauge, .drop])
        case .pokesIce: LimoLook(eyes: .dots, brows: .angry, mouth: .wobble, right: .poke, mood: .bright, props: [.ice])
        case .naps: LimoLook(eyes: .sleepy, mouth: .flat, mood: .dim, props: [.nightcap, .snore])
        case .vibes: LimoLook(eyes: .content, mouth: .smile, mood: .hidden, props: [.headphones, .note])
        case .umbrella: LimoLook(eyes: .dots, mouth: .smile, right: .umbrella, mood: .hidden, props: [.umbrella, .rain])
        case .fansItself: LimoLook(eyes: .content, mouth: .wobble, right: .fan, mood: .flushed, props: [.fan, .sweat])
        case .takesSip: LimoLook(eyes: .content, mouth: .none, right: .sip, props: [.glass])
        case .catchesIt: LimoLook(eyes: .open, mouth: .smile, left: .overhead, right: .overhead, props: [.paper])
        case .helpsCarry: LimoLook(eyes: .flat, mouth: .teeth, left: .overhead, right: .overhead, props: [.tile, .drop])
        case .curious: LimoLook(eyes: .dots, brows: .curious, mouth: .dot, right: .hip, props: [.question])
        }
    }
}

/// A pose broken into parts the painter draws.
struct LimoLook: Equatable, Sendable {
    enum Eyes: Sendable { case open, dots, happy, content, sleepy, flat }
    enum Brows: Sendable { case none, angry, curious }
    enum Mouth: Sendable { case none, smile, grin, gasp, dot, wobble, flat, teeth }
    /// Behind-the-body arms hang at the sides; the rest reach across the body and get a cream halo.
    enum Arm: Sendable { case rest, wave, raised, hug, poke, umbrella, fan, sip, overhead, hip }
    /// The coral cheek is the mood light: bright when something needs you, dim asleep, flushed when hot.
    enum Mood: Sendable { case calm, bright, dim, flushed, hidden }
    enum Prop: Sendable {
        case confetti, alert, gauge, drop, ice, nightcap, snore, headphones, note, umbrella, rain, fan, sweat, glass, paper
        case tile, question
    }

    var eyes: Eyes
    var brows: Brows = .none
    var mouth: Mouth
    var left: Arm = .rest
    var right: Arm = .rest
    var mood: Mood = .calm
    var props: [Prop] = []
}

/// How much of Limo the user wants (Settings › Limo). Stored as a raw string so Settings can bind to the key directly.
enum LimoPresence: String, CaseIterable, Sendable {
    /// Ambient gestures, springy pops, eyes that follow the cursor, blink and breath.
    case lively
    /// Pills only, with Limo in them; a gentle fade instead of a spring, blink but no bob, no ambient gestures.
    case calm
    /// No character anywhere; alerts still arrive as plain pills.
    case hidden

    static let storageKey = "limo.presence"

    static var current: LimoPresence {
        UserDefaults.standard.string(forKey: storageKey).flatMap(LimoPresence.init(rawValue:)) ?? .lively
    }
}
