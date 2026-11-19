import Foundation
import Observation
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "ai-usage")

/// Claude and Codex limit windows, refreshed every few seconds while a limits tile is on screen.
@MainActor @Observable
final class AIUsageService {
    static let shared = AIUsageService()

    struct Usage: Equatable {
        var windows: [LimitWindow]
        var capturedAt: Date
    }

    private(set) var usage: [AIProvider: Usage] = [:]

    private static let interval: TimeInterval = 5
    private static let codexRoot = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/sessions")

    @ObservationIgnored private var subscribers = 0
    @ObservationIgnored private var timer: Timer?

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
        usage[.claude] = readClaude()
        usage[.codex] = readCodex()
    }

    private func readClaude() -> Usage? {
        let file = ClaudeStatusLineBridge.standard.limitsFile
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        do {
            let modified = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date()
            return Usage(windows: try ClaudeData.limits(from: Data(contentsOf: file)), capturedAt: modified)
        } catch {
            log.error("Claude limits unreadable: \(error)")
            return nil
        }
    }

    private func readCodex() -> Usage? {
        // Newest session with a token_count event; limits are account-wide, so any session will do.
        for rollout in CodexData.recentRollouts(root: Self.codexRoot, days: 31) {
            do {
                if let windows = try CodexData.limits(in: rollout.url) {
                    return Usage(windows: windows, capturedAt: rollout.modified)
                }
            } catch {
                log.error("Codex rollout unreadable: \(error)")
            }
        }
        return nil
    }
}
