import AppKit
import Observation
import SwiftUI
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "plugins")

/// Built-in JSON plugins (bundled with the app) and user-installed ones from
/// `~/Library/Application Support/SuperDock/Plugins/`.
@MainActor @Observable
final class PluginStore {
    static let shared = PluginStore()

    struct Plugin: Identifiable, Equatable {
        var id: String { manifest.id }
        var manifest: PluginManifest
        var file: URL
        var isBuiltIn: Bool
    }

    struct GalleryEntry: Codable, Identifiable, Equatable {
        var id: String
        var name: String
        var description: String
        var author: String
        var file: String     // path relative to the gallery index
    }

    /// The community gallery lives in the SuperDock repo; plugins are plain JSON, so installing one never runs code.
    static let galleryIndex = URL(string: "https://raw.githubusercontent.com/apurvamukherjee/SuperDoc/main/gallery/index.json")!
    static let folder = URL.applicationSupportDirectory.appending(path: "SuperDock/Plugins")

    private(set) var plugins: [Plugin] = []
    /// Plugin files that couldn't be loaded, with the reason, shown in Settings.
    private(set) var problems: [String] = []

    private init() {
        reload()
    }

    var descriptors: [WidgetDescriptor] { plugins.map(Self.descriptor) }

    func reload() {
        var found: [Plugin] = []
        var problems: [String] = []
        let bundled = (Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("plugin-") }
        let installed: [URL]
        do {
            installed = FileManager.default.fileExists(atPath: Self.folder.path)
                ? try FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "json" }
                : []
        } catch {
            log.error("Can't list plugins: \(error)")
            installed = []
        }
        for (file, isBuiltIn) in bundled.map({ ($0, true) }) + installed.map({ ($0, false) }) {
            do {
                let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(contentsOf: file))
                try manifest.validate()
                guard !found.contains(where: { $0.id == manifest.id }) else { continue }   // built-ins win
                found.append(Plugin(manifest: manifest, file: file, isBuiltIn: isBuiltIn))
            } catch {
                problems.append("\(file.lastPathComponent): \(error)")
            }
        }
        plugins = found.sorted { $0.manifest.name < $1.manifest.name }
        self.problems = problems
    }

    /// Copies a plugin JSON file into the plugins folder after checking it.
    func install(_ data: Data) throws {
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: data)
        try manifest.validate()
        try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        let name = manifest.id.replacingOccurrences(of: "/", with: "_") + ".json"
        try data.write(to: Self.folder.appending(path: name), options: .atomic)
        reload()
    }

    func remove(_ plugin: Plugin) throws {
        guard !plugin.isBuiltIn else { return }
        // A user's own file: to the Trash, not deleted (hard rule 8).
        try FileManager.default.trashItem(at: plugin.file, resultingItemURL: nil)
        reload()
    }

    func gallery() async throws -> [GalleryEntry] {
        let (data, _) = try await URLSession.shared.data(from: Self.galleryIndex)
        return try JSONDecoder().decode([GalleryEntry].self, from: data)
    }

    func install(_ entry: GalleryEntry) async throws {
        let url = Self.galleryIndex.deletingLastPathComponent().appending(path: entry.file)
        let (data, _) = try await URLSession.shared.data(from: url)
        try install(data)
    }

    private static func descriptor(_ plugin: Plugin) -> WidgetDescriptor {
        let manifest = plugin.manifest
        return WidgetDescriptor(
            id: manifest.id, name: manifest.name,
            category: manifest.category.flatMap(WidgetCategory.init) ?? .community,
            symbol: manifest.symbol ?? "puzzlepiece.extension",
            supportedSizes: manifest.sizes ?? [.compact, .medium],
            usesNetwork: true,
            makeTile: { size, settings in AnyView(PluginTile(manifest: manifest, size: size, settings: PluginSettings.decode(settings))) },
            makeSettings: { binding in
                guard let fields = manifest.settings, !fields.isEmpty else { return nil }
                return AnyView(PluginSettingsView(fields: fields, settings: binding))
            }
        )
    }
}

/// Plugin settings are a flat string dictionary stored in the tile.
enum PluginSettings {
    static func decode(_ data: Data?) -> [String: String] {
        guard let data else { return [:] }
        do {
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            log.error("Plugin settings unreadable, using defaults: \(error)")
            return [:]
        }
    }

    static func encode(_ values: [String: String]) -> Data? {
        do {
            return try JSONEncoder().encode(values)
        } catch {
            log.fault("Plugin settings failed to encode: \(error)")
            return nil
        }
    }
}

