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

/// A named set of tiles, e.g. "Code", "Design", "Study".
struct Profile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var tiles: [Tile]
}

/// Which kind of display the bar is on. Each kind remembers its own active profile,
/// so the laptop screen and an external monitor can show different bars and switch automatically.
enum DisplayKind: String, Codable, CodingKeyRepresentable {
    case builtIn, external
}

/// What's saved in layout.json. `activeProfile` is an object keyed by display kind (CodingKeyRepresentable),
/// e.g. `{"builtIn": "<profile id>"}`, so the file stays readable and hand-editable.
struct LayoutFile: Codable, Equatable {
    var profiles: [Profile]
    var activeProfile: [DisplayKind: Profile.ID] = [:]
}

/// Profiles and the active profile's tiles, saved as JSON whenever they change.
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

    private(set) var file: LayoutFile {
        didSet {
            JSONFile.save(file, to: fileURL)
            onChange?()
        }
    }

    /// Set by BarController from the screen the Dock is on.
    var display = DisplayKind.builtIn {
        didSet { if display != oldValue { onChange?() } }
    }

    /// For AppKit owners (BarController) that can't observe through SwiftUI.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        // Old format first: JSONFile.load would treat it as unreadable and move it aside.
        if let tiles = Self.phase2Tiles(at: fileURL) {
            file = LayoutFile(profiles: [Profile(name: String(localized: "Default"), tiles: tiles)])
        } else if let saved = JSONFile.load(LayoutFile.self, from: fileURL) {
            file = saved
        } else {
            file = LayoutFile(profiles: [Profile(name: String(localized: "Default"), tiles: Self.starterTiles)])
        }
    }

    var profiles: [Profile] { file.profiles }

    var activeProfile: Profile {
        file.profiles.first { $0.id == file.activeProfile[display] } ?? file.profiles[0]
    }

    /// The active profile's tiles. Reads and writes go to whichever profile is active on the current display.
    var tiles: [Tile] {
        get { activeProfile.tiles }
        set {
            guard let index = file.profiles.firstIndex(where: { $0.id == activeProfile.id }) else { return }
            file.profiles[index].tiles = newValue
        }
    }

    var totalColumns: Int { tiles.reduce(0) { $0 + $1.size.columns } }

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
        // Edit a copy so the file is saved once, not once per step.
        var reordered = tiles
        reordered.insert(reordered.remove(at: from), at: targetIndex)
        tiles = reordered
    }

    // MARK: - Profiles

    /// Makes `id` the active profile on the current display.
    func activate(_ id: Profile.ID) {
        file.activeProfile[display] = id
    }

    /// Next profile on the current display, wrapping around (bound to a hotkey).
    func activateNext() {
        guard let index = file.profiles.firstIndex(where: { $0.id == activeProfile.id }) else { return }
        activate(file.profiles[(index + 1) % file.profiles.count].id)
    }

    /// New profile starting as a copy of the active one, so it's useful straight away.
    @discardableResult
    func addProfile(named name: String) -> Profile {
        let profile = Profile(name: name, tiles: tiles.map { tile in
            var copy = tile
            copy.id = UUID()
            return copy
        })
        file.profiles.append(profile)
        activate(profile.id)
        return profile
    }

    func rename(_ id: Profile.ID, to name: String) {
        guard let index = file.profiles.firstIndex(where: { $0.id == id }) else { return }
        file.profiles[index].name = name
    }

    /// The last profile can't be deleted; displays using a deleted profile fall back to the first one.
    func deleteProfile(_ id: Profile.ID) {
        guard file.profiles.count > 1 else { return }
        var next = file
        next.profiles.removeAll { $0.id == id }
        next.activeProfile = next.activeProfile.filter { $0.value != id }
        file = next
    }

    /// Phase 2–6 saved a bare tile array; it becomes the "Default" profile.
    /// nil (no file, or the current format) is the normal case, so failures here aren't errors.
    private static func phase2Tiles(at url: URL) -> [Tile]? {
        guard let data = FileManager.default.contents(atPath: url.path) else { return nil }
        return try? JSONDecoder().decode([Tile].self, from: data)
    }
}
