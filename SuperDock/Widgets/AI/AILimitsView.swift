import SwiftUI

/// One limit window, already resolved against "now".
struct AILimit: Identifiable, Equatable {
    var provider: AIProvider
    /// Short window name: "5h", "Wk", "30d".
    var name: String
    /// Roomy tiles spell it out: "5-hour", "Weekly".
    var longName: String
    /// 0–100.
    var used: Double
    /// Seconds until the window resets; nil when unknown.
    var resetsIn: TimeInterval?
    /// Weekday the window resets on, shown instead of a countdown when the reset is days away: "Mon".
    var resetDay: String?
    /// The provider's shortest window (5-hour). Its longer windows draw in the paler tint.
    var isPrimary = true

    var id: String { provider.rawValue + name }
    var isDanger: Bool { used >= 80 }
    var isSpent: Bool { used >= 100 }

    /// Short windows count down; long ones name the day.
    var resetText: String? {
        guard let resetsIn else { return nil }
        return resetsIn > 24 * 3600 ? resetDay ?? AIFormat.countdown(resetsIn) : AIFormat.countdown(resetsIn)
    }

    var fill: Color { isDanger ? Palette.coral : isPrimary ? provider.tint : provider.softTint }

    func shown(remaining: Bool) -> Double { remaining ? 100 - used : used }
}

/// AI Limits drawn from plain values. Compact: Watch-style rings. M: both 5-hour windows. W: all four with reset
/// times. L: all four plus the next reset.
struct AILimitsView: View {
    enum Content: Equatable {
        case connect
        case noData
        case limits([AILimit])
    }

    @Environment(\.tile) private var tile
    var content: Content
    var showRemaining = false
    var onConnect: () -> Void = {}

