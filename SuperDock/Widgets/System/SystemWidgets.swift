import SwiftUI

/// Label over a big value, with an optional detail line on bigger tiles. Shared by the simple stat widgets.
struct LegacyStatTile: View {
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

enum SystemFormat {
    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    /// One decimal under 10 so small values still move, whole numbers above: "4.2", "380".
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value < 9.95 ? 1 : 0)))
    }

    /// Decimal units, like Finder and Activity Monitor's network column: ("4.2", "MB/s").
    static func rate(_ bytesPerSecond: Double) -> (value: String, unit: String) {
        let units = ["KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond / 1000
        var index = 0
        while value >= 999.5, index < units.count - 1 {
            value /= 1000
            index += 1
        }
        return (number(value), units[index])
    }

    /// Decimal GB/TB, like Finder: ("212", "GB").
    static func storage(_ bytes: Int64) -> (value: String, unit: String) {
        let gigabytes = Double(bytes) / 1e9
        return gigabytes >= 999.5 ? (number(gigabytes / 1000), "TB") : (number(gigabytes), "GB")
    }
}

// MARK: Memory

struct MemoryWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "system.memory"
    static var name: String { String(localized: "Memory") }
    static let category = WidgetCategory.system
    static let symbol = "memorychip"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        MemoryTile()
    }
}

private struct MemoryTile: View {
    private let stats = SystemStatsService.shared

    var body: some View {
        MemoryTileView(memory: stats.memory).subscribes(to: .memory)
    }
}

/// 1 · Stat with a meter coloured by memory pressure. The pressure is also spelled out (badge at M, a warning
/// mark at C), never colour alone.
struct MemoryTileView: View {
    @Environment(\.tile) private var tile
    var memory: SystemStatsService.Memory?

    var body: some View {
        if let memory {
            // Activity Monitor reports binary gigabytes, so 17 179 869 184 bytes reads "16 GB".
            let gib = { (bytes: UInt64) in Double(bytes) / 1_073_741_824 }
            let used = gib(memory.used).formatted(.number.precision(.fractionLength(1)))
            let total = Int(gib(memory.total).rounded())
            let look = Pressure(memory.pressure, surface: tile.surface)
            let wide = !tile.isCompact && !tile.isPortrait
            SlotStack(label: wide ? String(localized: "Memory") : String(localized: "Mem"),
                      badge: wide ? "● \(look.word)" : memory.pressure == .normal ? nil : "⚠︎", badgeColor: look.text) {
                HeroText(value: used, unit: wide ? "/ \(total) GB" : nil)
            } bottom: {
                Meter(fraction: Double(memory.used) / Double(max(memory.total, 1)), color: look.meter, thickness: 5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Memory")
            .accessibilityValue("\(used) of \(total) GB used, pressure \(look.word)")
        } else {
            TileStateView(state: .loading)
        }
    }

    private struct Pressure {
        let word: String
        let meter: Color
        let text: Color

        init(_ pressure: SystemStatsService.MemoryPressure, surface: SurfaceTokens) {
            (word, meter, text) = switch pressure {
            case .normal: (String(localized: "Normal"), Palette.good, surface.good)
            case .warning: (String(localized: "High"), Palette.amber, surface.warning)
            case .critical: (String(localized: "Critical"), Palette.coral, surface.danger)
            }
        }
    }
}

// MARK: Network

struct NetworkWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "system.network"
    static var name: String { String(localized: "Network") }
    static let category = WidgetCategory.system
    static let symbol = "arrow.up.arrow.down"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        NetworkTile()
    }
}

private struct NetworkTile: View {
    private let stats = SystemStatsService.shared

    var body: some View {
        NetworkTileView(download: stats.download, upload: stats.upload,
                        downloadHistory: stats.downloadHistory, uploadHistory: stats.uploadHistory)
            .subscribes(to: .network)
    }
}

/// C: two stacked rates. M: the rates as a legend over a two-tone chart (download filled, upload as a line).
/// Arrows carry direction, so the green/amber pairing is never the only cue.
struct NetworkTileView: View {
    @Environment(\.tile) private var tile
    var download: Double?
    var upload: Double?
    var downloadHistory: [Double]
    var uploadHistory: [Double]

    var body: some View {
        if let download, let upload {
            let down = SystemFormat.rate(download)
            let sent = SystemFormat.rate(upload)
            Group {
                if tile.isCompact {
                    VStack(alignment: .leading, spacing: 9 * tile.scale) {
                        rate("↓", down, color: tile.surface.good)
                        rate("↑", sent, color: tile.surface.warning)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.leading, 2 * tile.scale)
                } else {
                    SystemChartLayout {
                        let legend = tile.isPortrait ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2 * tile.scale))
                                                     : AnyLayout(HStackLayout(spacing: 12 * tile.scale))
                        legend {
                            rate("↓", down, color: tile.surface.good)
                            rate("↑", sent, color: tile.surface.warning)
                        }
                    } chart: {
                        AreaChart(series: [.init(values: downloadHistory, color: Palette.good),
                                           .init(values: uploadHistory, color: Palette.amber, filled: false)])
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Network")
            .accessibilityValue("Download \(down.value) \(down.unit), upload \(sent.value) \(sent.unit)")
        } else {
            TileStateView(state: .loading)
        }
    }

    /// Compact stacks the rates, so the unit steps down to keep the number the thing you read.
    private func rate(_ arrow: String, _ reading: (value: String, unit: String), color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3 * tile.scale) {
            Text(arrow).tileStyle(.mono, color: color).fontWeight(.bold)
            // `Text.font` binds tighter than `tileStyle`'s, so it overrides the size and keeps the colour and tracking.
            Text(reading.value).font(tile.isCompact ? .system(size: 13 * tile.scale, weight: .semibold, design: .monospaced) : nil)
                .tileStyle(.mono).fontWeight(.semibold)
            if tile.isCompact {
                Text(reading.unit).font(.system(size: 8.5 * tile.scale, weight: .medium, design: .monospaced))
                    .foregroundStyle(tile.surface.secondary)
            } else {
                Text(reading.unit).tileStyle(.mono)
            }
        }
        .fixedSize()
    }
}

