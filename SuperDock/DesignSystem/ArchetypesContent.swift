import SwiftUI

// Archetypes 5–8: List, Media, Control, Glyph.

struct ListRow: Identifiable, Equatable {
    var id: String
    var glyph = RowGlyph.none
    var title: String
    var titleColor: Color?
    var trailing: String?
    /// Coral needs-you chip.
    var alert = false

    init(id: String? = nil, glyph: RowGlyph = .none, title: String, titleColor: Color? = nil, trailing: String? = nil,
         alert: Bool = false) {
        (self.id, self.glyph, self.title, self.titleColor) = (id ?? title, glyph, title, titleColor)
        (self.trailing, self.alert) = (trailing, alert)
    }
}

struct ListCount: Identifiable, Equatable {
    var id: Int
    var glyph: RowGlyph
    var count: Int
}

/// 5 · List. Agents, Ports, To-Do, plugin list. Rows fill columns top to bottom; overflow becomes "+N more".
struct ListTile: View {
    @Environment(\.tile) private var tile
    var rows: [ListRow]
    /// Compact shows these as a 2 × 2 grid of glyph + count instead of rows.
    var counts: [ListCount] = []
    var mono = false

    private var columns: Int { tile.isPortrait ? 1 : max(tile.columns - 1, 1) }
    private var perColumn: Int { tile.isPortrait ? max(Int(tile.contentSize.height / (24 * tile.scale)), 2) : 3 }

