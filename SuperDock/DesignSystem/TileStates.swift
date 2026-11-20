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
            layout(caption: "Offline", title: "Offline", detail: detail) { TileSymbol(name: "icloud.slash", color: tile.surface.secondary) }
        case let .needsPermission(detail):
            layout(caption: "Allow", title: "Needs access", detail: detail, color: tile.surface.warning) {
                TileSymbol(name: "key", color: tile.surface.warning)
            }
        case let .needsSetup(verb, title, detail):
            layout(caption: verb, title: title, detail: detail) { TileSymbol(name: "link", color: tile.surface.primary) }
        }
    }

    /// Compact: glyph over a caption. Wider: glyph beside title + detail. `color` tints the caption and the detail.
    private func layout(caption: String?, title: String, detail: String, color: Color? = nil,
                        @ViewBuilder glyph: () -> some View) -> some View {
        Group {
            if tile.isCompact {
                VStack(spacing: 5 * tile.scale) {
                    glyph().frame(width: 20 * tile.scale, height: 20 * tile.scale)
                    if let caption { Text(caption).tileStyle(.caption, color: color ?? tile.surface.secondary) }
                }
                .scaleEffect(caption == nil ? 1.6 : 1)
            } else {
                HStack(spacing: 8 * tile.scale) {
                    let side = (caption == nil ? 32 : 20) * tile.scale
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
    /// Error/offline with a last value: keep showing it, dimmed, with a cloud-slash mark and its age.
    func tileStale(_ age: String?) -> some View {
        modifier(StaleModifier(age: age))
    }
}

private struct StaleModifier: ViewModifier {
    @Environment(\.tile) private var tile
    let age: String?

    func body(content: Content) -> some View {
        if let age {
            content.opacity(0.5)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "icloud.slash").font(.system(size: 9 * tile.scale, weight: .semibold))
                        .foregroundStyle(tile.surface.secondary)
                }
                .accessibilityValue("Offline, showing data from \(age)")
        } else {
            content
        }
    }
}

/// Limo asleep, for empty states: the app icon's ink D-face with closed eyes, a flat mouth and the coral cheek.
/// ponytail: sleeping pose only; the Limo owner adds gaze, moods, arms and feet.
struct LimoFace: View {
    var snoring = true

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let rect = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side * 0.86)
                .offsetBy(dx: 0, dy: side * 0.07)
            let face = UnevenRoundedRectangle(topLeadingRadius: side * 0.2, bottomLeadingRadius: side * 0.2,
                                              bottomTrailingRadius: side * 0.43, topTrailingRadius: side * 0.43,
                                              style: .continuous).path(in: rect)
            context.fill(face, with: .linearGradient(Gradient(colors: [Palette.ink, Palette.inkDeep]),
                                                     startPoint: rect.origin, endPoint: CGPoint(x: rect.minX, y: rect.maxY)))
            context.stroke(face, with: .color(.white.opacity(0.92)), lineWidth: side * 0.045)

            var features = Path()
            for eyeX in [0.3, 0.55] {
                let center = CGPoint(x: rect.minX + side * eyeX, y: rect.minY + rect.height * 0.4)
                features.addArc(center: center, radius: side * 0.085, startAngle: .degrees(20), endAngle: .degrees(160),
                                clockwise: false)
                features.move(to: CGPoint(x: center.x + side * 0.1, y: center.y))
            }
            features.move(to: CGPoint(x: rect.minX + side * 0.36, y: rect.minY + rect.height * 0.66))
            features.addLine(to: CGPoint(x: rect.minX + side * 0.5, y: rect.minY + rect.height * 0.66))
            context.stroke(features, with: .color(Palette.cream), style: StrokeStyle(lineWidth: side * 0.045, lineCap: .round))

            let cheek = CGRect(x: rect.minX + side * 0.72, y: rect.minY + rect.height * 0.6, width: side * 0.09, height: side * 0.09)
            context.fill(Path(ellipseIn: cheek), with: .color(Palette.coral.opacity(0.85)))
        }
        .overlay(alignment: .topTrailing) {
            if snoring { snore }
        }
        .accessibilityHidden(true)
    }

    private var snore: some View {
        Text("z").font(.system(size: 7, weight: .heavy, design: .rounded)).foregroundStyle(.secondary).offset(x: 9, y: -8)
    }
}
