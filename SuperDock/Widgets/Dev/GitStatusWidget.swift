import AppKit
import SwiftUI

struct GitStatusWidget: SuperWidget {
    struct Settings: Codable, Equatable { var repository = "" }
    static let id = "dev.gitStatus"
    static var name: String { String(localized: "Git Status") }
    static let category = WidgetCategory.dev
    static let symbol = "arrow.triangle.branch"
    static let supportedSizes: [TileSize] = [.medium, .wide]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        GitStatusTile(repository: settings.repository, wantsLineCounts: size != .medium)
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(HStack {
            let repository = settings.wrappedValue.repository
            Text(repository.isEmpty ? "No repository" : (repository as NSString).lastPathComponent)
            Button("Choose Folder…") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                if panel.runModal() == .OK, let url = panel.url { settings.wrappedValue.repository = url.path }
            }
        })
    }
}

/// One poll's worth of `git status`, `git log -1` and (at W) `git diff --shortstat`.
struct GitSnapshot: Equatable {
    var repo: String
    var status: DevParsing.GitStatus
    var commit: DevParsing.Commit?
    var insertions: Int?
    var deletions: Int?
}

enum GitPhase: Equatable {
    case chooseRepo
    case notARepo(folder: String)
    case loading
    case ready(GitSnapshot)
}

/// Polls git for the chosen folder and hands plain values to `GitStatusView`.
private struct GitStatusTile: View {
    let repository: String
    let wantsLineCounts: Bool
    @State private var phase = GitPhase.loading
    @State private var now = Date()
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        GitStatusView(phase: repository.isEmpty ? .chooseRepo : phase, now: now, onChooseRepo: openWidgetSettings)
            .task(id: repository) {
                guard !repository.isEmpty else { return }
                phase = .loading
                while !Task.isCancelled {
                    phase = await poll()
                    now = Date()
                    do {
                        try await Task.sleep(for: .seconds(30))
                    } catch {
                        return
                    }
                }
            }
    }

    private func poll() async -> GitPhase {
        let folder = (repository as NSString).lastPathComponent
        guard let output = await runCommand("/usr/bin/git", ["-C", repository, "status", "--porcelain=v1", "-b"]),
              let status = DevParsing.gitStatus(fromPorcelain: output) else { return .notARepo(folder: folder) }
        var snapshot = GitSnapshot(repo: folder, status: status)
        if let log = await runCommand("/usr/bin/git", ["-C", repository, "log", "-1", "--format=\(DevParsing.commitFormat)"]) {
            snapshot.commit = DevParsing.lastCommit(fromLog: log)
        }
        // The diff walks every changed file, so only the size that shows line counts pays for it.
        if wantsLineCounts, let stat = await runCommand("/usr/bin/git", ["-C", repository, "diff", "--shortstat", "HEAD"]) {
            let lines = DevParsing.lineChanges(fromShortstat: stat)
            (snapshot.insertions, snapshot.deletions) = (lines.insertions, lines.deletions)
        }
        return .ready(snapshot)
    }

    private func openWidgetSettings() {
        UserDefaults.standard.set(SettingsTab.widgets.rawValue, forKey: SettingsTab.storageKey)
        NSApp.activate()   // agent apps are never frontmost, so Settings would open behind other apps
        openSettings()
    }
}

/// Terminal-chic: all mono. Branch on top, working-tree state in the middle, last commit at the bottom.
struct GitStatusView: View {
    @Environment(\.tile) private var tile
    var phase: GitPhase
    var now: Date
    var onChooseRepo: () -> Void = {}

    var body: some View {
        switch phase {
        case .chooseRepo:
            TileStateView(state: .needsSetup(verb: "Choose repo", title: "Choose a repo", detail: "Pick a folder to watch"),
                          action: onChooseRepo)
        case let .notARepo(folder):
            TileStateView(state: .needsSetup(verb: "Choose repo", title: "Not a git repo", detail: folder), action: onChooseRepo)
        case .loading:
            TileStateView(state: .loading)
        case let .ready(snapshot):
            ready(snapshot)
        }
    }

