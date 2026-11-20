import SwiftUI

/// What a widget asks of its tile's chrome, sent up with `.tileTint(_:)` / `.tileOutline(_:)`.
struct TileAppearance: Equatable, Sendable {
    enum Outline: Equatable, Sendable {
        case none
        /// Needs-you: coral hairline with a soft glow.
        case alert
        /// Needs setup: brighter hairline.
        case setup
        /// A placeholder slot: dashed hairline, no fill.
        case dashed
    }

    /// Colours washed over the tile fill, top-leading to bottom-trailing (art, sky, note paper). Empty = plain tile.
    var tint: [Color] = []
    /// How strongly the tint covers the fill, 0...1.
    var tintOpacity: Double = 1
    var outline = Outline.none
}

private struct TileAppearanceKey: PreferenceKey {
    static let defaultValue = TileAppearance()

    static func reduce(value: inout TileAppearance, nextValue: () -> TileAppearance) {
        let next = nextValue()
        if !next.tint.isEmpty { value.tint = next.tint; value.tintOpacity = next.tintOpacity }
        if next.outline != .none { value.outline = next.outline }
    }
}

extension View {
    /// Washes the whole tile in `colors` (media art, weather sky, note paper). One colour = flat tint.
    func tileTint(_ colors: [Color], opacity: Double = 1) -> some View {
        preference(key: TileAppearanceKey.self, value: TileAppearance(tint: colors, tintOpacity: opacity))
    }

    func tileTint(_ color: Color?, opacity: Double = 1) -> some View {
        tileTint(color.map { [$0] } ?? [], opacity: opacity)
    }

    func tileOutline(_ outline: TileAppearance.Outline) -> some View {
        preference(key: TileAppearanceKey.self, value: TileAppearance(outline: outline))
    }

    /// Draws `self` as one bar tile: padding, fixed frame, fill, hairline, continuous corners, light-style shadow,
    /// plus whatever tint/outline the content asked for. Reads size and surface from `\.tile`.
    func tileChrome() -> some View {
        modifier(TileChrome())
    }
}

struct TileChrome: ViewModifier {
    @Environment(\.tile) private var tile

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: tile.radius, style: .continuous)
        let surface = tile.surface
        content
            .padding(tile.padding)
            .frame(width: tile.frame.width, height: tile.frame.height)
            .backgroundPreferenceValue(TileAppearanceKey.self) { appearance in
                if !appearance.tint.isEmpty {
                    LinearGradient(colors: appearance.tint, startPoint: .topLeading, endPoint: .bottomTrailing)
                        .opacity(appearance.tintOpacity)
                }
            }
            .clipShape(shape)
            .background {
                // Fill and shadow sit outside the clip so the shadow isn't cut off.
                shape.fill(surface.tileFill).shadow(color: surface.shadow, radius: 5 * tile.scale, y: 1.5)
            }
            .overlayPreferenceValue(TileAppearanceKey.self) { appearance in
                TileOutlineView(outline: appearance.outline, shape: shape, surface: surface)
            }
            .contentShape(shape)
    }
}

private struct TileOutlineView: View {
    let outline: TileAppearance.Outline
    let shape: RoundedRectangle
    let surface: SurfaceTokens

    var body: some View {
        switch outline {
        case .none:
            shape.strokeBorder(surface.tileStroke, lineWidth: 1)
        case .alert:
            shape.strokeBorder(Palette.coral.opacity(0.9), lineWidth: 1.5)
                .shadow(color: Palette.coral.opacity(0.45), radius: 6)
        case .setup:
            shape.strokeBorder(surface.strongStroke, lineWidth: 1)
        case .dashed:
            shape.strokeBorder(surface.strongStroke, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
    }
}

/// The bar's own background for hand-built bars (gallery, previews). The real bar uses AppKit materials.
struct BarBackdrop: View {
    let surface: SurfaceTokens
    var radius: CGFloat = 18

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape.fill(surface.barFill)
            .overlay(shape.strokeBorder(surface.barStroke, lineWidth: 1))
            .shadow(color: .black.opacity(surface.isDark ? 0.35 : 0.12), radius: 14, y: 6)
    }
}
