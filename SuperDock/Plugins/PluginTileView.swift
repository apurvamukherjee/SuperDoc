import SwiftUI

/// What a plugin tile shows once its JSON is resolved: plain values, so the gallery can draw every template.
struct PluginDisplay: Equatable {
    struct Item: Identifiable, Equatable {
        var id: Int
        var title: String
        var count: String?
        var link: String?
    }

    enum Content: Equatable {
        /// `numeric` picks hero numerals; otherwise one token (an IP, a hash) is mono and prose is a title.
        case value(String, subtitle: String?, numeric: Bool)
        case text(String)
        case list([Item])
        case gauge(fraction: Double, value: String, subtitle: String?, range: String)
    }

    var label: String
    var symbol: String
    /// Index into the list accent hues; derived from the plugin id so each feed keeps its colour.
    var hue: Int
    var content: Content

    static func hue(for id: String) -> Int { id.unicodeScalars.reduce(0) { $0 + Int($1.value) } }
}

enum PluginPhase: Equatable {
    case loading
    case offline(name: String)
    case invalidURL
    /// `staleAge` set: the last fetch failed, so the previous data shows dimmed with its age.
    case ready(PluginDisplay, staleAge: String?)
}

/// The four declarative templates (value, text, list, gauge) on the kit's archetypes, plus the shared states.
struct PluginTileView: View {
    @Environment(\.tile) private var tile
    var phase: PluginPhase
    var onOpenLink: (String) -> Void = { _ in }

    var body: some View {
        switch phase {
        case .loading:
            TileStateView(state: .loading)
        case let .offline(name):
            TileStateView(state: .offline(detail: "\(name) unavailable"))
        case .invalidURL:
            TileStateView(state: .needsSetup(verb: "Check", title: "Check settings", detail: "Plugin URL is invalid"))
        case let .ready(display, staleAge):
            content(display).tileStale(staleAge)
        }
    }

    @ViewBuilder private func content(_ display: PluginDisplay) -> some View {
        switch display.content {
        case let .value(value, subtitle, numeric):
            PluginValueView(display: display, value: value, subtitle: subtitle, numeric: numeric)
        case let .text(text):
            PluginTextView(label: display.label, text: text)
        case let .list(items):
            PluginListView(label: display.label, hue: display.hue, items: items, onOpen: onOpenLink)
        case let .gauge(fraction, value, subtitle, range):
            PluginGaugeView(label: display.label, fraction: fraction, value: value, subtitle: subtitle, range: range)
        }
    }
}

/// Symbol + tracked label: the plugin's header line in every template.
private struct PluginLabel: View {
    @Environment(\.tile) private var tile
    var symbol: String?
    var text: String
    var symbolColor: Color?
    var color: Color?

    var body: some View {
        // A portrait tile is one unit wide, so the label gets the whole line and may wrap.
        HStack(spacing: 4 * tile.scale) {
            if let symbol, !tile.isPortrait {
                Image(systemName: symbol).font(.system(size: 9.5 * tile.scale, weight: .semibold))
                    .foregroundStyle(symbolColor ?? tile.surface.secondary)
            }
            Text(text).lineLimit(tile.isPortrait ? 2 : 1).tileStyle(.label, color: color).minimumScaleFactor(0.75)
        }
    }
}

/// Stat archetype: label, hero, subtitle. A leading "+" or "−" in the subtitle reads as a change and gets its colour.
private struct PluginValueView: View {
    @Environment(\.tile) private var tile
    let display: PluginDisplay
    let value: String
    let subtitle: String?
    let numeric: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PluginLabel(symbol: tile.isCompact && display.label.count > 7 ? nil : display.symbol, text: display.label)
            Spacer(minLength: 0)
            hero.minimumScaleFactor(0.5)
            Spacer(minLength: 0)
            if let subtitle, tile.showsDetail || tile.isCompact {
                Text(subtitle).tileStyle(.detail, color: changeColor(subtitle))
            }
        }
        .padding(.leading, 2 * tile.scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var hero: some View {
        if numeric {
            Text(value).tileStyle(tile.isCompact ? .heroCompact : .hero)
        } else if !value.contains(" ") {
            Text(value).tileStyle(tile.isPortrait ? .mono : .monoHero)
        } else {
            Text(value).lineLimit(2).tileStyle(.title)
        }
    }

    private func changeColor(_ text: String) -> Color? {
        if text.hasPrefix("+") { return tile.surface.good }
        return text.hasPrefix("-") || text.hasPrefix("−") ? tile.surface.danger : nil
    }
}

