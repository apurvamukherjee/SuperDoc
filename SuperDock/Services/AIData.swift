import Foundation
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "ai-data")

// Models, parsers and status rules for AI tools. Foundation-only so the tests can compile it directly.
// Formats are documented in docs/ai-data-sources.md. Hard rule: only metadata is ever decoded.

enum AIProvider: String, Codable, CaseIterable {
    case claude, codex

    var title: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }
}

struct LimitWindow: Equatable, Identifiable {
    var id: String { label }
    var label: String           // "5h", "Week", "30d"
    var usedPercent: Double     // 0–100
    var resetsAt: Date?

    /// Past the reset time the old percentage no longer applies.
    func usedPercent(at now: Date) -> Double {
        if let resetsAt, resetsAt <= now { return 0 }
        return usedPercent
    }
}

enum AgentStatus: String, CaseIterable {
    case working, needsInput, done, idle
}

enum AgentStatusRules {
    /// How long a finished session shows as "done" before fading to "idle".
    static let doneWindow: TimeInterval = 10 * 60
    /// A Codex session with no writes for this long, and no terminal event, is treated as idle (likely quit).
    static let codexStallWindow: TimeInterval = 2 * 60

    static func claude(status: String, changedAt: Date, now: Date) -> AgentStatus {
        switch status {
        case "busy", "shell": .working
        case "waiting": .needsInput
        case "idle": now.timeIntervalSince(changedAt) < doneWindow ? .done : .idle
        default: .idle
        }
    }

    static let codexNeedsInputEvents: Set = [
        "exec_approval_request", "apply_patch_approval_request", "request_permissions",
        "request_user_input", "elicitation_request"
    ]
    static let codexTurnEndEvents: Set = ["task_complete", "turn_aborted"]

    static func codex(lastEvent: String?, modifiedAt: Date, now: Date) -> AgentStatus {
        let age = now.timeIntervalSince(modifiedAt)
        if let lastEvent, codexNeedsInputEvents.contains(lastEvent) { return .needsInput }
        if let lastEvent, codexTurnEndEvents.contains(lastEvent) { return age < doneWindow ? .done : .idle }
        return age < codexStallWindow ? .working : .idle
    }
}

// MARK: - Claude Code

enum ClaudeData {
    /// One `~/.claude/sessions/<pid>.json`. `name`/`nameSource` are deliberately absent: they can hold a prompt-derived title.
    struct Session: Decodable {
        var pid: Int32
        var sessionId: String
        var cwd: String
        var status: String
        var statusUpdatedAt: Double?   // ms since 1970
        var updatedAt: Double          // ms since 1970
    }

    /// Parses the `rate_limits` object the status line bridge saves.
    static func limits(from data: Data) throws -> [LimitWindow] {
        struct Window: Decodable {
            var used_percentage: Double   // swiftlint:disable:this identifier_name
            var resets_at: Double?        // swiftlint:disable:this identifier_name
        }
        let windows = try JSONDecoder().decode([String: Window?].self, from: data)
        // Only the two windows the tiles show; per-model weekly buckets are skipped.
        let labels = [("five_hour", String(localized: "5h")), ("seven_day", String(localized: "Week"))]
        return labels.compactMap { key, label in
            guard let window = windows[key] ?? nil else { return nil }
            return LimitWindow(label: label, usedPercent: window.used_percentage,
                               resetsAt: window.resets_at.map { Date(timeIntervalSince1970: $0) })
        }
    }
}

// MARK: - Codex

enum CodexData {
    /// Lines that may contain prompt or code text (`response_item`, `user_message`, …) are never decoded:
    /// everything below works on the first bytes of a line, which hold only metadata.
    private static let prefixLength = 160

