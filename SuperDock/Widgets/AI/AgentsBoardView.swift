import SwiftUI

/// One coding-agent session as the board draws it. Only status metadata, never prompt text.
struct AgentItem: Identifiable, Equatable {
    var id: String
    var project: String
    var tool: AIProvider
    var status: AgentStatus
    /// When the current status began; nil when the source can't tell.
    var since: Date?
}

/// The coding-agents board drawn from plain values. Needs-you sorts first (the service orders them), is a filled
/// coral chip, outlines the compact tile, and nudges twice when it appears; working pulses only while working.
struct AgentsBoardView: View {
    @Environment(\.tile) private var tile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var agents: [AgentItem]
    var now = Date()

    @State private var nudges = 0

    private var needsCount: Int { agents.count { $0.status == .needsInput } }

    var body: some View {
        content
            .keyframeAnimator(initialValue: 0.0, trigger: nudges) { view, offset in
                view.offset(x: offset)
            } keyframes: { _ in
                let nudge = 2.5 * tile.scale
                KeyframeTrack {
                    CubicKeyframe(nudge, duration: 0.08)
                    CubicKeyframe(-nudge, duration: 0.12)
                    CubicKeyframe(0, duration: 0.1)
                    CubicKeyframe(nudge, duration: 0.08)
                    CubicKeyframe(-nudge, duration: 0.12)
                    CubicKeyframe(0, duration: 0.1)
                }
            }
            .onChange(of: needsCount) { old, new in
                if new > old, !reduceMotion { nudges += 1 }
            }
    }

    @ViewBuilder private var content: some View {
        if agents.isEmpty {
            TileStateView(state: .empty(title: String(localized: "All quiet"), detail: String(localized: "No agents running")))
        } else if tile.isCompact {
            AgentCounts(agents: agents, inline: false)
                .tileOutline(needsCount > 0 ? .alert : .none)
        } else if tile.tier == .tight, !tile.isPortrait {
            AgentCounts(agents: agents, inline: true)
        } else if !tile.isPortrait, agents.allSatisfy({ $0.status == .done }) {
            AllDone(agents: agents, now: now)
        } else if !tile.isPortrait, agents.count == 1, let agent = agents.first {
            AgentFocus(agent: agent, now: now)
                .tileOutline(agent.status == .needsInput ? .alert : .none)
        } else {
            AgentBoard(agents: agents, now: now)
        }
    }
}

enum AgentFormat {
    static func elapsed(since: Date?, now: Date) -> String? {
        guard let since else { return nil }
        return AIFormat.countdown(now.timeIntervalSince(since))
    }

    /// Roomy rows trade the provider badge for a status word: "needs you", "12m", "done".
    static func trailing(_ agent: AgentItem, now: Date) -> String {
        switch agent.status {
        case .needsInput: String(localized: "needs you")
        case .working: elapsed(since: agent.since, now: now) ?? String(localized: "working")
        case .done: String(localized: "done")
        case .idle: String(localized: "idle")
        }
    }
}

/// The status mark before a row. Working is the kit's pulsing ¾ arc over a faint track (still under Reduce Motion).
private struct StatusGlyph: View {
    @Environment(\.tile) private var tile
    var status: AgentStatus
    var size: CGFloat

