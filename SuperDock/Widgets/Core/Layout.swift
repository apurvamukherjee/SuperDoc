import Foundation
import Observation

/// Tiles share the bar's height; size sets how many columns wide they are.
enum TileSize: String, Codable, CaseIterable, Identifiable {
    case compact, medium, wide, large

    var id: Self { self }

    var columns: Int {
        switch self {
        case .compact: 1
        case .medium: 2
        case .wide: 3
        case .large: 4
        }
    }

    var title: String {
        switch self {
        case .compact: String(localized: "Compact")
        case .medium: String(localized: "Medium")
        case .wide: String(localized: "Wide")
        case .large: String(localized: "Large")
        }
    }
}

/// One widget instance on the bar.
struct Tile: Codable, Identifiable, Equatable {
    var id = UUID()
    var widgetId: String
    var size: TileSize
    /// The widget's own Settings type, JSON-encoded. nil means the widget's defaults.
    var settings: Data?

    private enum CodingKeys: String, CodingKey {
        case id = "instanceId", widgetId, size, settings
    }
}

// ponytail: one layout for now; Phase 7 keys this by profile and display.
/// The bar's tiles, saved as JSON whenever they change.
@MainActor @Observable
final class LayoutStore {
    static let shared = LayoutStore(
        fileURL: URL.applicationSupportDirectory.appending(path: "SuperDock/layout.json")
    )

    static let starterTiles = [
        Tile(widgetId: "time.clock", size: .compact),
        Tile(widgetId: "time.date", size: .compact),
        Tile(widgetId: "system.cpu", size: .compact),
        Tile(widgetId: "system.battery", size: .compact)
    ]

    var tiles: [Tile] {
        didSet {
            save()
            onChange?()
        }
    }

    /// For AppKit owners (BarController) that can't observe through SwiftUI.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let fileURL: URL

    var totalColumns: Int { tiles.reduce(0) { $0 + $1.size.columns } }

    init(fileURL: URL) {
        self.fileURL = fileURL
        tiles = JSONFile.load([Tile].self, from: fileURL) ?? Self.starterTiles
    }

    func add(_ widgetId: String, size: TileSize) {
        tiles.append(Tile(widgetId: widgetId, size: size))
    }

    func remove(_ id: Tile.ID) {
        tiles.removeAll { $0.id == id }
    }

    func setSize(_ size: TileSize, for id: Tile.ID) {
        guard let index = tiles.firstIndex(where: { $0.id == id }) else { return }
        tiles[index].size = size
    }

    /// Moves `id` into the slot currently held by `target` (used by drag-to-reorder on the bar).
    func move(_ id: Tile.ID, to target: Tile.ID) {
        guard id != target,
              let from = tiles.firstIndex(where: { $0.id == id }),
              let targetIndex = tiles.firstIndex(where: { $0.id == target }) else { return }
        // Edit a copy so didSet saves once, not once per step.
        var reordered = tiles
        reordered.insert(reordered.remove(at: from), at: targetIndex)
        tiles = reordered
    }

    private func save() {
        JSONFile.save(tiles, to: fileURL)
    }
}
