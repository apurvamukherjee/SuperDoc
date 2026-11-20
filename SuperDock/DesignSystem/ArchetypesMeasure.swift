import SwiftUI

// Archetypes 1–4: Stat, Ring, Bars, Chart. Each reads `\.tile` and picks its layout from size and orientation;
// widgets only fill the slots.

struct Stat: Identifiable, Equatable {
    var id: String { label }
    var label: String
    var value: String
    var unit: String?
    var detail: String?
    var meter: Double?
    var meterColor: Color?
    /// Trailing word on the label line at M and up: "Normal".
    var badge: String?
    var badgeColor: Color?
}

struct Breakdown: Identifiable, Equatable {
    var id: String { label }
    var label: String
    var value: String
}

/// 1 · Stat. One stat fills the tile; several stats (Large) sit side by side as columns.
struct StatTile: View {
    @Environment(\.tile) private var tile
    var stats: [Stat]
    /// Right-hand column at W/L: "App 7.9 · Wired 2.1 · Swap 0.4".
    var breakdown: [Breakdown] = []

    var body: some View {
        if stats.count > 1, !tile.isPortrait, !tile.isCompact {
            HStack(spacing: 10 * tile.scale) {
                ForEach(stats.prefix(tile.columns)) { StatColumn(stat: $0, compact: true) }
            }
        } else if let stat = stats.first {
            HStack(spacing: 10 * tile.scale) {
                StatColumn(stat: stat, compact: tile.isCompact)
                if !breakdown.isEmpty, tile.columns >= 3, !tile.isPortrait {
                    Divider().overlay(tile.surface.divider)
                    VStack(alignment: .leading, spacing: tile.rowSpacing) {
                        ForEach(breakdown) { row in
                            HStack {
                                Text(row.label).tileStyle(.detail)
                                Spacer(minLength: 6)
                                Text(row.value).tileStyle(.detail, color: tile.surface.primary).fontWeight(.semibold)
                            }
                        }
                    }
                    .frame(width: tile.contentSize.width * 0.3)
                }
            }
        }
    }
}

private struct StatColumn: View {
    @Environment(\.tile) private var tile
    let stat: Stat
    /// Compact columns put the detail line under the hero instead of a meter.
    let compact: Bool

    var body: some View {
        SlotStack(label: stat.label, badge: compact ? nil : stat.badge, badgeColor: stat.badgeColor) {
            HeroText(value: stat.value, unit: stat.unit)
        } bottom: {
            if let meter = stat.meter, !tile.isCompact {
                Meter(fraction: meter, color: stat.meterColor)
            } else if let detail = stat.detail, tile.showsDetail || tile.isCompact {
                Text(detail).tileStyle(.detail)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 2 · Ring. Pomodoro, Timer, Disk, AI Limits compact, plugin gauge.
struct RingTile: View {
    struct Action: Identifiable {
        var id: String { symbol }
        var symbol: String
        var label: String
        var run: () -> Void = {}
    }

    @Environment(\.tile) private var tile
    var rings: [RingGauge.Ring]
    var label: String?
    var value: String
    var detail: String?
    /// Round pips under the hero at W: (done, total).
    var segments: (done: Int, total: Int)?
    var actions: [Action] = []

    var body: some View {
        if tile.isCompact {
            ZStack {
                RingGauge(rings: rings)
                Text(value).tileStyle(.value)
            }
        } else if tile.isPortrait {
            VStack(spacing: tile.rowSpacing) {
                RingGauge(rings: rings, lineWidth: 6)
                Text(value).tileStyle(.heroCompact)
                if let detail { Text(detail).tileStyle(.detail) }
            }
        } else {
            HStack(spacing: 10 * tile.scale) {
                RingGauge(rings: rings, lineWidth: 6)
                SlotStack(label: label) {
                    Text(value).tileStyle(.hero)
                } bottom: {
                    if tile.size == .wide, let segments {
                        Pips(done: segments.done, total: segments.total)
                    } else if let detail {
                        Text(detail).tileStyle(.detail)
                    }
                }
                ForEach(actions.prefix(tile.size == .wide ? 1 : tile.size == .large ? 2 : 0)) { action in
                    TileIconButton(symbol: action.symbol, label: action.label, diameter: 32, action: action.run)
                }
            }
        }
    }
}

private struct Pips: View {
    @Environment(\.tile) private var tile
    let done: Int
    let total: Int

    var body: some View {
        HStack(spacing: 3 * tile.scale) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < done ? Palette.coral.opacity(index == done - 1 ? 0.6 : 1) : tile.surface.track)
                    .frame(width: 13 * tile.scale, height: 3.5 * tile.scale)
            }
        }
    }
}

struct BarRow: Identifiable, Equatable {
    var id: String { label }
    var label: String
    var value: String
    var unit: String?
    var fraction: Double
    var color: Color?
    var detail: String?
}

/// 3 · Bars. AI Limits M–L, Day/Week/Year progress. Compact shows the first row as a vertical gauge.
struct BarsTile: View {
    @Environment(\.tile) private var tile
    var rows: [BarRow]
    /// Large adds a column after a divider: "NEXT 1h 05m until Fri".
    var aside: Stat?