    var body: some View {
        if tile.isCompact, !counts.isEmpty {
            Grid(horizontalSpacing: 8 * tile.scale, verticalSpacing: 10 * tile.scale) {
                ForEach(0..<(counts.count + 1) / 2, id: \.self) { line in
                    GridRow {
                        ForEach(counts.dropFirst(line * 2).prefix(2)) { item in
                            HStack(spacing: 3 * tile.scale) {
                                item.glyph.view(size: 10 * tile.scale)
                                Text("\(item.count)").tileStyle(.value)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let capacity = columns * perColumn
            let visible = rows.count > capacity ? capacity - 1 : rows.count
            HStack(spacing: tile.rowSpacing) {
                ForEach(0..<columns, id: \.self) { column in
                    VStack(spacing: tile.rowSpacing) {
                        ForEach(column * perColumn..<(column + 1) * perColumn, id: \.self) { index in
                            if index < visible {
                                chip(rows[index])
                            } else if index == visible, rows.count > visible {
                                Text("+\(rows.count - visible) more").tileStyle(.detail)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                Color.clear
                            }
                        }
                    }
                }
            }
        }
    }

    private func chip(_ row: ListRow) -> some View {
        TileChip(alert: row.alert) {
            HStack(spacing: 4 * tile.scale) {
                row.glyph.view(size: 10 * tile.scale)
                Text(row.title).lineLimit(1).tileStyle(mono ? .mono : .body, color: row.titleColor).fontWeight(.medium)
                if let trailing = row.trailing, !tile.isPortrait {
                    Spacer(minLength: 2)
                    Text(trailing).tileStyle(mono ? .mono : .detail).lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 6 · Media. The artwork tints the whole tile.
struct MediaTile: View {
    @Environment(\.tile) private var tile
    var title: String
    var artist: String?
    var album: String?
    /// Stand-in gradient when there's no artwork; also the tile tint.
    var art: [Color]
    var artwork: Image?
    var isPlaying = false
    var progress: Double?
    /// "1:24 / 3:41" at W.
    var time: String?
    /// 0...1 levels for the L waveform.
    var waveform: [Double] = []
    var onPlayPause: () -> Void = {}
    var onNext: () -> Void = {}
    var onPrevious: () -> Void = {}

    var body: some View {
        Group {
            if tile.isCompact {
                playButton(.scrim, diameter: 30).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tile.isPortrait {
                VStack(spacing: 6 * tile.scale) {
                    artView.frame(width: tile.contentSize.width, height: tile.contentSize.width)
                    Text(title).tileStyle(.title).minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    HStack(spacing: 10 * tile.scale) { playButton(.primary); nextButton }
                }
            } else {
                HStack(spacing: 9 * tile.scale) {
                    artView.frame(width: tile.contentSize.height)
                    if tile.size == .large { largeBody } else { regularBody }
                }
            }
        }
        .tileTint(art, opacity: tile.isCompact ? 1 : 0.38)
    }

    private var regularBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).tileStyle(.title)
            Text([artist, tile.size == .wide ? album : nil].compactMap(\.self).joined(separator: " · ")).tileStyle(.detail)
            Spacer(minLength: 2)
            HStack(spacing: (tile.size == .wide ? 5 : 8) * tile.scale) {
                if tile.size == .wide { previousButton }
                playButton(.primary)
                nextButton
                if tile.size == .wide, let time {
                    Spacer(minLength: 2)
                    Text(time).tileStyle(.detail).fixedSize()
                }
            }
            Spacer(minLength: 2)
            if let progress { Meter(fraction: progress, color: tile.surface.primary, thickness: 2.5) }
        }
    }

    private var largeBody: some View {
        HStack(spacing: 10 * tile.scale) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).tileStyle(.title)
                ForEach([artist, album].compactMap(\.self), id: \.self) { Text($0).tileStyle(.detail) }
            }
            Spacer(minLength: 4)
            VStack(spacing: 6 * tile.scale) {
                if !waveform.isEmpty { Waveform(levels: waveform, played: progress ?? 0) }
                HStack(spacing: 12 * tile.scale) { previousButton; playButton(.primary); nextButton }
            }
            .padding(.trailing, 8 * tile.scale)
        }
    }

    private var artView: some View {
        let shape = RoundedRectangle(cornerRadius: tile.innerRadius * 1.3, style: .continuous)
        return Group {
            if let artwork {
                artwork.resizable().scaledToFill()
            } else {
                LinearGradient(colors: art, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(shape)
        .accessibilityHidden(true)
    }

    private func playButton(_ style: TileIconButton.Style, diameter: CGFloat = 24) -> some View {
        TileIconButton(symbol: isPlaying ? "pause.fill" : "play.fill", label: isPlaying ? "Pause" : "Play",
                       style: style, diameter: diameter, action: onPlayPause)
    }

    private var nextButton: some View {
        TileIconButton(symbol: "forward.fill", label: "Next", style: .glyph, diameter: 18, action: onNext)
    }

    private var previousButton: some View {
        TileIconButton(symbol: "backward.fill", label: "Previous", style: .glyph, diameter: 18, action: onPrevious)
    }
}

private struct Waveform: View {
    @Environment(\.tile) private var tile
    let levels: [Double]
    let played: Double

    var body: some View {
        HStack(spacing: 2 * tile.scale) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(Double(index) / Double(levels.count) < played ? tile.surface.primary : tile.surface.tertiary)
                    .frame(width: 2.5 * tile.scale, height: max(3, 20 * tile.scale * levels[index]))
            }
        }
        .frame(height: 20 * tile.scale)
        .accessibilityHidden(true)
    }
}

/// 7 · Control: a round toggle (Wi-Fi). Compact is just the disc; wider sizes add the label and state.
struct ToggleTile: View {
    @Environment(\.tile) private var tile
    var symbol: String
    var label: String
    var isOn: Bool
    var detail: String?
    var action: () -> Void = {}

    var body: some View {
        let side = tile.contentSize.height * (tile.isCompact ? 0.95 : 0.7)
        HStack(spacing: 9 * tile.scale) {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(.system(size: side * 0.4, weight: .semibold))
                    .foregroundStyle(isOn ? .white : tile.surface.primary)
                    .frame(width: side, height: side)
                    .background(Circle().fill(isOn ? tile.accent : tile.surface.controlFill))
            }
            .buttonStyle(TilePressStyle())
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? "On" : "Off")
            if !tile.isCompact {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).tileStyle(.title)
                    if let detail { Text(detail).tileStyle(.detail) }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A Control Center slider: light fill on a dark track, square leading edge of the fill, glyph inside.
struct TileSlider: View {
    @Environment(\.tile) private var tile
    @Binding var value: Double
    var symbol: String?
    var label: String

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(tile.surface.controlFill)
                Rectangle().fill(tile.surface.controlOn).frame(width: geo.size.width * value.unitClamped)
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: geo.size.height * 0.42, weight: .semibold))
                        .foregroundStyle(tile.surface.controlOnInk)
                        .padding(.leading, geo.size.height * 0.45)
                }
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                value = (drag.location.x / geo.size.width).unitClamped
            })
        }
        .frame(height: 28 * tile.scale)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            value = (value + (direction == .increment ? 0.1 : -0.1)).unitClamped
        }
    }
}

