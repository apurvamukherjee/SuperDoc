import Foundation
import Testing

private let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "Fixtures")
private let rollout = fixtures.appending(path: "codex-rollout.jsonl")

struct CodexParsingTests {
    @Test func limitsFromNewestTokenCount() throws {
        let windows = try #require(try CodexData.limits(in: rollout))
        #expect(windows.map(\.label) == ["5h", "Week"])
        #expect(windows.map(\.usedPercent) == [42, 7.5])
        #expect(windows[0].resetsAt == Date(timeIntervalSince1970: 1_795_100_000))
    }

    @Test func lastEventSkipsMessageLines() throws {
        // The newest line is a response_item (tool call text); it must be skipped, not parsed.
        #expect(try CodexData.lastEventType(in: rollout) == "exec_approval_request")
    }

    @Test func promptTextThatLooksLikeAnEventIsIgnored() {
        let fake = Data(#"{"timestamp":"t","type":"response_item","payload":{"type":"message","content":"\"type\":\"event_msg\""}}"#.utf8)
        #expect(CodexData.eventType(ofLine: fake) == nil)
    }

    @Test func projectFromSessionMeta() throws {
        #expect(try CodexData.cwd(of: rollout) == "/Users/test/code/Demo")
    }

    @Test func windowLabels() {
        #expect(CodexData.label(forMinutes: 300) == "5h")
        #expect(CodexData.label(forMinutes: 10080) == "Week")
        #expect(CodexData.label(forMinutes: 43200) == "30d")   // free plan, seen on the dev machine
    }

    @Test func tailDropsPartialFirstLine() throws {
        let lines = try JSONLines.tail(of: rollout, maxBytes: 300)
        #expect(lines.allSatisfy { $0.first == UInt8(ascii: "{") })
    }
}

struct ClaudeParsingTests {
    @Test func limitsFromBridgeFile() throws {
        let windows = try ClaudeData.limits(from: Data(contentsOf: fixtures.appending(path: "claude-limits.json")))
        #expect(windows.map(\.label) == ["5h", "Week"])
        #expect(windows.map(\.usedPercent) == [42.5, 7])
    }

    @Test func windowPastResetShowsZero() {
        let window = LimitWindow(label: "5h", usedPercent: 80, resetsAt: Date(timeIntervalSince1970: 100))
        #expect(window.usedPercent(at: Date(timeIntervalSince1970: 99)) == 80)
        #expect(window.usedPercent(at: Date(timeIntervalSince1970: 101)) == 0)
    }
}

struct StatusRuleTests {
    private let now = Date(timeIntervalSince1970: 10_000)

    @Test(arguments: [
        ("busy", 0.0, AgentStatus.working),
        ("shell", 0, .working),
        ("waiting", 0, .needsInput),
        ("idle", 60, .done),
        ("idle", 11 * 60, .idle),
        ("something-new", 0, .idle)
    ])
    func claude(status: String, secondsAgo: Double, expected: AgentStatus) {
        #expect(AgentStatusRules.claude(status: status, changedAt: now.addingTimeInterval(-secondsAgo), now: now) == expected)
    }

    @Test(arguments: [
        ("exec_approval_request", 600.0, AgentStatus.needsInput),
        ("task_complete", 60, .done),
        ("task_complete", 11 * 60, .idle),
        ("turn_aborted", 60, .done),
        ("exec_command_begin", 30, .working),
        ("exec_command_begin", 5 * 60, .idle)
    ])
    func codex(event: String, secondsAgo: Double, expected: AgentStatus) {
        #expect(AgentStatusRules.codex(lastEvent: event, modifiedAt: now.addingTimeInterval(-secondsAgo), now: now) == expected)
    }
}

struct ClaudeBridgeTests {
    private let folder = FileManager.default.temporaryDirectory.appending(path: "superdock-bridge-\(UUID().uuidString)")
    private var bridge: ClaudeStatusLineBridge {
        ClaudeStatusLineBridge(claudeSettings: folder.appending(path: "settings.json"), supportFolder: folder.appending(path: "support"))
    }

    private func settings() throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: bridge.claudeSettings)) as? [String: Any])
    }

    @Test func connectThenDisconnectRestoresOriginal() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let original = #"{"model":"opus","statusLine":{"type":"command","command":"ccstatusline","padding":0,"refreshInterval":10}}"#
        try Data(original.utf8).write(to: bridge.claudeSettings)

        try bridge.connect()
        #expect(bridge.isConnected)
        let connected = try #require(try settings()["statusLine"] as? [String: Any])
        #expect(connected["refreshInterval"] as? Int == 10)   // other statusLine keys kept
        let script = try String(contentsOf: bridge.script, encoding: .utf8)
        #expect(script.contains("| ccstatusline"))

        try bridge.disconnect()
        #expect(!bridge.isConnected)
        #expect(try settings()["model"] as? String == "opus")
        #expect((try settings()["statusLine"] as? [String: Any])?["command"] as? String == "ccstatusline")
        #expect(!FileManager.default.fileExists(atPath: bridge.script.path))
    }

    @Test func scriptSavesOnlyRateLimitsAndPassesPayloadThrough() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(#"{"statusLine":{"type":"command","command":"wc -c"}}"#.utf8).write(to: bridge.claudeSettings)
        try bridge.connect()

        let payload = #"{"cwd":"/secret/path","rate_limits":{"five_hour":{"used_percentage":12,"resets_at":1}}}"#
        let process = Process()
        process.executableURL = bridge.script
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        try process.run()
        input.fileHandleForWriting.write(Data(payload.utf8))
        try input.fileHandleForWriting.close()
        process.waitUntilExit()

        let passedThrough = String(bytes: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        #expect(passedThrough.trimmingCharacters(in: .whitespaces).hasPrefix("\(payload.utf8.count)"))
        let saved = try String(contentsOf: bridge.limitsFile, encoding: .utf8)
        #expect(saved.contains("five_hour") && !saved.contains("secret"))
    }

    @Test func noOriginalStatusLineIsRemovedOnDisconnect() throws {
        try bridge.connect()   // settings.json doesn't exist yet
        try bridge.disconnect()
        #expect(try settings()["statusLine"] == nil)
    }
}
