import SwiftUI

struct BatteryWidget: SuperWidget {
    typealias Settings = NoSettings

    static let id = "system.battery"
    static var name: String { String(localized: "Battery") }
    static let category = WidgetCategory.system
    static let symbol = "battery.100percent"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        BatteryTile(size: size)
    }
}

private struct BatteryTile: View {
    let size: TileSize
    private let stats = SystemStatsService.shared

    var body: some View {
        Group {
            if let battery = stats.battery {
                VStack(spacing: 2) {
                    Image(systemName: symbol(for: battery))
                        .font(.title3)
                        .foregroundStyle(battery.level < 0.2 && !battery.isOnPower ? .red : .primary)
                    Text(battery.level, format: .percent.precision(.fractionLength(0)))
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                    if size == .medium { Text(detail(for: battery)).font(.caption2).foregroundStyle(.secondary) }
                }
                .tileText()
            } else {
                Image(systemName: "powerplug").font(.title3).accessibilityLabel("No battery")
            }
        }
        .subscribes(to: .battery)
    }

    private func symbol(for battery: SystemStatsService.Battery) -> String {
        if battery.isCharging { return "battery.100percent.bolt" }
        let steps = [(0.875, "100"), (0.625, "75"), (0.375, "50"), (0.125, "25")]
        return "battery.\(steps.first { battery.level >= $0.0 }?.1 ?? "0")percent"
    }

    private func detail(for battery: SystemStatsService.Battery) -> String {
        if battery.isCharging { return String(localized: "Charging") }
        if battery.isOnPower { return String(localized: "On power") }
        guard let minutes = battery.minutesRemaining else { return String(localized: "Estimating…") }
        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }
}
