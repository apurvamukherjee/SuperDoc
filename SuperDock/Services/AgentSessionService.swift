import Foundation
import Observation
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "agents")

/// Live coding-agent sessions across all projects, for the agents board and Limo alerts.
@MainActor @Observable
final class AgentSessionService {
    static let shared = AgentSessionService()

    struct Session: Identifiable, Equatable {
        var id: String
        var tool: AIProvider
        var project: String
        var status: AgentStatus
    }

    private(set) var sessions: [Session] = []

    /// Fires when a session moves from working to done or needs-input (Limo listens).
    @ObservationIgnored var onAlert: ((Session) -> Void)?

    // ponytail: 1 s poll of a few tiny files while subscribed; FSEvents if the board ever needs to be instant.
    private static let interval: TimeInterval = 1
    private static let codexVisibleFor: TimeInterval = 30 * 60
    private static let claudeSessions = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/sessions")
    private static let codexRoot = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/sessions")

    @ObservationIgnored private var subscribers = 0
    @ObservationIgnored private var timer: Timer?
    private struct CodexEntry {
        var modified: Date
        var cwd: String?
        var lastEvent: String?
    }
    @ObservationIgnored private var codexCache: [URL: CodexEntry] = [:]

    func subscribe() {
        subscribers += 1
        guard subscribers == 1 else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func unsubscribe() {
        subscribers -= 1
        guard subscribers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        let now = Date()
        let next = (claudeSessions(now: now) + codexSessions(now: now))
            .sorted { ($0.status.sortOrder, $0.project) < ($1.status.sortOrder, $1.project) }
        let previous = Dictionary(sessions.map { ($0.id, $0.status) }, uniquingKeysWith: { first, _ in first })
        for session in next where previous[session.id] == .working && [.done, .needsInput].contains(session.status) {
            onAlert?(session)
        }
        if next != sessions { sessions = next }
    }

    private func claudeSessions(now: Date) -> [Session] {
        let files: [URL]
        do {
            guard FileManager.default.fileExists(atPath: Self.claudeSessions.path) else { return [] }
            files = try FileManager.default.contentsOfDirectory(at: Self.claudeSessions, includingPropertiesForKeys: nil)
        } catch {
            log.error("Can't list Claude sessions: \(error)")
            return []
        }
        return files.filter { $0.pathExtension == "json" }.compactMap { file in
            do {
                let session = try JSONDecoder().decode(ClaudeData.Session.self, from: Data(contentsOf: file))
                // Files outlive crashed processes; signal 0 only checks the pid exists.
                guard kill(session.pid, 0) == 0 || errno == EPERM else { return nil }
                let changed = Date(timeIntervalSince1970: (session.statusUpdatedAt ?? session.updatedAt) / 1000)
                return Session(id: "claude-\(session.sessionId)", tool: .claude,
                               project: URL(fileURLWithPath: session.cwd).lastPathComponent,
                               status: AgentStatusRules.claude(status: session.status, changedAt: changed, now: now))
            } catch {
                // Claude rewrites these files constantly; a half-written read is normal and fixed on the next tick.
                log.debug("Skipping \(file.lastPathComponent): \(error)")
                return nil
            }
        }
    }

    private func codexSessions(now: Date) -> [Session] {
        let recent = CodexData.recentRollouts(root: Self.codexRoot, days: 2)
            .filter { now.timeIntervalSince($0.modified) < Self.codexVisibleFor }
        codexCache = codexCache.filter { cached in recent.contains { $0.url == cached.key } }
        return recent.map { rollout in
            if codexCache[rollout.url]?.modified != rollout.modified {
                do {
                    let cwd = try codexCache[rollout.url]?.cwd ?? CodexData.cwd(of: rollout.url)
                    let lastEvent = try CodexData.lastEventType(in: rollout.url)
                    codexCache[rollout.url] = CodexEntry(modified: rollout.modified, cwd: cwd, lastEvent: lastEvent)
                } catch {
                    log.error("Codex rollout unreadable: \(error)")
                }
            }
            let cached = codexCache[rollout.url]
            return Session(id: "codex-\(rollout.url.lastPathComponent)", tool: .codex,
                           project: cached?.cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Codex",
                           status: AgentStatusRules.codex(lastEvent: cached?.lastEvent, modifiedAt: rollout.modified, now: now))
        }
    }
}

extension AgentStatus {
    /// Board order: what needs you first.
    var sortOrder: Int {
        switch self {
        case .needsInput: 0
        case .working: 1
        case .done: 2
        case .idle: 3
        }
    }
}
