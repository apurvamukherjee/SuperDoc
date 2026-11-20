import SwiftUI

// Pure Control Center views: plain values in, callbacks out. The widgets in ControlWidgets.swift wire them to services.

/// Quick Actions: round Control Center buttons, 1 at C, 3 at M, 6 at W. An "on" toggle (Dark Mode) turns white.
struct QuickActionsView: View {
    struct Item: Identifiable {
        var id: String
        var symbol: String
        var label: String
        var isOn = false
        var action: () -> Void = {}
    }

    @Environment(\.tile) private var tile
    var items: [Item]

    private var capacity: Int {
        switch tile.size {
        case .compact: 1
        case .medium: 3
        case .wide: 6
        case .large: 8
        }
    }

    var body: some View {
        if items.isEmpty {
            TileStateView(state: .needsSetup(verb: "Choose", title: "No actions", detail: "Pick some in Widget Settings"))
        } else {
            let shown = Array(items.prefix(capacity))
            let gap = 6 * tile.scale
            let length = tile.isPortrait ? tile.contentSize.height : tile.contentSize.width
            let cross = tile.isPortrait ? tile.contentSize.width : tile.contentSize.height
            let fit = (length - gap * CGFloat(shown.count - 1)) / CGFloat(shown.count)
            let diameter = min(cross * (tile.isCompact ? 0.82 : 0.66), fit)
            let layout = tile.isPortrait ? AnyLayout(VStackLayout(spacing: gap)) : AnyLayout(HStackLayout(spacing: gap))
            layout {
                ForEach(shown) { item in
                    TileIconButton(symbol: item.symbol, label: item.label, style: item.isOn ? .primary : .disc,
                                   diameter: diameter / tile.scale, action: item.action)
                        .help(item.label)
                        .accessibilityAddTraits(item.isOn ? .isSelected : [])
                }
            }
            .tileAnimation(value: shown.map(\.isOn))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Volume. C (and portrait) is a vertical Control Center slider, M the bare slider, W adds a mute disc and the value.
struct VolumeView: View {
    @Environment(\.tile) private var tile
    /// 0...1.
    var level: Double
    var isMuted = false
    /// false when the output (some HDMI displays) has no software volume.
    var isAdjustable = true
    var setLevel: @MainActor (Double) -> Void = { _ in }
    var toggleMute: () -> Void = {}

    private var symbol: String {
        if isMuted { return "speaker.slash" }
        if level <= 0 { return "speaker" }
        return "speaker.wave.\(level < 0.34 ? 1 : level < 0.67 ? 2 : 3)"
    }

    private var muteLabel: String { isMuted ? "Unmute" : "Mute" }

    var body: some View {
        let value = Binding(get: { level }, set: setLevel)
        Group {
            if !isAdjustable {
                UnavailableSlider(symbol: "speaker.slash", note: "Not adjustable on this output")
            } else if tile.isCompact || tile.isPortrait {
                VerticalTileSlider(value: value, symbol: symbol, label: "Volume")
            } else if tile.size == .medium {
                TileSlider(value: value, symbol: symbol, label: "Volume")
            } else {
                HStack(spacing: 10 * tile.scale) {
                    TileIconButton(symbol: symbol, label: muteLabel, diameter: 30, action: toggleMute)
                    TileSlider(value: value, label: "Volume")
                    SliderValue(level: level)
                }
            }
        }
        .accessibilityAction(named: Text(muteLabel), toggleMute)
    }
}

/// Brightness. nil level = the display isn't software-adjustable (most external displays).
struct BrightnessView: View {
    @Environment(\.tile) private var tile
    var level: Double?
    var setLevel: @MainActor (Double) -> Void = { _ in }

    var body: some View {
        if let level {
            let value = Binding(get: { level }, set: setLevel)
            if tile.isCompact || tile.isPortrait {
                VerticalTileSlider(value: value, symbol: "sun.max", label: "Brightness")
            } else if tile.size == .medium {
                TileSlider(value: value, symbol: "sun.max", label: "Brightness")
            } else {
                HStack(spacing: 10 * tile.scale) {
                    Image(systemName: "sun.max").font(.system(size: 14 * tile.scale, weight: .medium))
                        .foregroundStyle(tile.surface.secondary)
                        .accessibilityHidden(true)
                    TileSlider(value: value, label: "Brightness")
                    SliderValue(level: level)
                }
                .padding(.leading, 4 * tile.scale)
            }
        } else {
            UnavailableSlider(symbol: "sun.max", note: "Not adjustable on this display")
        }
    }
}

/// Wi-Fi: a round toggle, accent when on. nil = no Wi-Fi hardware.
struct WiFiView: View {
    @Environment(\.tile) private var tile
    var isOn: Bool?
    var toggle: () -> Void = {}

    var body: some View {
        let side = min(tile.contentSize.height, tile.contentSize.width) * 0.82
        let isLit = isOn == true
        Button(action: toggle) {
            Image(systemName: isLit ? "wifi" : "wifi.slash")
                .font(.system(size: side * 0.36, weight: .semibold))
                .foregroundStyle(isLit ? .white : tile.surface.secondary)
                .frame(width: side, height: side)
                .background(Circle().fill(isLit ? tile.accent : tile.surface.controlFill))
                .contentShape(Circle())
        }
        .buttonStyle(TilePressStyle())
        .disabled(isOn == nil)
        .opacity(isOn == nil ? 0.5 : 1)
        .tileAnimation(value: isLit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .help(isOn == nil ? "No Wi-Fi hardware" : isLit ? "Wi-Fi on" : "Wi-Fi off")
        .accessibilityLabel(isLit ? "Turn Wi-Fi off" : "Turn Wi-Fi on")
    }
}

/// The 0–100 readout beside a W slider.
private struct SliderValue: View {
    @Environment(\.tile) private var tile
    var level: Double

    var body: some View {
        Text("\(Int((level * 100).rounded()))").tileStyle(.value)
            .frame(minWidth: 24 * tile.scale, alignment: .trailing)
            .accessibilityHidden(true)
    }
}

// ponytail: a private copy of the kit's TileSlider turned upright; fold into TileSlider as an `axis` if others need it.
/// The Control Center pill standing up: fills from the bottom, glyph at the foot.
private struct VerticalTileSlider: View {
    @Environment(\.tile) private var tile
    @Binding var value: Double
    var symbol: String
    var label: String

    var body: some View {
        let width = min(30 * tile.scale, tile.contentSize.width)
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Rectangle().fill(tile.surface.controlFill)
                Rectangle().fill(tile.surface.controlOn).frame(height: geo.size.height * value.unitClamped)
                Image(systemName: symbol)
                    .font(.system(size: width * 0.4, weight: .semibold))
                    // The glyph sits at the foot, so it is on the fill unless the level is nearly zero.
                    .foregroundStyle(value > 0.2 ? tile.surface.controlOnInk : tile.surface.primary)
                    .padding(.bottom, width * 0.4)
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                value = (1 - drag.location.y / geo.size.height).unitClamped
            })
        }
        .frame(width: width)
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            value = (value + (direction == .increment ? 0.1 : -0.1)).unitClamped
        }
    }
}

/// An empty, dimmed slider with the reason under it. Upright at C and in portrait, where the reason is the tooltip.
private struct UnavailableSlider: View {
    @Environment(\.tile) private var tile
    var symbol: String
    var note: String

    var body: some View {
        let glyph = Image(systemName: symbol).font(.system(size: 12 * tile.scale, weight: .semibold))
            .foregroundStyle(tile.surface.tertiary)
        Group {
            if tile.isCompact || tile.isPortrait {
                Capsule().fill(tile.surface.controlFill)
                    .overlay(alignment: .bottom) { glyph.padding(.bottom, 12 * tile.scale) }
                    .frame(width: min(30 * tile.scale, tile.contentSize.width))
                    .frame(maxWidth: .infinity)
                    .help(note)
            } else {
                VStack(alignment: .leading, spacing: 5 * tile.scale) {
                    Capsule().fill(tile.surface.controlFill)
                        .overlay(alignment: .leading) { glyph.padding(.leading, 12 * tile.scale) }
                        .frame(height: 28 * tile.scale)
                    Text(note).tileStyle(.detail).minimumScaleFactor(0.85)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(note)
    }
}
