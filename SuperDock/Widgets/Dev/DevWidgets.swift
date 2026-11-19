import AppKit
import SwiftUI

/// Copies text; `concealed` marks it the way password managers do, so clipboard histories (ours included) skip it.
@MainActor
private func copy(_ text: String, concealed: Bool = false) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    if concealed { pasteboard.setData(Data(), forType: .init("org.nspasteboard.ConcealedType")) }
}

struct UUIDWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "dev.uuid"
    static var name: String { String(localized: "UUID") }
    static let category = WidgetCategory.dev
    static let symbol = "number.square"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        GenerateTile(label: "UUID", symbol: "number.square") { UUID().uuidString.lowercased() }
    }
}

struct PasswordWidget: SuperWidget {
    struct Settings: Codable, Equatable { var length = 20 }
    static let id = "dev.password"
    static var name: String { String(localized: "Password Generator") }
    static let category = WidgetCategory.dev
    static let symbol = "key"
    static let supportedSizes: [TileSize] = [.compact, .medium]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        GenerateTile(label: "Password", symbol: "key", concealed: true) { DevParsing.password(length: settings.length) }
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(Stepper("Length: \(settings.wrappedValue.length)", value: settings.length, in: 8...64))
    }
}

/// Tap to generate and copy; shows "Copied" briefly.
private struct GenerateTile: View {
    let label: LocalizedStringKey
    let symbol: String
    var concealed = false
    let generate: () -> String
    @State private var copiedAt: Date?

    var body: some View {
        Button {
            copy(generate(), concealed: concealed)
            copiedAt = Date()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: copiedAt == nil ? symbol : "checkmark").font(.title3)
                Text(copiedAt == nil ? label : "Copied").font(.caption2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Generate and copy \(Text(label))"))
        .task(id: copiedAt) {
            guard copiedAt != nil else { return }
            do {
                try await Task.sleep(for: .seconds(1.5))
            } catch {
                return   // tile went away
            }
            copiedAt = nil
        }
    }
}

struct PortsWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "dev.ports"
    static var name: String { String(localized: "Local Ports") }
    static let category = WidgetCategory.dev
    static let symbol = "point.3.connected.trianglepath.dotted"
    static let supportedSizes: [TileSize] = [.medium, .wide]

    static func view(size: TileSize, settings: Settings) -> some View {
        PortsTile(size: size)
    }
}

private struct PortsTile: View {
    let size: TileSize
    @State private var ports: [DevParsing.ListeningPort] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if ports.isEmpty {
                Text("No listening ports").font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(ports.prefix(size == .wide ? 4 : 3), id: \.self) { port in
                Button { NSWorkspace.shared.open(URL(string: "http://localhost:\(port.port)")!) } label: {
                    Text(":\(String(port.port))  \(port.process)").font(.caption2.monospacedDigit()).lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("Open http://localhost:\(String(port.port))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            while !Task.isCancelled {
                if let output = await runCommand("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN"]) {
                    ports = DevParsing.listeningPorts(fromLsof: output)
                }
                do {
                    try await Task.sleep(for: .seconds(10))
                } catch {
                    return
                }
            }
        }
    }
}

struct GitStatusWidget: SuperWidget {
    struct Settings: Codable, Equatable { var repository = "" }
    static let id = "dev.gitStatus"
    static var name: String { String(localized: "Git Status") }
    static let category = WidgetCategory.dev
    static let symbol = "arrow.triangle.branch"
    static let supportedSizes: [TileSize] = [.medium, .wide]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        GitStatusTile(repository: settings.repository)
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

private struct GitStatusTile: View {
    let repository: String
    @State private var status: DevParsing.GitStatus?
    @State private var failed = false

    var body: some View {
        Group {
            if repository.isEmpty {
                Text("Choose a repository in Widget Settings").font(.caption2).foregroundStyle(.secondary)
            } else if let status {
                VStack(alignment: .leading, spacing: 2) {
                    Label(status.branch, systemImage: "arrow.triangle.branch").font(.caption.weight(.semibold))
                    Text(summary(status)).font(.caption2).foregroundStyle(status.changed > 0 ? .orange : .secondary)
                }
                .tileText()
            } else if failed {
                Text("Not a git repository").font(.caption2).foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: repository) {
            guard !repository.isEmpty else { return }
            while !Task.isCancelled {
                let output = await runCommand("/usr/bin/git", ["-C", repository, "status", "--porcelain=v1", "-b"])
                status = output.flatMap(DevParsing.gitStatus(fromPorcelain:))
                failed = status == nil
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    return
                }
            }
        }
    }

    private func summary(_ status: DevParsing.GitStatus) -> String {
        var parts = [status.changed == 0 ? String(localized: "Clean") : String(localized: "\(status.changed) changed")]
        if status.ahead > 0 { parts.append("↑\(status.ahead)") }
        if status.behind > 0 { parts.append("↓\(status.behind)") }
        return parts.joined(separator: "  ")
    }
}
