import Foundation

/// Opt-in bridge that gets Claude Code's live rate-limit numbers, which are only ever passed to the status line command.
///
/// Connecting points `statusLine.command` in `~/.claude/settings.json` at a small script that saves only
/// `rate_limits` (via `plutil -extract`) and then runs the user's original status line unchanged.
/// Disconnecting puts the original `statusLine` back. See docs/ai-data-sources.md.
struct ClaudeStatusLineBridge {
    enum BridgeError: Error {
        case settingsNotAnObject
        case changedSinceConnect   // someone else edited statusLine after we connected; don't clobber it
    }

    var claudeSettings: URL
    var supportFolder: URL

    static let standard = ClaudeStatusLineBridge(
        claudeSettings: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/settings.json"),
        supportFolder: URL.applicationSupportDirectory.appending(path: "SuperDock")
    )

    var script: URL { supportFolder.appending(path: "claude-statusline.sh") }
    var limitsFile: URL { supportFolder.appending(path: "claude-limits.json") }
    private var originalFile: URL { supportFolder.appending(path: "claude-statusline-original.json") }
    private var backup: URL { claudeSettings.appendingPathExtension("superdock-backup") }

    var isConnected: Bool {
        (try? currentCommand()) == scriptCommand
    }

    private var scriptCommand: String { "'\(script.path)'" }

    func connect() throws {
        var settings = try readSettings()
        let original = settings["statusLine"] as? [String: Any]
        try FileManager.default.createDirectory(at: supportFolder, withIntermediateDirectories: true)
        // Keep the original exactly as it was, so disconnecting restores it byte-for-byte in meaning.
        try JSONSerialization.data(withJSONObject: original ?? [:]).write(to: originalFile, options: .atomic)
        try makeScript(originalCommand: original?["command"] as? String)

        var statusLine = original ?? ["type": "command", "padding": 0]
        statusLine["command"] = scriptCommand
        settings["statusLine"] = statusLine
        try writeSettings(settings)
    }

    func disconnect() throws {
        var settings = try readSettings()
        guard (settings["statusLine"] as? [String: Any])?["command"] as? String == scriptCommand else {
            throw BridgeError.changedSinceConnect
        }
        let original = try JSONSerialization.jsonObject(with: Data(contentsOf: originalFile)) as? [String: Any] ?? [:]
        settings["statusLine"] = original.isEmpty ? nil : original
        try writeSettings(settings)
        for file in [script, limitsFile, originalFile] where FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
    }

    // MARK: - Private

    private func currentCommand() throws -> String? {
        (try readSettings()["statusLine"] as? [String: Any])?["command"] as? String
    }

    private func readSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: claudeSettings.path) else { return [:] }
        guard let object = try JSONSerialization.jsonObject(with: Data(contentsOf: claudeSettings)) as? [String: Any] else {
            throw BridgeError.settingsNotAnObject
        }
        return object
    }

    private func writeSettings(_ settings: [String: Any]) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: claudeSettings.path) {
            if fileManager.fileExists(atPath: backup.path) { try fileManager.removeItem(at: backup) }
            try fileManager.copyItem(at: claudeSettings, to: backup)
        } else {
            try fileManager.createDirectory(at: claudeSettings.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: claudeSettings, options: .atomic)
    }

    private func makeScript(originalCommand: String?) throws {
        let limits = limitsFile.path
        let body = """
        #!/bin/sh
        # Installed by SuperDock (Settings → AI → Claude Code). Disconnecting there restores your previous status line.
        # Saves only Claude Code's rate-limit numbers for SuperDock, then runs your original status line unchanged.
        input=$(cat)
        printf '%s' "$input" | /usr/bin/plutil -extract rate_limits json -o '\(limits).tmp' - 2>/dev/null \\
          && mv '\(limits).tmp' '\(limits)'
        \(originalCommand.map { "printf '%s' \"$input\" | \($0)" } ?? ":")

        """
        try Data(body.utf8).write(to: script, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
    }
}