    private func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size * tile.scale, weight: weight, design: .monospaced)
    }

    private var isWide: Bool { tile.size != .medium && !tile.isPortrait }

    private func ready(_ snapshot: GitSnapshot) -> some View {
        let status = snapshot.status
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5 * tile.scale) {
                Image(systemName: "arrow.triangle.branch").font(.system(size: 11 * tile.scale, weight: .semibold))
                    .foregroundStyle(tile.surface.good)
                Text(status.branch).font(mono(12.5, .semibold)).foregroundStyle(tile.surface.primary)
                    .lineLimit(1).truncationMode(.middle)
                if !tile.isPortrait {
                    Spacer(minLength: 4)
                    Text(snapshot.repo).font(mono(10.5)).foregroundStyle(tile.surface.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if tile.isPortrait {
                VStack(alignment: .leading, spacing: 2 * tile.scale) { changes(snapshot) }
            } else {
                HStack(spacing: 7 * tile.scale) { changes(snapshot) }
            }
            Spacer(minLength: 0)
            footer(snapshot).font(mono(10.5, .regular)).foregroundStyle(tile.surface.secondary).lineLimit(1)
        }
        .padding(.horizontal, 2 * tile.scale)
        .padding(.vertical, 1 * tile.scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(snapshot))
    }

    /// Dirty is a dot plus the word "changed"; clean is a check plus "clean", so colour is never the only cue.
    @ViewBuilder private func changes(_ snapshot: GitSnapshot) -> some View {
        let status = snapshot.status
        let dirty = tile.surface.isDark ? Palette.hot : tile.surface.warning
        if status.changed == 0 {
            HStack(spacing: 4 * tile.scale) { Image(systemName: "checkmark"); Text("clean") }
                .font(mono(12)).foregroundStyle(tile.surface.good)
        } else if isWide, let insertions = snapshot.insertions, let deletions = snapshot.deletions {
            Text("+\(insertions)").font(mono(12)).foregroundStyle(tile.surface.good)
            Text("-\(deletions)").font(mono(12)).foregroundStyle(tile.surface.danger)
            Text("\(status.changed) \(status.changed == 1 ? "file" : "files")").font(mono(12)).foregroundStyle(dirty)
        } else {
            HStack(spacing: 5 * tile.scale) {
                Circle().fill(dirty).frame(width: 6 * tile.scale, height: 6 * tile.scale)
                Text(tile.isPortrait ? "\(status.changed)" : "\(status.changed) changed").font(mono(12)).foregroundStyle(dirty)
            }
            if tile.isPortrait { Text("changed").font(mono(10.5)).foregroundStyle(dirty) }
        }
        if isWide { Spacer(minLength: 4) }
        if status.ahead > 0 || status.behind > 0 || isWide {
            let sync = (isWide ? ["↑\(status.ahead)", "↓\(status.behind)"]
                               : [status.ahead > 0 ? "↑\(status.ahead)" : nil, status.behind > 0 ? "↓\(status.behind)" : nil]
                                .compactMap(\.self))
            Text(sync.joined(separator: " ")).font(mono(12))
                .foregroundStyle(tile.surface.isDark ? Palette.progress : Color(rgb: 0x1D6AD8)).lineLimit(1).fixedSize()
        }
    }

    @ViewBuilder private func footer(_ snapshot: GitSnapshot) -> some View {
        if let commit = snapshot.commit {
            if isWide {
                Text("\(commit.hash) \(commit.subject)")
            } else {
                Text("\(GitStatusView.age(from: commit.date, to: now)) \(tile.isPortrait ? "ago" : "since commit")")
            }
        } else {
            Text("no commits yet")
        }
    }

    private func accessibilityText(_ snapshot: GitSnapshot) -> String {
        let status = snapshot.status
        var parts = ["\(snapshot.repo), branch \(status.branch)",
                     status.changed == 0 ? "clean" : "\(status.changed) changed"]
        if status.ahead > 0 { parts.append("\(status.ahead) ahead") }
        if status.behind > 0 { parts.append("\(status.behind) behind") }
        return parts.joined(separator: ", ")
    }

    /// "12m", "3h", "2d": a terminal prompt's terse age.
    static func age(from date: Date, to now: Date) -> String {
        let minutes = max(Int(now.timeIntervalSince(date) / 60), 0)
        if minutes < 60 { return "\(minutes)m" }
        return minutes < 60 * 24 ? "\(minutes / 60)h" : "\(minutes / (60 * 24))d"
    }
}
