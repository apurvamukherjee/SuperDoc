import Foundation
import Testing

@MainActor
struct LayoutStoreTests {
    private let file = FileManager.default.temporaryDirectory
        .appending(path: "superdock-tests-\(UUID().uuidString)/layout.json")

    @Test func firstLaunchGetsStarterTiles() {
        #expect(LayoutStore(fileURL: file).tiles == LayoutStore.starterTiles)
    }

    @Test func changesPersistAcrossRelaunch() throws {
        let store = LayoutStore(fileURL: file)
        store.add("weather.current", size: .wide)
        store.remove(store.tiles[0].id)
        store.setSize(.medium, for: store.tiles[0].id)
        store.tiles[0].settings = Data(#"{"showSeconds":true}"#.utf8)

        #expect(LayoutStore(fileURL: file).tiles == store.tiles)
    }

    @Test func savedJSONUsesSpecFieldNames() throws {
        LayoutStore(fileURL: file).add("time.clock", size: .compact)
        let json = try String(contentsOf: file, encoding: .utf8)
        #expect(json.contains(#""instanceId""#) && json.contains(#""widgetId""#))
    }

    @Test func moveTakesTheTargetSlot() {
        let store = LayoutStore(fileURL: file)
        let ids = store.tiles.map(\.id)   // clock, date, cpu, battery
        store.move(ids[0], to: ids[2])
        #expect(store.tiles.map(\.id) == [ids[1], ids[2], ids[0], ids[3]])
        store.move(ids[3], to: ids[1])
        #expect(store.tiles.map(\.id) == [ids[3], ids[1], ids[2], ids[0]])
    }

    @Test func corruptFileIsKeptAside() throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: file)

        #expect(LayoutStore(fileURL: file).tiles == LayoutStore.starterTiles)
        let siblings = try FileManager.default.contentsOfDirectory(atPath: file.deletingLastPathComponent().path)
        #expect(siblings.contains { $0.hasPrefix("layout.corrupt-") })
    }
}

@Test func barLengthFitsTiles() {
    #expect(BarPlacement.barLength(columns: 1, thickness: 85) == 85)   // one square tile
    #expect(BarPlacement.barLength(columns: 0, thickness: 85) == 85)   // empty bar keeps room for +
    #expect(BarPlacement.barLength(columns: 4, thickness: 85) == 322)   // 2×6 padding + 4×73 tiles + 3×6 gaps
}

@MainActor
struct ProfileTests {
    private let file = FileManager.default.temporaryDirectory
        .appending(path: "superdock-profiles-\(UUID().uuidString)/layout.json")

    @Test func phase2LayoutMigratesToDefaultProfile() throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let old = [Tile(widgetId: "time.clock", size: .wide)]
        try JSONEncoder().encode(old).write(to: file)
        let store = LayoutStore(fileURL: file)
        #expect(store.profiles.count == 1)
        #expect(store.tiles == old)
    }

    @Test func newProfileCopiesTilesWithFreshIDs() {
        let store = LayoutStore(fileURL: file)
        let original = store.tiles
        store.addProfile(named: "Code")
        #expect(store.activeProfile.name == "Code")
        #expect(store.tiles.map(\.widgetId) == original.map(\.widgetId))
        #expect(Set(store.tiles.map(\.id)).isDisjoint(with: original.map(\.id)))
    }

    @Test func eachDisplayRemembersItsOwnProfile() {
        let store = LayoutStore(fileURL: file)
        let laptop = store.activeProfile
        let monitor = store.addProfile(named: "Monitor")   // active on built-in now
        store.activate(laptop.id)
        store.display = .external
        store.activate(monitor.id)
        store.add("weather.current", size: .wide)

        store.display = .builtIn
        #expect(store.activeProfile.id == laptop.id)
        #expect(!store.tiles.contains { $0.widgetId == "weather.current" })
        store.display = .external
        #expect(store.tiles.contains { $0.widgetId == "weather.current" })

        let reloaded = LayoutStore(fileURL: file)
        reloaded.display = .external
        #expect(reloaded.activeProfile.id == monitor.id)
    }

    @Test func deletingFallsBackAndKeepsTheLastProfile() {
        let store = LayoutStore(fileURL: file)
        let extra = store.addProfile(named: "Study")
        store.deleteProfile(extra.id)
        #expect(store.activeProfile.id == store.profiles[0].id)
        store.deleteProfile(store.profiles[0].id)
        #expect(store.profiles.count == 1)
    }

    @Test func activateNextWraps() {
        let store = LayoutStore(fileURL: file)
        let first = store.activeProfile.id
        store.addProfile(named: "Two")
        store.activateNext()
        #expect(store.activeProfile.id == first)
    }
}
