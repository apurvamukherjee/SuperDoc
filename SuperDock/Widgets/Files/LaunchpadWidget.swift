import SwiftUI

/// The Launchpad tile. The full-screen Launchpad itself lives in Launchpad/Launchpad.swift.
struct LaunchpadWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "files.launchpad"
    static var name: String { String(localized: "Launchpad") }
    static let category = WidgetCategory.files
    static let symbol = "square.grid.3x3"
    static let supportedSizes: [TileSize] = [.compact]

    static func view(size: TileSize, settings: Settings) -> some View {
        Button { Launchpad.shared.toggle() } label: { LaunchpadFace() }
            .buttonStyle(.plain)
            .help("Launchpad (⌃⌥⌘L)")
            .accessibilityLabel("Open Launchpad")
    }
}

/// 8 · Glyph: a 3 × 3 grid of app-coloured squircles.
struct LaunchpadFace: View {
    @Environment(\.tile) private var tile

    private static let colors: [Color] = [
        Palette.coral, Palette.hot, Palette.note,
        Palette.good, Palette.water, Palette.working,
        Color(rgb: 0x9D6BFF), Color(rgb: 0xE85BD0), Color(rgb: 0xC7C7CC)
    ]

    var body: some View {
        let side = 11.5 * tile.scale
        Grid(horizontalSpacing: 3 * tile.scale, verticalSpacing: 3 * tile.scale) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { column in
                        RoundedRectangle(cornerRadius: side * 0.28, style: .continuous)
                            .fill(Self.colors[row * 3 + column].gradient)
                            .frame(width: side, height: side)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}
