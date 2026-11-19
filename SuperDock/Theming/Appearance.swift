import AppKit
import SwiftUI

enum BarStyle: String, CaseIterable {
    case glass, frosted, dark, light

    var title: LocalizedStringKey {
        switch self {
        case .glass: "Liquid Glass"
        case .frosted: "Frosted"
        case .dark: "Solid dark"
        case .light: "Solid light"
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
        var cornerRadius: CGFloat
        var opacity: CGFloat
    }

    @MainActor static var current: Values {
        let defaults = UserDefaults.standard
        var style = defaults.string(forKey: styleKey).flatMap(BarStyle.init) ?? .glass
        // Reduce Transparency wins over any see-through style.
        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency, style == .glass || style == .frosted {
            style = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        }
        return Values(style: style,
                      cornerRadius: defaults.object(forKey: cornerRadiusKey) as? Double ?? defaultCornerRadius,
                      opacity: defaults.object(forKey: opacityKey) as? Double ?? 1)
    }

    /// Background view for the bar. Liquid Glass needs macOS 26; older systems get frosted instead.
    @MainActor
    static func background(for values: Values) -> NSView {
        let view: NSView
        switch values.style {
        case .glass where isGlassAvailable:
            if #available(macOS 26, *) {
                let glass = NSGlassEffectView()
                glass.cornerRadius = values.cornerRadius
                view = glass
            } else {
                view = frosted()
            }
        case .glass, .frosted:
            view = frosted()
        case .dark, .light:
            view = NSView()
            view.wantsLayer = true
            view.layer?.backgroundColor = (values.style == .dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.96, alpha: 1)).cgColor
        }
        view.wantsLayer = true
        view.layer?.cornerRadius = values.cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        view.alphaValue = values.opacity
        return view
    }

    private static var isGlassAvailable: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    @MainActor
    private static func frosted() -> NSView {
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        return blur
    }
}
