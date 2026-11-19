import Foundation
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "dock-replacement")

/// Reads and writes the system Dock's preferences. The app uses `SystemDockPrefs`; tests use an in-memory copy.
protocol DockPrefsStore: Sendable {
    func value(_ key: String) -> Any?
    /// nil removes the key, restoring the system default.
    func set(_ key: String, _ value: Any?)
    func restartDock()
}

struct SystemDockPrefs: DockPrefsStore {
    private var domain: CFString { "com.apple.dock" as CFString }

    func value(_ key: String) -> Any? {
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(key as CFString, domain)
    }

    func set(_ key: String, _ value: Any?) {
        CFPreferencesSetAppValue(key as CFString, value as CFPropertyList?, domain)
        CFPreferencesAppSynchronize(domain)
    }

    func restartDock() {
        do {
            try Process.run(URL(fileURLWithPath: "/usr/bin/killall"), arguments: ["Dock"])
        } catch {
            log.error("Couldn't restart the Dock: \(error)")
        }
    }
}

/// Optional mode that hides the system Dock so SuperDock's own app strip takes its place (SUPERDOCK.md §5.4).
///
/// Hard rule 9: the original settings are written to a flag file *before* anything changes, and put back when the
/// user turns the mode off, when SuperDock quits, and on the next launch after a crash.
struct DockReplacement: Sendable {
    static let enabledKey = "dock.replacement"
    static let standard = DockReplacement(
        prefs: SystemDockPrefs(),
        flagFile: URL.applicationSupportDirectory.appending(path: "SuperDock/dock-replaced.json")
    )

    /// The user's own values; nil means the key wasn't set (system default).
    struct Saved: Codable, Equatable {
        var autohide: Bool?
        var autohideDelay: Double?
    }

    var prefs: DockPrefsStore
    var flagFile: URL

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// True while the system Dock is hidden by us (the flag file exists).
    var isApplied: Bool { FileManager.default.fileExists(atPath: flagFile.path) }

    /// Hides the Dock: auto-hide on, with a delay so long it never appears.
    func apply() {
        guard !isApplied else { return }
        let saved = Saved(autohide: prefs.value("autohide") as? Bool, autohideDelay: prefs.value("autohide-delay") as? Double)
        JSONFile.save(saved, to: flagFile)
        guard isApplied else { return log.error("Couldn't write the restore file; leaving the Dock alone") }
        prefs.set("autohide", true)
        prefs.set("autohide-delay", 1000.0)
        prefs.restartDock()
    }

    /// Puts the user's own Dock settings back.
    func restore() {
        guard isApplied, let saved = JSONFile.load(Saved.self, from: flagFile) else { return }
        prefs.set("autohide", saved.autohide)
        prefs.set("autohide-delay", saved.autohideDelay)
        prefs.restartDock()
        do {
            try FileManager.default.removeItem(at: flagFile)
        } catch {
            log.error("Couldn't remove the restore file: \(error)")
        }
    }

    /// At launch: makes the system match the setting. A leftover flag with the mode off means we crashed or
    /// were force-quit while the Dock was hidden, so the user's settings are restored.
    func reconcile(enabled: Bool) {
        if enabled { apply() } else { restore() }
    }

    /// App bundles pinned in the system Dock, in order, to seed SuperDock's own strip.
    func nativePinnedApps() -> [URL] {
        let tiles = prefs.value("persistent-apps") as? [[String: Any]] ?? []
        return tiles.compactMap { tile in
            let fileData = (tile["tile-data"] as? [String: Any])?["file-data"] as? [String: Any]
            return (fileData?["_CFURLString"] as? String).flatMap(URL.init(string:))
        }
    }
}
