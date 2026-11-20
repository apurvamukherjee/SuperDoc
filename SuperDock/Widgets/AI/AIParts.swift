import SwiftUI

/// Provider identity without brand marks: a rounded square in the provider's colour holding its monogram.
struct ProviderBadge: View {
    @Environment(\.tile) private var tile
    var provider: AIProvider
    var dimmed = false

    var body: some View {
        let side = 12 * tile.scale
        Text(provider.monogram)
            .font(tile.font(.badge))
            .foregroundStyle(provider.monogramInk)
            .frame(width: side, height: side)
            .background(provider.tint, in: RoundedRectangle(cornerRadius: 3 * tile.scale, style: .continuous))
            .opacity(dimmed ? 0.45 : 1)
            .accessibilityHidden(true)
    }
}

/// The ≥ 80 % mark, so danger is never colour alone.
struct DangerGlyph: View {
    @Environment(\.tile) private var tile
    var style = TileTextStyle.detail

    var body: some View {
        Image(systemName: tile.surface.isDark ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
            .font(tile.font(style).weight(.bold))
            .foregroundStyle(tile.surface.danger)
            .accessibilityHidden(true)
    }
}

/// A fuel bar with a hairline at 80 %, so the danger zone shows before you reach it. Danger bars glow coral.
struct LimitMeter: View {
    @Environment(\.tile) private var tile
    var fraction: Double
    var color: Color
    var marker: Double?
    var glows = false

    var body: some View {
        let side = 4 * tile.scale
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tile.surface.track)
                Capsule().fill(color)
                    .frame(width: max(side, geo.size.width * fraction.unitClamped))
                    .shadow(color: glows ? Palette.coral.opacity(0.55) : .clear, radius: 4 * tile.scale)
                if let marker {
                    Capsule().fill(tile.surface.secondary)
                        .frame(width: max(1, 1.2 * tile.scale), height: side + 4 * tile.scale)
                        .offset(x: geo.size.width * marker.unitClamped)
                }
            }
            .frame(height: side)
        }
        .frame(height: side)
        .tileAnimation(value: fraction)
        .accessibilityHidden(true)
    }
}

/// "2h 14m" with the digits at `style` and the unit letters smaller, like the hero numerals elsewhere.
struct DurationText: View {
    @Environment(\.tile) private var tile
    var text: String
    var style = TileTextStyle.hero
    var color: Color?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
                Text(run.text).font(tile.font(run.isNumber ? style : .heroUnit))
            }
        }
        .foregroundStyle(color ?? tile.surface.primary)
        .lineLimit(1)
        .fixedSize()
    }

    private var runs: [(text: String, isNumber: Bool)] {
        text.reduce(into: []) { runs, character in
            let isNumber = character.isNumber || character == ":"
            if let last = runs.last, last.isNumber == isNumber {
                runs[runs.count - 1].text.append(character)
            } else {
                runs.append((String(character), isNumber))
            }
        }
    }
}

enum AIFormat {
    /// "2h 14m", "38m", "3d 4h".
    static func countdown(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(seconds, 60))
            .formatted(.units(allowed: [.days, .hours, .minutes], width: .narrow, maximumUnitCount: 2))
    }

    /// "2:14" for the compact resets readout; whole days past 24 h.
    static func clock(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(seconds, 60) / 60)
        return minutes >= 24 * 60 ? countdown(seconds) : String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}
