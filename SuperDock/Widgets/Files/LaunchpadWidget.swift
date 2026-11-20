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
        Button { Launchpad.shared.toggle() } label: {
            Image(systemName: "square.grid.3x3.fill").font(.title2).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .help("Launchpad (⌃⌥⌘L)")
        .accessibilityLabel("Open Launchpad")
    }
}