    /// The event name of an `event_msg` line, read straight from its prefix, e.g. "task_complete".
    static func eventType(ofLine line: Data) -> String? {
        let prefix = line.prefix(prefixLength)
        guard prefix.range(of: Data(#""type":"event_msg""#.utf8)) != nil,
              let marker = prefix.range(of: Data(#""payload":{"type":""#.utf8)) else { return nil }
        let rest = prefix[marker.upperBound...]
        guard let end = rest.firstIndex(of: UInt8(ascii: "\"")) else { return nil }
        return String(bytes: rest[..<end], encoding: .utf8)
    }

    /// The most recent event type in the file.
    static func lastEventType(in url: URL) throws -> String? {
        try JSONLines.tail(of: url).lazy.compactMap(eventType(ofLine:)).first
    }

    /// Limit windows from the newest `token_count` event in the file.
    static func limits(in url: URL) throws -> [LimitWindow]? {
        guard let line = try JSONLines.tail(of: url).first(where: { eventType(ofLine: $0) == "token_count" }) else { return nil }
        // swiftlint:disable identifier_name
        struct Event: Decodable {
            struct Payload: Decodable { var rate_limits: RateLimits? }
            struct RateLimits: Decodable { var primary: Window?; var secondary: Window? }
            struct Window: Decodable { var used_percent: Double; var window_minutes: Int?; var resets_at: Double? }
            var payload: Payload
        }
        // swiftlint:enable identifier_name
        guard let limits = try JSONDecoder().decode(Event.self, from: line).payload.rate_limits else { return nil }
        return [limits.primary, limits.secondary].compactMap { $0 }.map {
            LimitWindow(label: label(forMinutes: $0.window_minutes), usedPercent: $0.used_percent,
                        resetsAt: $0.resets_at.map { Date(timeIntervalSince1970: $0) })
        }
    }

    /// Windows are named by length because free and paid plans put different windows in "primary".
    static func label(forMinutes minutes: Int?) -> String {
        switch minutes {
        case 300: String(localized: "5h")
        case 10080: String(localized: "Week")
        case let minutes? where minutes % 1440 == 0: String(localized: "\(minutes / 1440)d")
        case let minutes? where minutes % 60 == 0: String(localized: "\(minutes / 60)h")
        default: String(localized: "Limit")
        }
    }

    /// Project folder from the `session_meta` first line.
    static func cwd(of url: URL) throws -> String? {
        guard let line = try JSONLines.firstLine(of: url),
              line.prefix(prefixLength).range(of: Data(#""type":"session_meta""#.utf8)) != nil else { return nil }
        struct Meta: Decodable {
            struct Payload: Decodable { var cwd: String? }
            var payload: Payload
        }
        return try JSONDecoder().decode(Meta.self, from: line).payload.cwd
    }

    /// Rollout files from the last `days` day-folders (`sessions/YYYY/MM/DD`), newest first.
    static func recentRollouts(root: URL, days: Int, now: Date = Date()) -> [(url: URL, modified: Date)] {
        let calendar = Calendar.current
        let files = (0..<days).flatMap { offset -> [URL] in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return [] }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            let folder = root.appending(path: String(format: "%04d/%02d/%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0))
            // Most day folders don't exist (no Codex use that day); that's not an error.
            guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
            do {
                return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])
            } catch {
                log.error("Can't list \(folder.path): \(error)")
                return []
            }
        }
        return files
            .filter { $0.pathExtension == "jsonl" }
            .compactMap { url in
                // nil only if the file vanished since the listing; skipping it is the right outcome.
                (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate).map { (url, $0) }
            }
            .sorted { $0.modified > $1.modified }
    }
}

// MARK: - JSONL reading

enum JSONLines {
    /// Complete lines from the last `maxBytes` of the file, newest first. Never loads the whole transcript.
    static func tail(of url: URL, maxBytes: UInt64 = 256 * 1024) throws -> [Data] {
        let handle = try FileHandle(forReadingFrom: url)
        defer { close(handle) }
        let size = try handle.seekToEnd()
        let start = size > maxBytes ? size - maxBytes : 0
        try handle.seek(toOffset: start)
        var lines = (try handle.readToEnd() ?? Data()).split(separator: UInt8(ascii: "\n"))
        if start > 0, !lines.isEmpty { lines.removeFirst() }   // cut mid-line by the seek
        return lines.reversed().map { Data($0) }
    }

    static func firstLine(of url: URL, maxBytes: Int = 1 << 20) throws -> Data? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { close(handle) }
        guard let chunk = try handle.read(upToCount: maxBytes) else { return nil }
        return chunk.split(separator: UInt8(ascii: "\n"), maxSplits: 1).first.map { Data($0) }
    }

    private static func close(_ handle: FileHandle) {
        do {
            try handle.close()
        } catch {
            // Read-only handle: a failed close loses no data, so log and move on.
            log.error("close failed: \(error)")
        }
    }
}
