import Foundation
import Testing

/// In-memory stand-in for the system Dock's preferences.
private final class FakeDockPrefs: DockPrefsStore, @unchecked Sendable {   // tests run it on one thread
    var values: [String: Any] = [:]
    var restarts = 0
    func value(_ key: String) -> Any? { values[key] }
    func set(_ key: String, _ value: Any?) { values[key] = value }
    func restartDock() { restarts += 1 }
}

struct DockReplacementTests {
    private let prefs = FakeDockPrefs()
    private var replacement: DockReplacement {
        DockReplacement(prefs: prefs, flagFile: FileManager.default.temporaryDirectory
            .appending(path: "superdock-dock-\(ObjectIdentifier(prefs).hashValue)/dock-replaced.json"))
    }

    @Test func applyHidesThenRestoreReturnsUserValues() {
        prefs.values = ["autohide": false, "autohide-delay": 0.2]
        replacement.apply()
        #expect(prefs.values["autohide"] as? Bool == true)
        #expect(prefs.values["autohide-delay"] as? Double == 1000)
        #expect(replacement.isApplied)

        replacement.restore()
        #expect(prefs.values["autohide"] as? Bool == false)
        #expect(prefs.values["autohide-delay"] as? Double == 0.2)
        #expect(!replacement.isApplied)
        #expect(prefs.restarts == 2)
    }

    @Test func unsetKeysAreRemovedAgainNotSetToDefaults() {
        replacement.apply()
        replacement.restore()
        #expect(prefs.values["autohide"] == nil)
        #expect(prefs.values["autohide-delay"] == nil)
    }

    @Test func applyingTwiceKeepsTheOriginalValues() {
        prefs.values = ["autohide": false]
        replacement.apply()
        replacement.apply()   // e.g. relaunch after a crash with the mode still on
        replacement.restore()
        #expect(prefs.values["autohide"] as? Bool == false)
    }

    @Test func launchAfterCrashWithModeOffRestores() {
        prefs.values = ["autohide": false]
        replacement.apply()                  // …then SuperDock crashed
        replacement.reconcile(enabled: false)
        #expect(prefs.values["autohide"] as? Bool == false)
        #expect(!replacement.isApplied)
    }

    @Test func pinnedAppsComeFromPersistentApps() {
        prefs.values["persistent-apps"] = [
            ["tile-data": ["file-data": ["_CFURLString": "file:///System/Applications/Mail.app/"]]],
            ["tile-data": ["no-file": true]],
            ["tile-data": ["file-data": ["_CFURLString": "file:///Applications/Safari.app/"]]]
        ]
        #expect(replacement.nativePinnedApps().map(\.lastPathComponent) == ["Mail.app", "Safari.app"])
    }
}
