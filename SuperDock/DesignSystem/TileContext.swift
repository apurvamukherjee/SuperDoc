import SwiftUI

/// How much a tile can say at the current Dock size: tight drops labels and detail, roomy adds a detail line.
enum TileTier: Int, Comparable, Sendable {
    case tight, regular, roomy

    static func < (lhs: TileTier, rhs: TileTier) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Everything a tile may know about where it is drawn. Widgets read this (`@Environment(\.tile)`), never
/// @AppStorage, so the gallery can render any style at any size.
struct TileContext: Equatable, Sendable {
    /// Side of a compact tile: bar thickness − 12.
    var unit: CGFloat = 73
    var size: TileSize = .compact
    /// Vertical bar: the tile is one unit wide and `columns` units tall.
    var isPortrait = false
    var surface = SurfaceTokens(.glassDark)
    var accent: Color = Palette.progress
    /// Bar corner radius − 6, at least 4.
    var radius: CGFloat = 12

    static let spacing: CGFloat = 6
    /// The design is drawn at an 85 pt bar.
    static let designUnit: CGFloat = 73

    var columns: Int { size.columns }
    var isCompact: Bool { size == .compact }

    var tier: TileTier {
        if unit < 60 { return .tight }
        return unit >= 100 ? .roomy : .regular
    }

    /// Type and stroke scale relative to the design unit. Clamped so a huge Dock gets room, not billboard text.
    var scale: CGFloat { min(max(unit / Self.designUnit, 0.62), 1.3) }

    var padding: CGFloat { min(max((6 * scale).rounded(), 4), 8) }

    var frame: CGSize {
        let length = Self.length(columns: columns, unit: unit)
        return isPortrait ? CGSize(width: unit, height: length) : CGSize(width: length, height: unit)
    }

    var contentSize: CGSize { CGSize(width: frame.width - 2 * padding, height: frame.height - 2 * padding) }

    var showsLabel: Bool { tier > .tight }
    var showsDetail: Bool { tier > .tight }
    var showsExtraDetail: Bool { tier == .roomy }

    /// Gap between stacked rows/chips inside a tile.
    var rowSpacing: CGFloat { (4 * scale).rounded() }
    /// Corner radius for chips, fields and buttons inside a tile.
    var innerRadius: CGFloat { max(4, min(radius - 4, 7 * scale)) }

    static func length(columns: Int, unit: CGFloat) -> CGFloat {
        CGFloat(columns) * unit + CGFloat(max(columns - 1, 0)) * spacing
    }

    func font(_ style: TileTextStyle) -> Font { style.font(scale: scale) }
}

extension EnvironmentValues {
    @Entry var tile = TileContext()
}

/// The type scale, tuned at unit 73 (85 pt bar) and scaled with the tile.
enum TileTextStyle: Sendable {
    /// Small caps-ish: "CPU", "MEMORY", "5H". Semibold, tracked, secondary.
    case label
    /// Even smaller tracked caption under glyphs and states: "OFFLINE", "WANING".
    case caption
    /// Big numerals on the baseline: "11.2", "62%".
    case hero
    /// Hero when it shares a compact tile with a chart, bar or ring: "23%".
    case heroCompact
    /// The biggest numerals: date "19", wide clock.
    case display
    /// Suffix after a hero: "GB", "%". Smaller and secondary.
    case heroUnit
    /// Trailing values in meter rows: "96%".
    case value
    /// Names and state titles: "Night Drive", "All quiet".
    case title
    /// Notes, chip text, list rows.
    case body
    /// Secondary line: "of 16 GB", "2h 14m".
    case detail
    /// SF Mono for developer tiles.
    case mono
    /// Large SF Mono: epoch seconds, passwords.
    case monoHero
    /// Monogram letters in provider badges.
    case badge

    // swiftlint:disable:next cyclomatic_complexity
    func font(scale: CGFloat) -> Font {
        let font: Font = switch self {
        case .label: .system(size: 9.5 * scale, weight: .semibold)
        case .caption: .system(size: 8.5 * scale, weight: .semibold)
        case .hero: .system(size: 25 * scale, weight: .semibold)
        case .heroCompact: .system(size: 18.5 * scale, weight: .semibold)
        case .display: .system(size: 32 * scale, weight: .semibold)
        case .heroUnit: .system(size: 12.5 * scale, weight: .medium)
        case .value: .system(size: 14.5 * scale, weight: .semibold)
        case .title: .system(size: 12.5 * scale, weight: .semibold)
        case .body: .system(size: 11.5 * scale, weight: .regular)
        case .detail: .system(size: 10.5 * scale, weight: .regular)
        case .mono: .system(size: 11 * scale, weight: .medium, design: .monospaced)
        case .monoHero: .system(size: 17 * scale, weight: .medium, design: .monospaced)
        case .badge: .system(size: 8.5 * scale, weight: .heavy, design: .rounded)
        }
        return isNumeric ? font.monospacedDigit() : font
    }

    var isNumeric: Bool { [.hero, .heroCompact, .display, .value, .heroUnit, .detail].contains(self) }
    var isUppercase: Bool { self == .label || self == .caption }
    var tracking: CGFloat {
        switch self {
        case .label: 0.9
        case .caption: 1.0
        case .hero, .display, .heroCompact: -0.3
        default: 0
        }
    }

    func defaultColor(_ surface: SurfaceTokens) -> Color {
        switch self {
        case .label, .caption, .heroUnit, .detail: surface.secondary
        default: surface.primary
        }
    }
}

private struct TileTextModifier: ViewModifier {
    @Environment(\.tile) private var tile
    let style: TileTextStyle
    let color: Color?

    func body(content: Content) -> some View {
        let styled = content
            .font(tile.font(style))
            .tracking(style.tracking * tile.scale)
            .textCase(style.isUppercase ? .uppercase : nil)
            .foregroundStyle(color ?? style.defaultColor(tile.surface))
        if style == .body { styled } else { styled.lineLimit(1) }
    }
}

extension View {
    /// Applies a type-scale style (font, tracking, case, colour from surface tokens). Single line except `.body`;
    /// a `.lineLimit` placed before this call wins, since the innermost limit applies.
    func tileStyle(_ style: TileTextStyle, color: Color? = nil) -> some View {
        modifier(TileTextModifier(style: style, color: color))
    }

    /// Lets a chart or artwork run to the tile's edges, past the inner padding (the chrome clips it).
    func tileBleed(_ edges: Edge.Set = [.horizontal, .bottom]) -> some View {
        modifier(BleedModifier(edges: edges))
    }

    /// Context for a hand-built tile (gallery, settings previews). The bar sets this itself.
    func tileContext(_ context: TileContext) -> some View {
        environment(\.tile, context)
            .environment(\.colorScheme, context.surface.isDark ? .dark : .light)
    }
}

private struct BleedModifier: ViewModifier {
    @Environment(\.tile) private var tile
    let edges: Edge.Set

    func body(content: Content) -> some View {
        content.padding(edges, -tile.padding)
    }
}
