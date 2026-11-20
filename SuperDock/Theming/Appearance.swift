import AppKit
import SwiftUI

enum BarStyle: String, CaseIterable {
    case glass, frosted, dark, light, paper

    var title: LocalizedStringKey {
        switch self {
        case .glass: "Liquid Glass"
        case .frosted: "Frosted"
        case .dark: "Solid dark"
        case .light: "Solid light"
        case .paper: "Paper"
        }
    }
}

/// Bar look, shared by Settings (@AppStorage) and the bar.
enum AppearancePrefs {
    static let styleKey = "appearance.style"
    static let cornerRadiusKey = "appearance.cornerRadius"
    static let opacityKey = "appearance.opacity"
    static let accentKey = "appearance.accent"          // "#RRGGBB", or "" for the system accent
    static let tileBackgroundsKey = "appearance.tileBackgrounds"

    static let defaultCornerRadius = 18.0

    struct Values: Equatable {
        var style: BarStyle
        var isDark: Bool
        var reduceTransparency: Bool
        var cornerRadius: CGFloat
        var opacity: CGFloat

        /// The same resolution the tiles get, so bar and tiles always agree on style and mode.
        var surface: SurfaceStyle { SurfaceStyle.resolve(style, isDark: isDark, reduceTransparency: reduceTransparency) }
    }

    @MainActor static var current: Values {
        let defaults = UserDefaults.standard
        return Values(style: defaults.string(forKey: styleKey).flatMap(BarStyle.init) ?? .glass,
                      isDark: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua,
                      reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
                      cornerRadius: defaults.object(forKey: cornerRadiusKey) as? Double ?? defaultCornerRadius,
                      opacity: defaults.object(forKey: opacityKey) as? Double ?? 1)
    }

    /// Background view for the bar. Liquid Glass needs macOS 26; older systems get frosted instead.
    @MainActor
    static func background(for values: Values) -> NSView {
        let surface = values.surface
        let tokens = SurfaceTokens(surface)
        let view: NSView
        var drawsOwnEdge = false
        switch surface {
        case .glassDark, .glassLight:
            if #available(macOS 26, *) {
                let glass = NSGlassEffectView()
                glass.cornerRadius = values.cornerRadius
                view = glass
                drawsOwnEdge = true
            } else {
                view = frosted(isDark: surface.isDark)
            }
        case .frostedDark, .frostedLight:
            view = frosted(isDark: surface.isDark)
        case .solidDark, .solidLight, .paper:
            view = NSView()
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor(tokens.barFill).cgColor
        }
        view.wantsLayer = true
        view.layer?.cornerRadius = values.cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        // Liquid Glass draws its own edge; everything else gets the hairline the mockups show around the bar.
        if !drawsOwnEdge {
            view.layer?.borderWidth = 1
            view.layer?.borderColor = NSColor(tokens.barStroke).cgColor
        }
        view.alphaValue = values.opacity
        return view
    }

    @MainActor
    private static func frosted(isDark: Bool) -> NSView {
        let blur = NSVisualEffectView()
        // HUD material is always dark; the light frosted bar needs one that follows the appearance.
        blur.material = isDark ? .hudWindow : .popover
        blur.blendingMode = .behindWindow
        blur.state = .active
        return blur
    }
}
