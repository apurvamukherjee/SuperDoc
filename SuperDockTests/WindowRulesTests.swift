import CoreGraphics
import Foundation
import Testing

private func row(id: CGWindowID, pid: pid_t, title: String = "", layer: Int = 0, size: CGSize = CGSize(width: 800, height: 600),
                 onScreen: Bool = true, alpha: Double = 1) -> [String: Any] {
    [kCGWindowNumber as String: id, kCGWindowOwnerPID as String: pid, kCGWindowName as String: title,
     kCGWindowLayer as String: layer, kCGWindowAlpha as String: alpha, kCGWindowIsOnscreen as String: onScreen,
     kCGWindowBounds as String: CGRect(origin: .zero, size: size).dictionaryRepresentation]
}

struct WindowFilterTests {
    private let names: [pid_t: String] = [10: "Safari", 20: "Notes"]

    @Test func keepsRealWindowsDropsHelpers() {
        let rows = [
            row(id: 1, pid: 10, title: "Apple"),                       // titled
            row(id: 2, pid: 10),                                       // untitled helper, unknown to AX
            row(id: 3, pid: 20),                                       // untitled but AX knows it
            row(id: 4, pid: 10, title: "Menu", layer: 25),             // not a normal window layer
            row(id: 5, pid: 10, title: "Tiny", size: CGSize(width: 20, height: 20)),
            row(id: 6, pid: 99, title: "Background app"),              // not a regular app
            row(id: 7, pid: 10, title: "Invisible", alpha: 0),
            row(id: 8, pid: 42, title: "SuperDock itself")
        ]
        let windows = WindowRules.windows(from: rows, appNames: names.merging([42: "SuperDock"]) { $1 },
                                          axTitles: [3: "Shopping List"], ownPID: 42)
        #expect(windows.map(\.id) == [1, 3])
        #expect(windows.map(\.title) == ["Apple", "Shopping List"])
    }

    @Test func untitledAXWindowFallsBackToAppName() {
        let windows = WindowRules.windows(from: [row(id: 3, pid: 20)], appNames: names, axTitles: [3: ""], ownPID: 0)
        #expect(windows.first?.title == "Notes")
    }
}

struct SwitcherOrderTests {
    private func window(_ id: CGWindowID, pid: pid_t, onScreen: Bool) -> WindowInfo {
        WindowInfo(id: id, pid: pid, appName: "", title: "", bounds: .zero, isOnScreen: onScreen)
    }

    @Test func onScreenFirstThenOtherSpacesByAppRecency() {
        let windows = [
            window(1, pid: 10, onScreen: true), window(2, pid: 20, onScreen: false),
            window(3, pid: 30, onScreen: false), window(4, pid: 20, onScreen: true), window(5, pid: 99, onScreen: false)
        ]
        let ordered = WindowRules.ordered(windows, appMRU: [30, 20, 10])
        #expect(ordered.map(\.id) == [1, 4, 3, 2, 5])
    }

    @Test func stepWrapsBothWays() {
        #expect(WindowRules.step(0, by: 1, count: 3) == 1)
        #expect(WindowRules.step(2, by: 1, count: 3) == 0)
        #expect(WindowRules.step(0, by: -1, count: 3) == 2)
        #expect(WindowRules.step(0, by: 1, count: 0) == 0)
    }
}

struct FreezeCounterTests {
    @Test func frozenAfterTwoMissesInARowAndRecovers() {
        var counter = FreezeCounter()
        #expect(counter.record([1: false, 2: true]).isEmpty)
        #expect(counter.record([1: false, 2: true]) == [1])
        #expect(counter.frozen == [1])
        #expect(counter.record([1: false]).isEmpty)      // reported once, not every tick
        #expect(counter.record([1: true]).isEmpty)
        #expect(counter.frozen.isEmpty)
    }

    @Test func aSingleSlowReplyDoesNotCount() {
        var counter = FreezeCounter()
        _ = counter.record([1: false])
        _ = counter.record([1: true])
        #expect(counter.record([1: false]).isEmpty)
    }
}