    var body: some View {
        switch content {
        case .connect:
            TileStateView(state: .needsSetup(verb: String(localized: "Connect"), title: String(localized: "Connect Claude"),
                                             detail: String(localized: "Reads % only")), action: onConnect)
                .help("Connect Claude Code in Settings → AI to see its limits")
        case .noData:
            GlyphTile(caption: String(localized: "No data"), title: String(localized: "No limits yet"),
                      details: [String(localized: "Nothing used yet")]) {
                TileSymbol(name: "gauge.with.dots.needle.0percent", color: tile.surface.secondary)
                    .padding(tile.isCompact ? 4 * tile.scale : 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("No AI limit data yet")
        case let .limits(limits):
            layout(limits)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(limits.map(spoken).joined(separator: ", "))
        }
    }

    @ViewBuilder private func layout(_ limits: [AILimit]) -> some View {
        if tile.isCompact {
            if let spent = limits.first(where: \.isSpent), let resetsIn = spent.resetsIn {
                ResetsReadout(limit: spent, resetsIn: resetsIn)
            } else {
                LimitRings(limits: Array(limits.prefix(3)), showRemaining: showRemaining)
            }
        } else if tile.isPortrait {
            VStack(spacing: 5 * tile.scale) {
                ForEach(Array(mediumPick(limits).prefix(tile.columns == 2 ? 2 : 4).enumerated()), id: \.element.id) { index, limit in
                    if index > 0 { Divider().overlay(tile.surface.divider) }
                    PortraitLimit(limit: limit, showRemaining: showRemaining)
                }
            }
        } else if tile.tier == .tight {
            grid(limits) { TightLimitLine(limit: $0, showRemaining: showRemaining) }
        } else {
            HStack(spacing: 12 * tile.scale) {
                VStack(spacing: 0) {
                    if tile.showsExtraDetail { roomyHeader(limits) }
                    grid(limits) { limit in
                        LimitLine(limit: limit, showRemaining: showRemaining, showsReset: tile.size != .large,
                                  long: tile.showsExtraDetail && tile.size == .medium)
                    }
                }
                if tile.size == .large, let next = nextReset(limits) {
                    Divider().overlay(tile.surface.divider)
                    NextReset(limit: next)
                }
            }
        }
    }

    /// M shows each provider's 5-hour window first; W and L lay the windows out a provider per column.
    private func grid(_ limits: [AILimit], @ViewBuilder line: @escaping (AILimit) -> some View) -> some View {
        let columns = tile.size == .medium ? [mediumPick(limits).prefix(2)]
                                           : [limits.prefix(2), limits.dropFirst(2).prefix(2)].filter { !$0.isEmpty }
        return HStack(spacing: 8 * tile.scale) {
            ForEach(columns.indices, id: \.self) { column in
                VStack(spacing: 0) {
                    ForEach(Array(columns[column].enumerated()), id: \.element.id) { index, limit in
                        if index > 0 { Spacer(minLength: 2 * tile.scale) }
                        line(limit)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.vertical, 1 * tile.scale)
    }

    private func mediumPick(_ limits: [AILimit]) -> [AILimit] {
        limits.filter(\.isPrimary) + limits.filter { !$0.isPrimary }
    }

    private func nextReset(_ limits: [AILimit]) -> AILimit? {
        limits.filter { $0.resetsIn != nil }.min { ($0.resetsIn ?? 0) < ($1.resetsIn ?? 0) }
    }

    private func roomyHeader(_ limits: [AILimit]) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("AI Limits").tileStyle(.label)
            Spacer(minLength: 4)
            if tile.size != .large, let next = nextReset(limits), let resetsIn = next.resetsIn {
                Text("next reset \(AIFormat.countdown(resetsIn))").tileStyle(.detail)
            }
        }
        .padding(.bottom, 4 * tile.scale)
    }

    private func spoken(_ limit: AILimit) -> String {
        let verb = showRemaining ? String(localized: "left") : String(localized: "used")
        return "\(limit.provider.title) \(limit.name) \(Int(limit.shown(remaining: showRemaining)))% \(verb)"
    }
}

/// "62%" with a smaller percent sign; danger turns it coral behind a warning mark.
private struct PercentText: View {
    @Environment(\.tile) private var tile
    var value: Double
    var isDanger: Bool
    var style = TileTextStyle.value
    var showsSign = true

    var body: some View {
        let color = isDanger ? tile.surface.danger : nil
        HStack(alignment: .firstTextBaseline, spacing: 1.5 * tile.scale) {
            if isDanger, showsSign { DangerGlyph(style: style == .value ? .detail : .title) }
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(Int(value.rounded()))").tileStyle(style, color: color)
                if showsSign {
                    Text("%").font(tile.font(.caption)).foregroundStyle(color ?? tile.surface.secondary)
                }
            }
        }
        .fixedSize()
    }
}

/// M–L row: badge, window, reset, value, then the fuel bar.
private struct LimitLine: View {
    @Environment(\.tile) private var tile
    let limit: AILimit
    let showRemaining: Bool
    let showsReset: Bool
    let long: Bool

    var body: some View {
        let danger = limit.isDanger ? tile.surface.danger : nil
        VStack(spacing: 5 * tile.scale) {
            HStack(alignment: .firstTextBaseline, spacing: 3 * tile.scale) {
                ProviderBadge(provider: limit.provider)
                if long {
                    Text(limit.longName).tileStyle(.title, color: danger)
                } else {
                    Text(showRemaining ? "\(limit.name) left" : limit.name).tileStyle(.label, color: danger ?? tile.surface.primary)
                        .fontWeight(.bold)
                }
                if showsReset, !showRemaining || long, let reset = limit.resetText {
                    // W's two columns are a few points short of the full "2h 14m"; shrinking beats an ellipsis.
                    Text(reset).tileStyle(.detail, color: danger).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                PercentText(value: limit.shown(remaining: showRemaining), isDanger: limit.isDanger)
            }
            LimitMeter(fraction: limit.shown(remaining: showRemaining) / 100, color: limit.fill,
                       marker: showRemaining ? nil : 0.8, glows: limit.isDanger)
        }
    }
}

/// 56 pt Dock: no words, just badge, bar and number.
private struct TightLimitLine: View {
    @Environment(\.tile) private var tile
    let limit: AILimit
    let showRemaining: Bool

    var body: some View {
        HStack(spacing: 4 * tile.scale) {
            ProviderBadge(provider: limit.provider)
            LimitMeter(fraction: limit.shown(remaining: showRemaining) / 100, color: limit.fill, glows: limit.isDanger)
            PercentText(value: limit.shown(remaining: showRemaining), isDanger: limit.isDanger, style: .heroCompact,
                        showsSign: false)
                .frame(minWidth: 18 * tile.scale, alignment: .trailing)
        }
        .frame(maxHeight: .infinity)
    }
}

/// Vertical bar: the row stacks into badge + window, value, bar, reset.
private struct PortraitLimit: View {
    @Environment(\.tile) private var tile
    let limit: AILimit
    let showRemaining: Bool

    var body: some View {
        let danger = limit.isDanger ? tile.surface.danger : nil
        VStack(alignment: .leading, spacing: 3 * tile.scale) {
            HStack(spacing: 4 * tile.scale) {
                ProviderBadge(provider: limit.provider)
                Text(showRemaining ? "\(limit.name) left" : limit.name).tileStyle(.label, color: danger ?? tile.surface.primary)
            }
            // W stacks four windows in 231 pt: smaller numbers and no reset line, or the top window is cut off.
            PercentText(value: limit.shown(remaining: showRemaining), isDanger: limit.isDanger,
                        style: tile.columns == 3 ? .value : .heroCompact)
            LimitMeter(fraction: limit.shown(remaining: showRemaining) / 100, color: limit.fill, glows: limit.isDanger)
            if tile.columns != 3, let reset = limit.resetText { Text(reset).tileStyle(.detail, color: danger) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Watch-style rings: outer Claude 5h, middle Claude week, inner Codex 5h. The centre shows the most urgent %.
private struct LimitRings: View {
    @Environment(\.tile) private var tile
    let limits: [AILimit]
    let showRemaining: Bool

    var body: some View {
        let width = 6 * tile.scale
        let gap = 1 * tile.scale
        let urgent = limits.max { $0.used < $1.used }
        ZStack {
            ForEach(Array(limits.enumerated()), id: \.element.id) { index, limit in
                let inset = CGFloat(index) * (width + gap) + width / 2
                Circle().stroke(limit.fill.opacity(tile.surface.isDark ? 0.22 : 0.25), lineWidth: width).padding(inset)
                Circle().trim(from: 0, to: (limit.shown(remaining: showRemaining) / 100).unitClamped)
                    .stroke(limit.fill, style: StrokeStyle(lineWidth: width, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(inset)
            }
            if let urgent {
                Text("\(Int(urgent.shown(remaining: showRemaining).rounded()))")
                    .tileStyle(.title, color: urgent.isDanger ? tile.surface.danger : nil)
                    .monospacedDigit()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tileAnimation(value: limits)
    }
}

/// Compact, once a window is used up: when it comes back matters more than the rings.
private struct ResetsReadout: View {
    @Environment(\.tile) private var tile
    let limit: AILimit
    let resetsIn: TimeInterval

    var body: some View {
        VStack(spacing: 0) {
            Text("Resets").tileStyle(.caption)
            Spacer(minLength: 0)
            Text(AIFormat.clock(resetsIn)).tileStyle(.hero).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            HStack(spacing: 3 * tile.scale) {
                ProviderBadge(provider: limit.provider)
                Text(limit.name).tileStyle(.label, color: tile.surface.primary)
            }
        }
        .padding(.vertical, 1 * tile.scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// L's right column: the soonest reset, coral if that window is in danger.
private struct NextReset: View {
    @Environment(\.tile) private var tile
    let limit: AILimit

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Next reset").tileStyle(.label)
            Spacer(minLength: 0)
            DurationText(text: AIFormat.countdown(limit.resetsIn ?? 0), style: .hero,
                         color: limit.isDanger ? tile.surface.danger : nil)
            Spacer(minLength: 0)
            HStack(spacing: 4 * tile.scale) {
                ProviderBadge(provider: limit.provider)
                Text("\(limit.provider.title) \(limit.name)").tileStyle(.detail)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