/// A quote-marked label over a short paragraph.
private struct PluginTextView: View {
    @Environment(\.tile) private var tile
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3 * tile.scale) {
            PluginLabel(symbol: "quote.opening", text: label, symbolColor: Palette.amber)
            Text(text).lineLimit(tile.isPortrait ? 9 : 3).tileStyle(.body).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2 * tile.scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

/// Coloured header, ranked rows (count + title). The first two rows are bright, the rest recede. At L the header
/// moves to its own column so the rows get the full width.
private struct PluginListView: View {
    @Environment(\.tile) private var tile
    let label: String
    let hue: Int
    let items: [PluginDisplay.Item]
    let onOpen: (String) -> Void

    private var accent: Color {
        let dark = [Palette.hot, Palette.coral, Palette.codex, Palette.progress]
        let light = [tile.surface.warning, tile.surface.danger, Color(rgb: 0x6A4FD0), Color(rgb: 0x1D6AD8)]
        return (tile.surface.isDark ? dark : light)[hue % dark.count]
    }

    private var rowCount: Int {
        tile.isPortrait ? max(Int(tile.contentSize.height / (30 * tile.scale)), 2) : 3
    }

    var body: some View {
        Group {
            if tile.size == .large, !tile.isPortrait {
                HStack(spacing: 10 * tile.scale) {
                    Text(label).tileStyle(.label, color: accent).frame(width: tile.contentSize.width * 0.14, alignment: .leading)
                    Divider().overlay(tile.surface.divider)
                    rows
                }
            } else {
                VStack(alignment: .leading, spacing: 1 * tile.scale) {
                    PluginLabel(text: label, color: accent)
                    rows
                }
            }
        }
        .padding(.horizontal, 2 * tile.scale)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items.prefix(rowCount)) { item in
                Button { if let link = item.link { onOpen(link) } } label: { row(item) }
                    .buttonStyle(TilePressStyle())
                    .disabled(item.link == nil)
                    .accessibilityLabel(item.count.map { "\(item.title), \($0)" } ?? item.title)
            }
            if items.isEmpty { Text("Nothing yet").tileStyle(.detail).frame(maxHeight: .infinity) }
        }
    }

    private func row(_ item: PluginDisplay.Item) -> some View {
        let bright = item.id < 2
        // One unit wide, the count sits above its title instead of eating half the line.
        let layout = tile.isPortrait ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                                     : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6 * tile.scale))
        return layout {
            if let count = item.count {
                Text(count).tileStyle(.body, color: bright ? accent : tile.surface.secondary).fontWeight(.semibold)
                    .monospacedDigit().lineLimit(1).fixedSize()
            }
            Text(item.title).lineLimit(tile.isPortrait ? 3 : 1)
                .tileStyle(.body, color: bright ? tile.surface.primary : tile.surface.secondary)
                .fontWeight(bright ? .semibold : .regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// An open-bottomed arc gauge. Compact: value in the arc, label under it. Wider: label, subtitle and range beside it.
private struct PluginGaugeView: View {
    @Environment(\.tile) private var tile
    let label: String
    let fraction: Double
    let value: String
    let subtitle: String?
    let range: String

    var body: some View {
        Group {
            if tile.isCompact || tile.isPortrait {
                VStack(spacing: 1 * tile.scale) {
                    arc(value: .value).frame(width: tile.contentSize.width * 0.8)
                    Text(label).lineLimit(2).multilineTextAlignment(.center).tileStyle(.caption)
                    if tile.isPortrait, let subtitle { Text(subtitle).tileStyle(.title, color: Palette.amber) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 10 * tile.scale) {
                    arc(value: .heroCompact).frame(width: tile.contentSize.height * 1.15)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(label).lineLimit(2).tileStyle(.label)
                        if let subtitle {
                            Text(subtitle).tileStyle(.title, color: tile.surface.isDark ? Palette.amber : tile.surface.warning)
                        }
                        Text(range).lineLimit(2).tileStyle(.detail)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([label, value, subtitle].compactMap(\.self).joined(separator: ", "))
    }

    /// Sweep of 234°, centred on the top, so the gap sits at the bottom under the number.
    private func arc(value style: TileTextStyle) -> some View {
        let sweep = 0.65
        let width = 5.5 * tile.scale
        return ZStack {
            Group {
                Circle().trim(from: 0, to: sweep).stroke(tile.surface.track, style: StrokeStyle(lineWidth: width, lineCap: .round))
                Circle().trim(from: 0, to: sweep * fraction.unitClamped)
                    .stroke(Palette.amber, style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
            .rotationEffect(.degrees(90 + (1 - sweep) * 180))
            .padding(width / 2)
            Text(value).tileStyle(style).minimumScaleFactor(0.6).padding(.horizontal, width * 1.5).offset(y: width * 0.6)
        }
        .aspectRatio(1, contentMode: .fit)
        .tileAnimation(value: fraction)
    }
}