    var body: some View {
        if tile.isCompact, let row = rows.first {
            HStack(spacing: 7 * tile.scale) {
                Meter(fraction: row.fraction, color: row.color, thickness: 9, axis: .vertical)
                SlotStack(label: row.label) {
                    HeroText(value: row.value, unit: row.unit, style: .heroCompact)
                } bottom: {
                    if let detail = row.detail { Text(detail).tileStyle(.detail) }
                }
            }
        } else if tile.isPortrait {
            VStack(spacing: 6 * tile.scale) {
                ForEach(Array(rows.prefix(2).enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Divider().overlay(tile.surface.divider) }
                    SlotStack(label: row.label) {
                        HeroText(value: row.value, unit: row.unit, style: .heroCompact)
                    } bottom: {
                        VStack(alignment: .leading, spacing: 3 * tile.scale) {
                            Meter(fraction: row.fraction, color: row.color)
                            if let detail = row.detail { Text(detail).tileStyle(.detail) }
                        }
                    }
                }
            }
        } else {
            HStack(spacing: 12 * tile.scale) {
                let columns = tile.size == .medium ? 1 : 2
                Grid(horizontalSpacing: 12 * tile.scale, verticalSpacing: 0) {
                    ForEach(0..<2, id: \.self) { line in
                        if line > 0 { Spacer(minLength: 0) }
                        GridRow {
                            ForEach(rows.dropFirst(line * columns).prefix(columns)) { BarLine(row: $0) }
                        }
                    }
                }
                if let aside, tile.size == .large {
                    Divider().overlay(tile.surface.divider)
                    SlotStack(label: aside.label) {
                        Text(aside.value).tileStyle(.heroCompact)
                    } bottom: {
                        if let detail = aside.detail { Text(detail).tileStyle(.detail) }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.vertical, 2 * tile.scale)
        }
    }
}

private struct BarLine: View {
    @Environment(\.tile) private var tile
    let row: BarRow

    var body: some View {
        VStack(spacing: 4 * tile.scale) {
            HStack(alignment: .firstTextBaseline) {
                if tile.showsLabel { Text(row.label).tileStyle(.label) }
                Spacer(minLength: 4)
                Text(row.value + (row.unit ?? "")).tileStyle(.value)
            }
            Meter(fraction: row.fraction, color: row.color)
        }
        .accessibilityElement(children: .combine)
    }
}

struct Legend: Identifiable, Equatable {
    var id: String { text }
    var text: String
    var color: Color
}

/// 4 · Chart. CPU and Network: an area that bleeds to the tile's bottom edge.
struct ChartTile: View {
    @Environment(\.tile) private var tile
    var label: String
    var value: String?
    var series: [AreaChart.Series]
    /// Coloured mono readings at W ("↓ 4.2 MB/s"), shown instead of `value`.
    var legend: [Legend] = []
    /// Secondary text after the label at L: "P 31% · E 12%".
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 2 * tile.scale)
            AreaChart(series: series)
                .frame(height: tile.contentSize.height * (tile.isPortrait ? 0.32 : tile.isCompact ? 0.42 : 0.55))
                .tileBleed()
        }
    }

    @ViewBuilder private var header: some View {
        if tile.isCompact || tile.isPortrait {
            if tile.showsLabel { Text(label).tileStyle(.label) }
            if let value {
                Text(value).tileStyle(tile.isPortrait ? .hero : .heroCompact)
                    .padding(.top, tile.isPortrait ? 16 * tile.scale : 0)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6 * tile.scale) {
                Text(label).tileStyle(.label).fixedSize()
                if let detail, tile.size == .large { Text(detail).tileStyle(.detail) }
                Spacer(minLength: 0)
                if !legend.isEmpty, tile.size == .wide {
                    ForEach(legend) { Text($0.text).tileStyle(.mono, color: $0.color).fixedSize() }
                } else if let value {
                    Text(value).tileStyle(.heroCompact)
                }
            }
            .padding(.top, 2 * tile.scale)
        }
    }
}
