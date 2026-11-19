import SwiftUI

/// Label over a big value, with an optional detail line on bigger tiles. Shared by the simple stat widgets.
struct StatTile: View {
    let label: LocalizedStringKey
    let value: String
    var detail: String?
    var tint: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(tint)
            if let detail { Text(detail).font(.caption2).foregroundStyle(.secondary) }
        }
        .tileText()
        .accessibilityElement(children: .combine)
    }
}

private let bytes = ByteCountFormatStyle(style: .memory)

struct MemoryWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "system.memory"
    static var name: String { String(localized: "Memory") }
    static let category = WidgetCategory.system
    static let symbol = "memorychip"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        let memory = SystemStatsService.shared.memory
        let share = memory.map { Double($0.used) / Double(max($0.total, 1)) }
        return StatTile(label: "RAM", value: share?.formatted(.percent.precision(.fractionLength(0))) ?? "–",
                        detail: size == .compact ? nil : memory.map { "\($0.used.formatted(bytes)) of \($0.total.formatted(bytes))" },
                        tint: memory?.pressure == .critical ? .red : memory?.pressure == .warning ? .orange : .primary)
            .subscribes(to: .memory)
    }
}

struct NetworkWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "system.network"
    static var name: String { String(localized: "Network") }
    static let category = WidgetCategory.system
    static let symbol = "arrow.up.arrow.down"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        let stats = SystemStatsService.shared
        let rate = { (value: Double?) in value.map { "\(Int64($0).formatted(.byteCount(style: .file)))/s" } ?? "–" }
        return VStack(alignment: .leading, spacing: 4) {
            Label(rate(stats.download), systemImage: "arrow.down").accessibilityLabel("Download \(rate(stats.download))")
            Label(rate(stats.upload), systemImage: "arrow.up").accessibilityLabel("Upload \(rate(stats.upload))")
        }
        .font(size == .compact ? .caption2.monospacedDigit() : .callout.monospacedDigit())
        .tileText()
        .subscribes(to: .network)
    }
}

struct DiskWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "system.disk"
    static var name: String { String(localized: "Disk") }
    static let category = WidgetCategory.system
    static let symbol = "internaldrive"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        let disk = SystemStatsService.shared.disk
        return StatTile(label: "Free", value: disk.map { $0.available.formatted(.byteCount(style: .file)) } ?? "–",
                        detail: size == .compact ? nil : disk.map { "of \($0.total.formatted(.byteCount(style: .file)))" },
                        tint: (disk.map { Double($0.available) / Double(max($0.total, 1)) } ?? 1) < 0.1 ? .orange : .primary)
            .subscribes(to: .disk)
    }
}

struct UptimeWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "system.uptime"
    static var name: String { String(localized: "Uptime") }
    static let category = WidgetCategory.system
    static let symbol = "clock.arrow.circlepath"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    /// Boot time never changes while the app runs, so read it once.
    private static let bootDate: Date = {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        sysctlbyname("kern.boottime", &boot, &size, nil, 0)
        return Date(timeIntervalSince1970: Double(boot.tv_sec))
    }()

    static func view(size: TileSize, settings: Settings) -> some View {
        TimelineView(.everyMinute) { context in
            StatTile(label: "Uptime",
                     value: Duration.seconds(context.date.timeIntervalSince(bootDate))
                        .formatted(.units(allowed: [.days, .hours, .minutes], width: .narrow, maximumUnitCount: 2)))
        }
    }
}

struct ThermalWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "system.thermal"
    static var name: String { String(localized: "Thermal") }
    static let category = WidgetCategory.system
    static let symbol = "thermometer.medium"
    static let supportedSizes: [TileSize] = [.compact]

    static func view(size: TileSize, settings: Settings) -> some View {
        ThermalTile()
    }
}

/// macOS only exposes a coarse thermal state publicly (no temperatures), which is what this shows.
private struct ThermalTile: View {
    @State private var state = ProcessInfo.processInfo.thermalState

    var body: some View {
        let (label, tint): (LocalizedStringKey, Color) = switch state {
        case .nominal: ("Cool", .green)
        case .fair: ("Warm", .yellow)
        case .serious: ("Hot", .orange)
        case .critical: ("Critical", .red)
        @unknown default: ("?", .secondary)
        }
        VStack(spacing: 2) {
            Image(systemName: "thermometer.medium").font(.title3).foregroundStyle(tint)
            Text(label).font(.caption.weight(.semibold))
        }
        .tileText()
        .accessibilityElement(children: .combine)
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            state = ProcessInfo.processInfo.thermalState
        }
    }
}
