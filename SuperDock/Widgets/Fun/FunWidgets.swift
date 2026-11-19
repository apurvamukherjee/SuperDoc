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
    @State private var result: String?

    var body: some View {
        Button {
            result = settings.mode == .coin
                ? (Bool.random() ? String(localized: "Heads") : String(localized: "Tails"))
                : String(Int.random(in: 1...max(settings.sides, 2)))
        } label: {
            VStack(spacing: 2) {
                Image(systemName: settings.mode == .coin ? "circle.lefthalf.filled" : "dice").font(.title3)
                Text(result ?? (settings.mode == .coin ? "Flip" : "Roll")).font(.callout.weight(.semibold)).tileText()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(result.map { "Result \($0). Tap again." } ?? "Tap to roll")
    }
}

struct EightBallWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "fun.eightBall"
    static var name: String { String(localized: "Magic 8 Ball") }
    static let category = WidgetCategory.fun
    static let symbol = "8.circle"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static let answers = [
        "It is certain", "Without a doubt", "Yes", "Most likely", "Outlook good", "Ask again later",
        "Cannot predict now", "Better not tell you now", "Don't count on it", "My sources say no", "Very doubtful"
    ]

    static func view(size: TileSize, settings: Settings) -> some View {
        EightBallTile()
    }
}

private struct EightBallTile: View {
    @State private var answer: String?

    var body: some View {
        Button { answer = EightBallWidget.answers.randomElement() } label: {
            Text(answer.map { LocalizedStringKey($0) } ?? "Ask, then tap")
                .font(.caption.weight(.medium)).multilineTextAlignment(.center).tileText()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}
