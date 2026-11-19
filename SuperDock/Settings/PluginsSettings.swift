import SwiftUI

/// Settings → Plugins: installed JSON plugins and the community gallery.
struct PluginsSettings: View {
    private let store = PluginStore.shared
    @State private var gallery: [PluginStore.GalleryEntry]?
    @State private var message: String?

    var body: some View {
        Form {
            Section("Installed") {
                ForEach(store.plugins) { plugin in
                    HStack {
                        Label(plugin.manifest.name, systemImage: plugin.manifest.symbol ?? "puzzlepiece.extension")
                        if plugin.isBuiltIn { Text("Built-in").font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        if !plugin.isBuiltIn {
                            Button("Remove") { run { try store.remove(plugin) } }.controlSize(.small)
                        }
                    }
                    .help(plugin.manifest.description ?? plugin.manifest.source.url)
                }
                ForEach(store.problems, id: \.self) { Text($0).font(.caption).foregroundStyle(.red) }
                HStack {
                    Button("Install from File…") { installFromFile() }
                    Button("Open Plugins Folder") {
                        run {
                            try FileManager.default.createDirectory(at: PluginStore.folder, withIntermediateDirectories: true)
                            NSWorkspace.shared.open(PluginStore.folder)
                        }
                    }
                    Button("Reload") { store.reload() }
                }
            }
            Section("Community gallery") {
                if let gallery {
                    ForEach(gallery) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.name)
                                Text("\(entry.description) · by \(entry.author)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.plugins.contains(where: { $0.id == entry.id }) {
                                Text("Installed").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Button("Install") { Task { await install(entry) } }.controlSize(.small)
                            }
                        }
                    }
                } else {
                    Button("Browse Gallery") { Task { await loadGallery() } }
                }
                if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
            }
            Section {
                Text("""
                    Plugins are JSON files that describe a URL to fetch and which values to show (docs/plugins.md). \
                    They can't run code, read your files or open anything except web links.
                    """)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
            message = nil
        } catch {
            message = String(localized: "Couldn't do that: \(error.localizedDescription)")
        }
    }

    private func installFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        run { try store.install(Data(contentsOf: url)) }
    }

    private func loadGallery() async {
        do {
            gallery = try await store.gallery()
            message = nil
        } catch {
            message = String(localized: "Couldn't load the gallery. Check your connection.")
        }
    }

    private func install(_ entry: PluginStore.GalleryEntry) async {
        do {
            try await store.install(entry)
            message = String(localized: "Installed \(entry.name). Add it from the Widgets tab.")
        } catch {
            message = String(localized: "Couldn't install \(entry.name): \(error.localizedDescription)")
        }
    }
}