/// Shared fetch cache, so tiles re-appearing (the bar hides with the Dock) don't refetch before `every` has passed.
@MainActor @Observable
final class PluginFetcher {
    static let shared = PluginFetcher()

    private(set) var results: [String: Any] = [:]
    private(set) var failed: Set<String> = []
    @ObservationIgnored private var fetchedAt: [String: Date] = [:]

    /// Runs for as long as the tile's `.task` lives.
    func keepFresh(_ url: URL, headers: [String: String], every seconds: Int) async {
        let key = url.absoluteString
        while !Task.isCancelled {
            if Date().timeIntervalSince(fetchedAt[key] ?? .distantPast) >= Double(seconds) {
                await fetch(url, headers: headers, key: key)
            }
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return   // tile went away
            }
        }
    }

    private func fetch(_ url: URL, headers: [String: String], key: String) async {
        var request = URLRequest(url: url)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            results[key] = try JSONSerialization.jsonObject(with: data)
            fetchedAt[key] = Date()
            failed.remove(key)
        } catch {
            log.error("Plugin fetch failed for \(url.host() ?? "?"): \(error)")
            failed.insert(key)
        }
    }
}

private struct PluginTile: View {
    let manifest: PluginManifest
    let size: TileSize
    let settings: [String: String]
    private let fetcher = PluginFetcher.shared

    var body: some View {
        let values = manifest.values(from: settings)
        let tile = manifest.tile
        if let url = URL(string: PluginTemplate.fill(manifest.source.url, with: values, encode: true)) {
            let key = url.absoluteString
            content(json: fetcher.results[key], failed: fetcher.failed.contains(key), values: values, tile: tile)
                .contentShape(Rectangle())
                .onTapGesture { open(tile.open, values: values) }
                .task(id: key) { await fetcher.keepFresh(url, headers: manifest.source.headers ?? [:], every: manifest.interval) }
        } else {
            Image(systemName: "exclamationmark.triangle").accessibilityLabel("Plugin URL is invalid")
        }
    }

    @ViewBuilder
    private func content(json: Any?, failed: Bool, values: [String: String], tile: PluginManifest.Tile) -> some View {
        if let json {
            let path = { (template: String?) in template.map { PluginTemplate.fill($0, with: values) } }
            let main = path(tile.value).flatMap { JSONPath.value($0, in: json) }
            let shown = (tile.prefix ?? "") + PluginTemplate.format(main, as: tile.format, currency: tile.currency) + (tile.suffix ?? "")
            switch tile.template {
            case .value:
                LegacyStatTile(label: LocalizedStringKey(PluginTemplate.fill(tile.label ?? manifest.name, with: values)), value: shown,
                         detail: path(tile.subtitle).flatMap { JSONPath.value($0, in: json) }.map { "\($0)" })
            case .text:
                Text(shown).font(size == .compact ? .caption2 : .caption).lineLimit(4).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            case .gauge:
                Gauge(value: min(max((main as? NSNumber)?.doubleValue ?? 0, 0), tile.max ?? 100), in: 0...(tile.max ?? 100)) {
                    Text(verbatim: PluginTemplate.fill(tile.label ?? manifest.name, with: values))
                } currentValueLabel: { Text(shown) }
                .gaugeStyle(.accessoryCircular)
            case .list:
                list(titles: path(tile.items).map { JSONPath.values($0, in: json) } ?? [],
                     links: path(tile.links).map { JSONPath.values($0, in: json) } ?? [])
            }
        } else if failed {
            Image(systemName: "exclamationmark.icloud").font(.title3).accessibilityLabel("\(manifest.name) unavailable")
        } else {
            ProgressView().controlSize(.small)
        }
    }

    private func list(titles: [Any], links: [Any]) -> some View {
        let rows = size.columns >= 3 ? 3 : 2
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(titles.prefix(rows).enumerated()), id: \.offset) { index, title in
                Text(verbatim: "\(title)").font(.caption2).lineLimit(1)
                    .onTapGesture { open(links.indices.contains(index) ? "\(links[index])" : nil, values: [:]) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Only web links, so a plugin can't open apps or files.
    private func open(_ template: String?, values: [String: String]) {
        guard let template, let url = URL(string: PluginTemplate.fill(template, with: values, encode: true)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct PluginSettingsView: View {
    let fields: [PluginManifest.Field]
    @Binding var settings: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(fields, id: \.key) { field in
                TextField(field.label, text: Binding(
                    get: { PluginSettings.decode(settings)[field.key] ?? "" },
                    set: { value in
                        var values = PluginSettings.decode(settings)
                        values[field.key] = value
                        settings = PluginSettings.encode(values)
                    }
                ), prompt: Text(field.default ?? ""))
            }
        }
    }
}
