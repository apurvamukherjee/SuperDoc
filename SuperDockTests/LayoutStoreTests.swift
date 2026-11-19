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
