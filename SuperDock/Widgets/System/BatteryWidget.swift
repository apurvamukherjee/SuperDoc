import SwiftUI

struct BatteryWidget: SuperWidget {
    typealias Settings = NoSettings

    static let id = "system.battery"
    static var name: String { String(localized: "Battery") }
    static let category = WidgetCategory.system
    static let symbol = "battery.100percent"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        BatteryTile()
    }
}

private struct BatteryTile: View {
    private let stats = SystemStatsService.shared

    var body: some View {
        BatteryTileView(battery: stats.battery)
            .subscribes(to: .battery)
    }
}

/// Glyph archetype at C, glyph beside a hero at M. `battery == nil` is a desktop Mac: a plug, "On power".
struct BatteryTileView: View {
    @Environment(\.tile) private var tile
    var battery: SystemStatsService.Battery?

    var body: some View {
        if let battery {
            reading(battery)
        } else {
            GlyphTile(caption: String(localized: "On power"), title: String(localized: "On power"),
                      details: [String(localized: "No battery")]) {
                TileSymbol(name: "powerplug.portrait", color: tile.surface.primary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("No battery, on power")
        }
    }

    @ViewBuilder private func reading(_ battery: SystemStatsService.Battery) -> some View {
        let isLow = battery.level < 0.2 && !battery.isOnPower
        let level = SystemFormat.percent(battery.level)
        let ink = isLow ? tile.surface.danger : tile.surface.primary
        let glyph = BatteryGlyph(level: battery.level, isCharging: battery.isCharging, isOnPower: battery.isOnPower, isLow: isLow)
        Group {
            if tile.isCompact || tile.isPortrait {
                VStack(spacing: 4 * tile.scale) {
                    Spacer(minLength: 0)
                    glyph.frame(width: tile.contentSize.width * 0.62)
                    Text(level).tileStyle(.heroCompact, color: ink)
                    if tile.isPortrait {
                        Text(detail(battery, isLow: isLow)).lineLimit(2).multilineTextAlignment(.center).tileStyle(.detail)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 9 * tile.scale) {
                    glyph.frame(width: tile.contentSize.width * 0.3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(level).tileStyle(.hero, color: ink)
                        Text(detail(battery, isLow: isLow)).tileStyle(.detail, color: isLow ? tile.surface.danger : nil)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 2 * tile.scale)
                .frame(maxHeight: .infinity)
            }
        }
        .tileTint(isLow ? Palette.coral : nil, opacity: 0.16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery")
        .accessibilityValue("\(level), \(detail(battery, isLow: isLow))")
    }

    private func detail(_ battery: SystemStatsService.Battery, isLow: Bool) -> String {
        let format = { (minutes: Int) in
            Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
        }
        if battery.isCharging {
            return battery.minutesToFull.map { String(localized: "Full in \(format($0))") } ?? String(localized: "Charging")
        }
        if battery.isOnPower { return battery.level >= 0.99 ? String(localized: "Charged") : String(localized: "On power") }
        let left = battery.minutesRemaining.map { String(localized: "\(format($0)) left") } ?? String(localized: "Estimating…")
        return isLow ? String(localized: "Low · \(left)") : left
    }
}

/// A drawn battery: the fill is the real level, so "low" reads from the shape as well as the colour.
struct BatteryGlyph: View {
    @Environment(\.tile) private var tile
    var level: Double
    var isCharging: Bool
    var isOnPower: Bool
    var isLow: Bool

    var body: some View {
        let line = 1.6 * tile.scale
        let fill = isLow ? tile.surface.danger : isOnPower ? Palette.good : tile.surface.primary
        HStack(spacing: line) {
            GeometryReader { geo in
                let inset = line + 1.4 * tile.scale
                let inner = geo.size.width - 2 * inset
                RoundedRectangle(cornerRadius: geo.size.height * 0.26, style: .continuous)
                    .strokeBorder(isLow ? tile.surface.danger : tile.surface.tertiary, lineWidth: line)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: geo.size.height * 0.14, style: .continuous)
                            .fill(fill)
                            .frame(width: max(inner * level.unitClamped, 2 * tile.scale))
                            .padding(inset)
                            .tileAnimation(value: level)
                    }
                    .overlay {
                        if isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: geo.size.height * 0.42, weight: .bold))
                                .foregroundStyle(.white)
                                .symbolEffect(.bounce, value: isCharging)
                        }
                    }
            }
            RoundedRectangle(cornerRadius: line, style: .continuous)
                .fill(isLow ? tile.surface.danger : tile.surface.tertiary)
                .frame(width: line * 1.6)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 8 * tile.scale)
        }
        .aspectRatio(2.1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