/// 7 · Control: volume / brightness. M is the bare slider; W and L add a disc button and the value.
struct SliderTile: View {
    @Environment(\.tile) private var tile
    @Binding var value: Double
    var symbol: String
    var label: String
    var onSymbolTap: () -> Void = {}

    var body: some View {
        switch tile.size {
        case .compact:
            VStack(spacing: 4 * tile.scale) {
                TileIconButton(symbol: symbol, label: label, diameter: 34, action: onSymbolTap)
                Text("\(Int((value * 100).rounded()))").tileStyle(.value)
            }
        case .medium:
            TileSlider(value: $value, symbol: symbol, label: label)
        case .wide, .large:
            HStack(spacing: 10 * tile.scale) {
                TileIconButton(symbol: symbol, label: label, diameter: 30, action: onSymbolTap)
                TileSlider(value: $value, label: label)
                Text("\(Int((value * 100).rounded()))").tileStyle(.value).frame(minWidth: 24 * tile.scale, alignment: .trailing)
            }
        }
    }
}

struct ControlButton: Identifiable {
    var id: String { label }
    var symbol: String
    var label: String
    var isOn = false
    var action: () -> Void = {}
}

/// 7 · Control: Quick Actions. One square button per column; "on" buttons invert.
struct ButtonsTile: View {
    @Environment(\.tile) private var tile
    var buttons: [ControlButton]

    var body: some View {
        HStack(spacing: tile.rowSpacing * 1.5) {
            ForEach(buttons.prefix(tile.columns)) { button in
                Button(action: button.action) {
                    VStack(spacing: 4 * tile.scale) {
                        Image(systemName: button.symbol).font(.system(size: 14 * tile.scale, weight: .semibold))
                        if tile.showsLabel { Text(button.label).font(tile.font(.detail)).fontWeight(.medium).lineLimit(1) }
                    }
                    .foregroundStyle(button.isOn ? tile.surface.controlOnInk : tile.surface.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(button.isOn ? tile.surface.controlOn : tile.surface.controlFill,
                                in: RoundedRectangle(cornerRadius: tile.innerRadius, style: .continuous))
                }
                .buttonStyle(TilePressStyle())
                .accessibilityLabel(button.label)
                .accessibilityAddTraits(button.isOn ? .isSelected : [])
            }
        }
    }
}

/// An SF Symbol scaled to whatever frame the glyph slot gives it.
struct TileSymbol: View {
    var name: String
    var color: Color?

    var body: some View {
        Image(systemName: name).resizable().scaledToFit().fontWeight(.medium).foregroundStyle(color ?? .primary)
    }
}

/// 8 · Glyph. Moon, Thermal, Launchpad, Stack, Dice. Stops at M; wider widgets use Stat.
struct GlyphTile<Glyph: View>: View {
    @Environment(\.tile) private var tile
    var caption: String
    var title: String?
    var details: [String] = []
    var captionColor: Color?
    @ViewBuilder var glyph: Glyph

    var body: some View {
        if tile.isCompact {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                glyph.frame(width: tile.contentSize.height * 0.44, height: tile.contentSize.height * 0.44)
                Spacer(minLength: 0)
                Text(caption).tileStyle(.caption, color: captionColor)
            }
            .padding(.vertical, 2 * tile.scale)
            .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: 11 * tile.scale) {
                glyph.frame(width: tile.contentSize.height * 0.55, height: tile.contentSize.height * 0.55)
                    .padding(.leading, 4 * tile.scale)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title ?? caption).lineLimit(2).tileStyle(.title)
                    ForEach(details, id: \.self) { Text($0).tileStyle(.detail) }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