// MARK: Disk

struct DiskWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "system.disk"
    static var name: String { String(localized: "Disk") }
    static let category = WidgetCategory.system
    static let symbol = "internaldrive"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        DiskTile()
    }
}

private struct DiskTile: View {
    private let stats = SystemStatsService.shared

    var body: some View {
        DiskTileView(disk: stats.disk).subscribes(to: .disk)
    }
}

/// C: a capacity ring with free space inside. M: free space as a stat over a used / purgeable / free bar.
/// Under 10 % free the tile says "Low" as well as turning red.
struct DiskTileView: View {
    @Environment(\.tile) private var tile
    var disk: SystemStatsService.Disk?

    var body: some View {
        if let disk, disk.total > 0 {
            let total = Double(disk.total)
            let free = SystemFormat.storage(disk.available)
            let isLow = Double(disk.available) / total < 0.1
            let used = 1 - Double(disk.available) / total
            let alarm = isLow ? tile.surface.danger : nil
            Group {
                if tile.isCompact || tile.isPortrait {
                    ZStack {
                        RingGauge(rings: [.init(fraction: used, color: alarm ?? tile.surface.primary)], lineWidth: 4.5)
                        VStack(spacing: 0) {
                            Text(free.value).tileStyle(.value, color: alarm)
                            // Smaller than `.caption` so "GB FREE" sits inside the ring.
                            Text(isLow ? "\(free.unit) low" : "\(free.unit) free").font(.system(size: 6.5 * tile.scale, weight: .bold))
                                .tileStyle(.caption, color: alarm)
                        }
                    }
                } else {
                    SlotStack(label: disk.name ?? String(localized: "Disk"), badge: isLow ? String(localized: "Low") : nil,
                              badgeColor: tile.surface.danger) {
                        HeroText(value: free.value, unit: "\(free.unit) free", color: alarm)
                    } bottom: {
                        CapacityBar(segments: [(used - Double(disk.purgeable) / total, isLow ? Palette.coral : Palette.progress),
                                               (Double(disk.purgeable) / total, Palette.amber)])
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(disk.name ?? "Disk")
            .accessibilityValue("\(free.value) \(free.unit) free\(isLow ? ", low" : "")")
        } else {
            TileStateView(state: .loading)
        }
    }
}

/// Segments laid end to end on a track, with small gaps, like Storage settings.
private struct CapacityBar: View {
    @Environment(\.tile) private var tile
    var segments: [(fraction: Double, color: Color)]

    var body: some View {
        let gap = 3 * tile.scale
        GeometryReader { geo in
            HStack(spacing: gap) {
                let visible = segments.filter { $0.fraction > 0.004 }
                ForEach(visible.indices, id: \.self) { index in
                    Capsule().fill(visible[index].color)
                        .frame(width: max(geo.size.width * visible[index].fraction.unitClamped - gap, 0))
                }
                Capsule().fill(tile.surface.track)
            }
        }
        .frame(height: 5 * tile.scale)
        .accessibilityHidden(true)
    }
}

// MARK: Uptime

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
            UptimeTileView(boot: bootDate, now: context.date)
        }
    }
}

/// 1 · Stat: "3d 4h", minutes as the unit at M, and when the Mac booted.
struct UptimeTileView: View {
    @Environment(\.tile) private var tile
    var boot: Date
    var now: Date
    var calendar = Calendar.current

    var body: some View {
        let minutes = max(Int(now.timeIntervalSince(boot) / 60), 0)
        let (days, hours, mins) = (minutes / 1440, minutes / 60 % 24, minutes % 60)
        let roomy = !tile.isCompact && !tile.isPortrait
        let value = days > 0 ? "\(days)d \(hours)h" : hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
        StatTile(stats: [Stat(label: tile.isCompact ? String(localized: "Up") : String(localized: "Uptime"), value: value,
                              unit: roomy && days > 0 ? "\(mins)m" : nil, detail: since(full: roomy))])
            .minimumScaleFactor(0.75)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Uptime")
            .accessibilityValue("\(value), \(since(full: true))")
    }

    private func since(full: Bool) -> String {
        let time = boot.formatted(date: .omitted, time: .shortened)
        let when: String
        if calendar.isDate(boot, inSameDayAs: now) {
            when = time
        } else if let days = calendar.dateComponents([.day], from: boot, to: now).day, days < 6 {
            let weekday = boot.formatted(.dateTime.weekday(.abbreviated))
            when = full ? "\(weekday) \(time)" : weekday
        } else {
            when = boot.formatted(.dateTime.day().month(.abbreviated))
        }
        return full ? String(localized: "Since \(when)") : String(localized: "since \(when)")
    }
}
