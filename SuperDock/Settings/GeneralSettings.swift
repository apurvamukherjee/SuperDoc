import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "general")

/// Settings → General: launch at login, updates, and moving settings to another Mac.
struct GeneralSettings: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Toggle("Open SuperDock at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                LabeledContent("Updates") {
                    if Updates.isConfigured {
                        Button("Check Now") { Updates.shared.checkForUpdates() }
                    } else {
                        Text("Available in release builds").foregroundStyle(.secondary)
                    }
                }
            }
            Section("Move to another Mac") {
                HStack {
                    Button("Export Settings…", action: exportSettings)
                    Button("Import Settings…", action: importSettings)
                }
                Text("Includes the bar layout, profiles and preferences. Clipboard history and AI data are never exported.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            message = nil
        } catch {
            message = String(localized: "Couldn't change the login item: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "SuperDock Settings.plist"
        panel.allowedContentTypes = [.propertyList]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try SettingsTransfer.export(to: url)
            message = String(localized: "Settings exported.")
        } catch {
            message = String(localized: "Couldn't export: \(error.localizedDescription)")
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.propertyList]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try SettingsTransfer.import(from: url)
            SettingsTransfer.relaunch()
        } catch {
            message = String(localized: "Couldn't import: \(error.localizedDescription)")
        }
    }
}

/// One plist with SuperDock's preferences and layout file.
enum SettingsTransfer {
    enum TransferError: Error { case notASuperDockExport }

    private static let layoutFile = URL.applicationSupportDirectory.appending(path: "SuperDock/layout.json")
    /// Window frames, Sparkle bookkeeping and first-run state belong to this Mac, not the user's setup.
    private static let skippedPrefixes = ["NS", "SU", "onboarding.", "settings.tab"]

    static func export(to url: URL) throws {
        let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
        let preferences = domain.filter { key, _ in !skippedPrefixes.contains { key.hasPrefix($0) } }
        var bundle: [String: Any] = ["format": "superdock-settings-1", "preferences": preferences]
        if let layout = FileManager.default.contents(atPath: layoutFile.path) { bundle["layout"] = layout }
        try PropertyListSerialization.data(fromPropertyList: bundle, format: .xml, options: 0).write(to: url, options: .atomic)
    }

    static func `import`(from url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let bundle = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              bundle["format"] as? String == "superdock-settings-1" else { throw TransferError.notASuperDockExport }
        for (key, value) in bundle["preferences"] as? [String: Any] ?? [:] {
            UserDefaults.standard.set(value, forKey: key)
        }
        if let layout = bundle["layout"] as? Data {
            try FileManager.default.createDirectory(at: layoutFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try layout.write(to: layoutFile, options: .atomic)
        }
    }

    /// Stores and services read their files at launch, so the simplest correct way to apply an import is a restart.
    /// The new copy starts only after this one has exited, so its quit-time Dock restore can't undo the new launch.
    @MainActor static func relaunch() {
        let script = "while kill -0 \(getpid()) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\""
        do {
            try Process.run(URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script, Bundle.main.bundlePath])
        } catch {
            log.error("Couldn't relaunch: \(error)")
        }
        NSApp.terminate(nil)
    }
}
