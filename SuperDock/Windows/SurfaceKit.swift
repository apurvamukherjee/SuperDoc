import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension EnvironmentValues {
    /// Set by the gallery: draw surfaces in this style with token fills, because ImageRenderer can't draw materials,
    /// scroll views or text fields. nil = live, styled like the user's bar.
    @Entry var surfaceSnapshot: SurfaceStyle?
}

/// The shared look of every panel around the bar: the bar's own background, the kit's tokens, and the tile type scale
/// at 1.1× so panel text sits a step above tile text.
enum SurfaceKit {
    static let unit = TileContext.designUnit * 1.1

    /// The same icon the Finder shows; for paths that don't exist (fixtures, files moved since) the type's icon.
    @MainActor
    static func icon(for url: URL) -> NSImage {
        if FileManager.default.fileExists(atPath: url.path) { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSWorkspace.shared.icon(for: UTType(filenameExtension: url.pathExtension) ?? .data)
    }
}

/// The menu bar extra's header line: "SuperDock · 3 agents · 62%".
enum MenuStatus {
    /// Agents that aren't idle, and the most-used limit window across providers (the one that matters next).
    static func title(sessions: [AgentSessionService.Session], usage: [AIProvider: AIUsageService.Usage],
                      now: Date = Date()) -> String {
        var parts = ["SuperDock"]
        let active = sessions.filter { $0.status != .idle }.count
        if active > 0 { parts.append(active == 1 ? String(localized: "1 agent") : String(localized: "\(active) agents")) }
        if let top = usage.values.flatMap(\.windows).map({ $0.usedPercent(at: now) }).max() {
            parts.append("\(Int(top.rounded()))%")
        }
        return parts.joined(separator: " · ")
    }
}

extension View {
    /// Root of a surface: resolves the bar style against light/dark and Reduce Transparency, and exposes its tokens
    /// through `\.tile` so `tileStyle` and `tile.surface` work inside panels.
    func surfaceContext() -> some View {
        modifier(SurfaceContextModifier())
    }

    /// Panel background: the bar's material (Liquid Glass, frosted or solid) with a hairline.
    func surfacePanel(radius: CGFloat = 18) -> some View {
        modifier(SurfacePanelModifier(radius: radius))
    }

    /// The pop spring on appear (scale up from `from` and fade in); a plain fade under Reduce Motion.
    func surfacePop(from scale: CGFloat = 0.92, anchor: UnitPoint = .center) -> some View {
        modifier(SurfacePopModifier(scale: scale, anchor: anchor))
    }
}

private struct SurfaceContextModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.surfaceSnapshot) private var snapshot

    func body(content: Content) -> some View {
        let style = snapshot ?? SurfaceStyle.resolve(AppearancePrefs.current.style, isDark: scheme == .dark,
                                                     reduceTransparency: reduceTransparency)
        content.tileContext(TileContext(unit: SurfaceKit.unit, surface: SurfaceTokens(style)))
    }
}

private struct SurfacePanelModifier: ViewModifier {
    @Environment(\.tile) private var tile
    @Environment(\.surfaceSnapshot) private var snapshot
    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                if snapshot != nil {
                    BarBackdrop(surface: tile.surface, radius: radius)
                } else {
                    // The panel's window draws the shadow; a SwiftUI one would be clipped by the window's bounds.
                    BarMaterial(radius: radius).clipShape(shape)
                }
            }
            .overlay(shape.strokeBorder(tile.surface.barStroke, lineWidth: 1))
    }
}

/// The bar's own background view, so panels match whatever style the user picked for the bar.
private struct BarMaterial: NSViewRepresentable {
    let radius: CGFloat

    func makeNSView(context: Context) -> NSView {
        var values = AppearancePrefs.current
        values.cornerRadius = radius
        values.opacity = 1
        return AppearancePrefs.background(for: values)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private struct SurfacePopModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.surfaceSnapshot) private var snapshot
    @State private var shown = false
    let scale: CGFloat
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        let visible = shown || snapshot != nil
        content
            .scaleEffect(visible || reduceMotion ? 1 : scale, anchor: anchor)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(reduceMotion ? Motion.reduced : Motion.pop) { shown = true }
            }
    }
}

/// A small keyboard shortcut cap: "⌥⌘V", "↩".
struct KeyCap: View {
    @Environment(\.tile) private var tile
    let keys: String

    init(_ keys: String) {
        self.keys = keys
    }

    var body: some View {
        Text(keys)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tile.surface.secondary)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(tile.surface.controlFill, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// A rounded search well with a magnifier. In gallery snapshots the AppKit text field is replaced by its prompt.
struct SurfaceSearchField: View {
    @Environment(\.tile) private var tile
    @Environment(\.surfaceSnapshot) private var snapshot
    let prompt: LocalizedStringKey
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    var height: CGFloat = 30

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .semibold)).foregroundStyle(tile.surface.secondary)
            if snapshot != nil {
                Text(prompt).font(tile.font(.body)).foregroundStyle(tile.surface.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(prompt, text: $text).textFieldStyle(.plain).font(tile.font(.body)).focused(focus)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .background(tile.surface.chipFill, in: Capsule())
        .overlay(Capsule().strokeBorder(tile.surface.divider, lineWidth: 1))
    }
}

/// A symbol on a soft rounded square: the type icon in clipboard and shelf rows.
struct SurfaceGlyph: View {
    @Environment(\.tile) private var tile
    let symbol: String
    var tint: Color?
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint ?? tile.surface.primary.opacity(0.85))
            .frame(width: size, height: size)
            .background(tile.surface.controlFill, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A round glyph button on a dark disc: window controls, shelf remove.
struct SurfaceDiscButton: View {
    let symbol: String
    let label: LocalizedStringKey
    var diameter: CGFloat = 20
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: diameter * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: diameter, height: diameter)
                .background(Color.black.opacity(0.45), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(TilePressStyle())
        .accessibilityLabel(label)
    }
}
