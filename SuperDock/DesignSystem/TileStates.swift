import SwiftUI

/// The five states every widget shares. One look everywhere; a tap fixes the state.
enum TileState: Equatable {
    /// Skeleton in the archetype's slots. No spinner.
    case loading
    /// Calm, never an error: sleeping Limo. "All quiet" / "No agents running".
    case empty(title: String, detail: String)
    /// No data at all. With a last value, show it with `.tileStale(_:)` instead.
    case offline(detail: String)
    /// Amber key; the tap opens the right System Settings pane.
    case needsPermission(detail: String)
    /// Outlined tile, verb first: "Connect" / "Connect Claude" / "Takes 5 seconds".
    case needsSetup(verb: String, title: String, detail: String)
}

struct TileStateView: View {
    @Environment(\.tile) private var tile
    var state: TileState
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) { content }.buttonStyle(TilePressStyle())
            } else {
                content
            }
        }
        .tileOutline(isSetup ? .setup : .none)
    }

    private var isSetup: Bool {
        if case .needsSetup = state { return true }
        return false
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            TileSkeleton()
        case let .empty(title, detail):
            layout(caption: nil, title: title, detail: detail) { LimoFace(snoring: tile.isCompact) }
        case let .offline(detail):
            layout(caption: "Offline", title: "Offline", detail: detail) {
                TileSymbol(name: "exclamationmark.icloud", color: tile.surface.secondary)
            }
        case let .needsPermission(detail):
            layout(caption: "Allow", title: "Needs access", detail: detail, color: tile.surface.warning) {
                TileSymbol(name: "key", color: tile.surface.warning)
            }
        case let .needsSetup(verb, title, detail):
            // Connecting an account is Limo's "curious" moment (mockup 04); other verbs (choose, set) keep the link.
            if verb == String(localized: "Connect") {
                layout(caption: verb, title: title, detail: detail, faceGlyph: true) {
                    LimoFace(snoring: false, pose: .curious)
                }
            } else {
                layout(caption: verb, title: title, detail: detail) { TileSymbol(name: "link", color: tile.surface.primary) }
            }
        }
    }

    /// Compact: glyph over a caption. Wider: glyph beside title + detail. `color` tints the caption and the detail.
    /// `faceGlyph` sizes a Limo face up, since its features read smaller than an SF Symbol in the same box.
    private func layout(caption: String?, title: String, detail: String, color: Color? = nil, faceGlyph: Bool = false,
                        @ViewBuilder glyph: () -> some View) -> some View {
        Group {
            if tile.isCompact {
                VStack(spacing: 5 * tile.scale) {
                    let side = (faceGlyph && caption != nil ? 26 : 20) * tile.scale
                    glyph().frame(width: side, height: side)
                    if let caption { Text(caption).tileStyle(.caption, color: color ?? tile.surface.secondary) }
                }
                .scaleEffect(caption == nil ? 1.6 : 1)
            } else {
                HStack(spacing: 8 * tile.scale) {
                    let side = (caption == nil || faceGlyph ? 32 : 20) * tile.scale
                    glyph().frame(width: side, height: side)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).tileStyle(.title)
                        Text(detail).tileStyle(.detail, color: color)
                    }
                    .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 3 * tile.scale)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(detail)")
    }
}

/// Grey blocks where the label, hero and detail will land.
private struct TileSkeleton: View {
    @Environment(\.tile) private var tile

    var body: some View {
        let fill = tile.surface.skeleton
        let width = tile.contentSize.width
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(fill).frame(width: min(width * 0.4, 40 * tile.scale), height: 7 * tile.scale)
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 4 * tile.scale).fill(fill)
                .frame(width: tile.isCompact ? width * 0.75 : width * 0.55, height: 18 * tile.scale)
            Spacer(minLength: 0)
            Capsule().fill(fill).frame(width: tile.isCompact ? width * 0.55 : width, height: (tile.isCompact ? 7 : 4) * tile.scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityLabel("Loading")
    }
}

extension View {
    /// Error/offline with a last value: keep showing it, dimmed, with an offline badge on the tile corner and its age.
    func tileStale(_ age: String?) -> some View {
        modifier(StaleModifier(age: age))
    }
}

private struct StaleModifier: ViewModifier {
    let age: String?

    func body(content: Content) -> some View {
        if let age {
            // The badge is drawn by `TileChrome`, outside the content's clip and dimming.
            content.opacity(0.5)
                .transformPreference(TileAppearanceKey.self) { $0.isStale = true }
                .accessibilityValue("Offline, showing data from \(age)")
        } else {
            content
        }
    }
}