    var body: some View {
        Group {
            switch status {
            case .working:
                ZStack {
                    Circle().stroke(Palette.working.opacity(0.28), lineWidth: 1.6).padding(1)
                    ActivityArc(color: Palette.working)
                }
                .workingPulse(true)
            case .needsInput:
                Image(systemName: "hand.raised.fill").resizable().scaledToFit().foregroundStyle(Palette.coral)
            case .done:
                Image(systemName: "checkmark").resizable().scaledToFit().fontWeight(.bold).foregroundStyle(tile.surface.good)
                    .padding(size * 0.08)
            case .idle:
                Image(systemName: "moon").resizable().scaledToFit().fontWeight(.semibold).foregroundStyle(tile.surface.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Compact: a 2 × 2 of status + count. Tight M: the same counts in one line, needs-you first.
private struct AgentCounts: View {
    @Environment(\.tile) private var tile
    let agents: [AgentItem]
    let inline: Bool

    private var counts: [(status: AgentStatus, count: Int)] {
        let order: [AgentStatus] = inline ? [.needsInput, .working, .done, .idle] : [.working, .needsInput, .done, .idle]
        return order.map { status in (status, agents.count { $0.status == status }) }.filter { $0.count > 0 }
    }

    var body: some View {
        Group {
            if inline {
                HStack(spacing: 10 * tile.scale) {
                    ForEach(counts, id: \.status) { cell($0.status, $0.count) }
                }
            } else {
                Grid(horizontalSpacing: 9 * tile.scale, verticalSpacing: 11 * tile.scale) {
                    ForEach(0..<(counts.count + 1) / 2, id: \.self) { line in
                        GridRow {
                            ForEach(counts.dropFirst(line * 2).prefix(2), id: \.status) { cell($0.status, $0.count) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cell(_ status: AgentStatus, _ count: Int) -> some View {
        HStack(spacing: 4 * tile.scale) {
            // A 56 pt Dock scales type to 62 %; the counts step up a size to stay readable at a glance.
            StatusGlyph(status: status, size: (tile.tier == .tight ? 13 : 11) * tile.scale)
            Text("\(count)").tileStyle(tile.tier == .tight ? .heroCompact : .value,
                                       color: status == .idle ? tile.surface.secondary : nil)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) \(status.title)")
    }
}

/// M three rows · W 2 × 3 · L 3 × 3 · portrait one column. Overflow becomes "+N".
private struct AgentBoard: View {
    @Environment(\.tile) private var tile
    let agents: [AgentItem]
    let now: Date

    private var chipHeight: CGFloat { 18 * tile.scale }

    var body: some View {
        if tile.isPortrait {
            let slots = max(Int((tile.contentSize.height + tile.rowSpacing) / (chipHeight + tile.rowSpacing)), 2)
            let visible = agents.count > slots ? slots - 1 : agents.count
            VStack(spacing: tile.rowSpacing) {
                ForEach(agents.prefix(visible)) { AgentChip(agent: $0, trailing: .none, now: now).frame(height: chipHeight) }
                if agents.count > visible { more(agents.count - visible).frame(height: chipHeight) }
                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: .leading, spacing: tile.rowSpacing) {
                if tile.showsExtraDetail { Text("Agents · \(agents.count)").tileStyle(.label) }
                columns
            }
        }
    }

    private var columns: some View {
        let columnCount = max(tile.columns - 1, 1)
        let capacity = columnCount * 3
        // M keeps its third row and counts the rest beside it; W and L give the last slot to "+N more".
        let visible = agents.count > capacity ? (columnCount == 1 ? capacity : capacity - 1) : agents.count
        let hidden = agents.count - visible
        return HStack(spacing: tile.rowSpacing) {
            ForEach(0..<columnCount, id: \.self) { column in
                VStack(spacing: tile.rowSpacing) {
                    ForEach(column * 3..<(column + 1) * 3, id: \.self) { index in
                        if index < visible {
                            AgentChip(agent: agents[index], trailing: trailing(index, visible: visible, hidden: hidden), now: now)
                        } else if index == visible, hidden > 0 {
                            more(hidden)
                        } else {
                            Color.clear
                        }
                    }
                }
            }
        }
    }

    private func trailing(_ index: Int, visible: Int, hidden: Int) -> AgentChip.Trailing {
        if hidden > 0, tile.columns == 2, index == visible - 1 { return .count(hidden) }
        // Status words only fit M's single wide column; W and L keep the badge.
        return tile.showsExtraDetail && tile.columns == 2 ? .status : .badge
    }

    private func more(_ count: Int) -> some View {
        Text("+\(count) more").tileStyle(.detail).fontWeight(.medium)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: tile.isPortrait ? .leading : .center)
            .padding(.leading, tile.isPortrait ? 5 * tile.scale : 0)
    }
}

private struct AgentChip: View {
    enum Trailing: Equatable {
        case none, badge, status
        case count(Int)
    }

    @Environment(\.tile) private var tile
    let agent: AgentItem
    let trailing: Trailing
    let now: Date

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: tile.innerRadius * 0.8, style: .continuous)
        let alert = agent.status == .needsInput
        HStack(spacing: 5 * tile.scale) {
            StatusGlyph(status: agent.status, size: 10 * tile.scale)
            Text(agent.project).tileStyle(.body, color: agent.status == .idle ? tile.surface.secondary : nil)
                .fontWeight(.semibold).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 2 * tile.scale)
            switch trailing {
            case .none:
                EmptyView()
            case .badge:
                ProviderBadge(provider: agent.tool, dimmed: agent.status == .idle)
            case .status:
                Text(AgentFormat.trailing(agent, now: now)).tileStyle(.detail).fontWeight(.medium)
            case let .count(hidden):
                Text("+\(hidden)").tileStyle(.detail).fontWeight(.medium)
            }
        }
        .padding(.horizontal, 5 * tile.scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            if alert {
                shape.fill(Palette.coral.opacity(tile.surface.isDark ? 0.28 : 0.16))
            } else {
                shape.fill(tile.surface.chipFill)
                if agent.status == .working {
                    // A still glow, not a sweep: the arc already moves, and one loop per working row is the budget.
                    shape.fill(LinearGradient(colors: [.clear, Palette.working.opacity(0.22), .clear],
                                              startPoint: .leading, endPoint: .trailing))
                }
            }
        }
        .overlay { if alert { shape.strokeBorder(Palette.coral.opacity(0.85), lineWidth: 1) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(agent.project), \(agent.tool.title), \(agent.status.title)")
    }
}

/// Every session finished: one calm green line instead of a board of checks.
private struct AllDone: View {
    @Environment(\.tile) private var tile
    let agents: [AgentItem]
    let now: Date

    var body: some View {
        let last = agents.max { ($0.since ?? .distantPast) < ($1.since ?? .distantPast) }
        HStack(spacing: 9 * tile.scale) {
            Image(systemName: "checkmark").font(.system(size: 13 * tile.scale, weight: .heavy))
                .foregroundStyle(Palette.inkDeep)
                .frame(width: 28 * tile.scale, height: 28 * tile.scale)
                .background(Palette.done, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(agents.count == 1 ? "\(agents[0].project) is done" : "All \(agents.count) done").tileStyle(.title)
                if let last {
                    Text(lastLine(last)).tileStyle(.detail)
                }
            }
            .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.leading, 2 * tile.scale)
        .frame(maxHeight: .infinity)
        .tileTint(Palette.done, opacity: tile.surface.isDark ? 0.16 : 0.12)
        .accessibilityElement(children: .combine)
    }

    private func lastLine(_ last: AgentItem) -> String {
        guard let ago = AgentFormat.elapsed(since: last.since, now: now) else { return String(localized: "Last: \(last.project)") }
        return String(localized: "Last: \(last.project) · \(ago) ago")
    }
}

/// A single session gets the whole tile: big status disc, project, how long it has been in this state.
private struct AgentFocus: View {
    @Environment(\.tile) private var tile
    let agent: AgentItem
    let now: Date

    var body: some View {
        let side = 32 * tile.scale
        HStack(spacing: 9 * tile.scale) {
            StatusGlyph(status: agent.status, size: side * 0.5)
                .frame(width: side, height: side)
                .background(agent.status.tint.opacity(0.2), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5 * tile.scale) {
                    Text(agent.project).tileStyle(.title)
                    ProviderBadge(provider: agent.tool)
                }
                Text([agent.status.title, AgentFormat.elapsed(since: agent.since, now: now)].compactMap(\.self).joined(separator: " · "))
                    .tileStyle(.detail)
            }
            Spacer(minLength: 0)
            if tile.columns >= 3 {
                Text("1 of 1").tileStyle(.label, color: agent.status.tint)
            }
        }
        .padding(.leading, 3 * tile.scale)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(agent.project), \(agent.tool.title), \(agent.status.title)")
    }
}
