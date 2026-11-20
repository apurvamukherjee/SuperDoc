import SwiftUI

extension Color {
    /// 0xRRGGBB in sRGB.
    init(rgb: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255, opacity: opacity)
    }
}

/// Brand and semantic hues, measured off the design mockups. They read on every surface, so they don't vary by style;
/// where a hue is too light for text on white, `SurfaceTokens` has a text-safe variant (danger, good, warning).
enum Palette {
    static let claude = Color(rgb: 0xFFB547)
    /// Claude's weekly window, the paler ring in the Watch-style gauge.
    static let claudeSoft = Color(rgb: 0xF7D7A1)
    static let codex = Color(rgb: 0xB69CFF)
    static let codexSoft = Color(rgb: 0x9A87D5)
    /// Danger (≥ 80 %), needs-you, critical, calendar today.
    static let coral = Color(rgb: 0xFF5A4E)
    static let working = Color(rgb: 0x4C8DFF)
    /// Default fill for progress bars and charts.
    static let progress = Color(rgb: 0x5AA2FF)
    static let done = Color(rgb: 0x34C77B)
    /// Healthy readings: memory "Normal", checks, network down.
    static let good = Color(rgb: 0x4FD48A)
    static let idle = Color(rgb: 0x8E8E93)
    static let amber = Color(rgb: 0xFFB340)
    static let hot = Color(rgb: 0xFF8A3D)
    static let water = Color(rgb: 0x3FD0E6)
    static let note = Color(rgb: 0xFFD15C)
    static let today = coral
    static let ink = Color(rgb: 0x26282E)
    static let inkDeep = Color(rgb: 0x0E0F12)
    static let cream = Color(rgb: 0xFBF9F4)
    static let creamDeep = Color(rgb: 0xE4DFD3)
}

/// A bar style resolved against light/dark mode and Reduce Transparency: the only thing tile colours depend on.
enum SurfaceStyle: String, CaseIterable, Sendable {
    case glassDark = "glass-dark", glassLight = "glass-light"
    case frostedDark = "frosted-dark", frostedLight = "frosted-light"
    case solidDark = "solid-dark", solidLight = "solid-light"
    case paper

    static func resolve(_ style: BarStyle, isDark: Bool, reduceTransparency: Bool) -> SurfaceStyle {
        switch style {
        case .glass where !reduceTransparency: isDark ? .glassDark : .glassLight
        case .frosted where !reduceTransparency: isDark ? .frostedDark : .frostedLight
        case .glass, .frosted: isDark ? .solidDark : .solidLight
        case .dark: .solidDark
        case .light: .solidLight
        case .paper: .paper
        }
    }

    var isDark: Bool { [.glassDark, .frostedDark, .solidDark].contains(self) }
    var isTranslucent: Bool { [.glassDark, .glassLight, .frostedDark, .frostedLight].contains(self) }
}

/// Every colour a tile draws with. Tiles read these (through `TileContext.surface`), never raw system styles,
/// so one layout works on every style, mode and wallpaper.
struct SurfaceTokens: Equatable, Sendable {
    let style: SurfaceStyle
    var isDark: Bool { style.isDark }

    /// Exact for solid and paper; an approximation of the material for glass/frosted (gallery and previews only).
    let barFill: Color
    let barStroke: Color
    let tileFill: Color
    let tileStroke: Color
    /// Setup outlines and empty-slot hairlines.
    let strongStroke: Color
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let track: Color
    let chipFill: Color
    let divider: Color
    let skeleton: Color
    /// Light styles lift tiles off busy wallpapers with a soft shadow; clear on dark styles.
    let shadow: Color
    /// Round Control Center buttons when off; `controlOn` + `controlOnInk` when on, and slider fills.
    let controlFill: Color
    let controlOn: Color
    let controlOnInk: Color
    /// Text-safe semantic colours (the raw Palette hues are too light for text on white).
    let danger: Color
    let good: Color
    let warning: Color

    init(_ style: SurfaceStyle, tileBackgrounds: Bool = true) {
        self.style = style
        let dark = style.isDark
        let white = { (opacity: Double) in Color(white: 1, opacity: opacity) }
        let black = { (opacity: Double) in Color(white: 0, opacity: opacity) }
        let ink = style == .paper ? Palette.ink : Color(rgb: 0x141518)

        let fills: Fills = switch style {
        case .glassDark: Fills(white(0.10), white(0.075), white(0.10))
        case .frostedDark: Fills(Color(rgb: 0x2A2540, opacity: 0.72), white(0.08), white(0.08))
        case .solidDark: Fills(Color(rgb: 0x1F1F21), Color(rgb: 0x2A2B2F), white(0.06))
        // Over a bright photo the tile itself must carry contrast, so it is nearly opaque.
        case .glassLight: Fills(white(0.45), white(0.90), black(0.05))
        case .frostedLight: Fills(white(0.70), white(0.88), black(0.05))
        case .solidLight: Fills(Color(rgb: 0xF5F5F6), .white, black(0.06))
        case .paper: Fills(Palette.cream, .white, Color(rgb: 0xE4E2DE))
        }
        barFill = fills.bar
        tileFill = tileBackgrounds ? fills.tile : .clear
        tileStroke = tileBackgrounds ? fills.stroke : .clear
        barStroke = dark ? white(0.14) : black(0.06)
        strongStroke = dark ? white(0.28) : black(0.22)
        primary = dark ? white(0.96) : ink
        secondary = dark ? white(0.62) : ink.opacity(0.58)
        tertiary = dark ? white(0.38) : ink.opacity(0.36)
        track = dark ? white(0.14) : black(0.08)
        chipFill = dark ? white(0.07) : black(0.045)
        divider = dark ? white(0.12) : black(0.08)
        skeleton = dark ? white(0.10) : black(0.07)
        shadow = dark ? .clear : black(style == .glassLight ? 0.10 : 0.06)
        controlFill = dark ? white(0.14) : black(0.06)
        controlOn = dark ? Color(rgb: 0xF1F1F3) : Color(rgb: 0x2A2B2F)
        controlOnInk = dark ? Color(rgb: 0x141518) : .white
        danger = dark ? Color(rgb: 0xFF6B5F) : Color(rgb: 0xD93025)
        good = dark ? Palette.good : Color(rgb: 0x1F9D57)
        warning = dark ? Palette.amber : Color(rgb: 0xB86E00)
    }

    private struct Fills {
        let bar: Color, tile: Color, stroke: Color
        init(_ bar: Color, _ tile: Color, _ stroke: Color) { (self.bar, self.tile, self.stroke) = (bar, tile, stroke) }
    }

    /// Bar background for the solid styles, shared with the AppKit bar panel.
    static func solidBarFill(_ style: BarStyle) -> Color {
        switch style {
        case .paper: SurfaceTokens(.paper).barFill
        case .light: SurfaceTokens(.solidLight).barFill
        case .dark, .glass, .frosted: SurfaceTokens(.solidDark).barFill
        }
    }
}

extension AIProvider {
    var tint: Color { self == .claude ? Palette.claude : Palette.codex }
    /// Paler hue for the provider's weekly window.
    var softTint: Color { self == .claude ? Palette.claudeSoft : Palette.codexSoft }
    /// We can't use brand marks, so each provider is a coloured monogram.
    var monogram: String { self == .claude ? "C" : "X" }
    var monogramInk: Color { self == .claude ? Palette.ink : .white }
}

extension AgentStatus {
    var tint: Color {
        switch self {
        case .working: Palette.working
        case .needsInput: Palette.coral
        case .done: Palette.good
        case .idle: Palette.idle
        }
    }
}
