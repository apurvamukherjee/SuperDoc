import AppKit
import SwiftUI
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "stacks")

/// Fan-out folders and Smart Stacks: a folder (or Downloads, Screenshots, recent files) that opens into a grid or list.
struct StackWidget: SuperWidget {
    enum Source: Codable, Equatable, Hashable {
        case downloads, screenshots, recent
        case folder(String)

        var title: String {
            switch self {
            case .downloads: String(localized: "Downloads")
            case .screenshots: String(localized: "Screenshots")
            case .recent: String(localized: "Recent Files")
            case .folder(let path): FileManager.default.displayName(atPath: path)
            }
        }
    }

    enum Style: String, Codable, CaseIterable {
        case grid, list
    }

    struct Settings: Codable, Equatable {
        var source = Source.downloads
        var style = Style.grid
    }

    static let id = "files.stack"
    static var name: String { String(localized: "Folder / Smart Stack") }
    static let category = WidgetCategory.files
    static let symbol = "square.stack.3d.up"
    static let supportedSizes: [TileSize] = [.compact, .medium]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        StackTile(size: size, settings: settings)
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(StackSettings(settings: settings))
    }
}

private struct StackTile: View {
    let size: TileSize
    let settings: StackWidget.Settings
    @State private var isOpen = false
    @State private var items: [URL] = []

    var body: some View {
        Button {
            items = StackContents.load(settings.source)
            isOpen = true
        } label: {
            VStack(spacing: 2) {
                Image(nsImage: StackContents.icon(for: settings.source)).resizable().scaledToFit().frame(maxHeight: 34)
                if size == .medium { Text(settings.source.title).font(.caption2).lineLimit(1) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(settings.source.title)")
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            StackPopover(title: settings.source.title, items: items, style: settings.style, folder: StackContents.folder(settings.source))
        }
    }
}

private struct StackSettings: View {
    @Binding var settings: StackWidget.Settings

    var body: some View {
        VStack(alignment: .leading) {
            Picker("Show", selection: Binding(
                get: { settings.source },
                set: { source in
                    if case .folder = source { chooseFolder() } else { settings.source = source }
                }
            )) {
                Text("Downloads").tag(StackWidget.Source.downloads)
                Text("Screenshots").tag(StackWidget.Source.screenshots)
                Text("Recent Files").tag(StackWidget.Source.recent)
                if case .folder(let path) = settings.source {
                    Text(FileManager.default.displayName(atPath: path)).tag(settings.source)
                }
                Text("Choose Folder…").tag(StackWidget.Source.folder(""))
            }
            .fixedSize()
            Picker("Layout", selection: $settings.style) {
                Text("Grid").tag(StackWidget.Style.grid)
                Text("List").tag(StackWidget.Style.list)
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = String(localized: "Choose")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.source = .folder(url.path)
    }
}

/// Reads stack contents on demand (only when opened), newest first.
enum StackContents {
    static let limit = 24

    static func folder(_ source: StackWidget.Source) -> URL? {
        switch source {
        case .downloads: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        case .screenshots: screenshotsFolder
        case .recent: nil
        case .folder(let path): URL(fileURLWithPath: path)
        }
    }

    static func icon(for source: StackWidget.Source) -> NSImage {
        folder(source).map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil) ?? NSImage()
    }

    static func load(_ source: StackWidget.Source) -> [URL] {
        switch source {
        case .recent: recentFiles()
        case .screenshots: newest(in: screenshotsFolder).filter(isScreenCapture)
        case .downloads, .folder: folder(source).map(newest(in:)) ?? []
        }
    }

    /// Where macOS saves screenshots: the user's choice in the Screenshot app, else the Desktop.
    private static var screenshotsFolder: URL {
        let custom = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        return custom.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop")
    }

    private static func newest(in folder: URL) -> [URL] {
        let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .contentModificationDateKey]
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                   options: [.skipsHiddenFiles])
            func date(_ url: URL) -> Date {
                let values = try? url.resourceValues(forKeys: Set(keys))   // missing dates just sort last
                return values?.addedToDirectoryDate ?? values?.contentModificationDate ?? .distantPast
            }
            return Array(urls.sorted { date($0) > date($1) }.prefix(limit))
        } catch {
            log.error("Can't list \(folder.path): \(error)")
            return []
        }
    }

    /// Spotlight tags screenshots and screen recordings, which is locale-proof unlike matching "Screenshot" in names.
    private static func isScreenCapture(_ url: URL) -> Bool {
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return false }
        return (MDItemCopyAttribute(item, "kMDItemIsScreenCapture" as CFString) as? Bool) == true
    }

    /// Files used in the last week, via a synchronous Spotlight query (only runs when the stack is opened).
    private static func recentFiles() -> [URL] {
        let since = Date().addingTimeInterval(-7 * 86_400)
        let format = "kMDItemLastUsedDate >= $time.iso(\(ISO8601DateFormatter().string(from: since)))"
            + " && kMDItemContentTypeTree != \"public.folder\""
        guard let query = MDQueryCreate(nil, format as CFString, nil,
                                        [kMDItemLastUsedDate as String] as CFArray) else { return [] }
        MDQuerySetSearchScope(query, [kMDQueryScopeHome] as CFArray, 0)
        guard MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue)) else { return [] }
        let count = MDQueryGetResultCount(query)
        let items: [(URL, Date)] = (0..<count).compactMap { index in
            guard let raw = MDQueryGetResultAtIndex(query, index) else { return nil }
            let item = Unmanaged<MDItem>.fromOpaque(raw).takeUnretainedValue()
            guard let path = MDItemCopyAttribute(item, kMDItemPath) as? String,
                  let used = MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date,
                  !path.contains("/Library/") else { return nil }   // skip app support files
            return (URL(fileURLWithPath: path), used)
        }
        return Array(items.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0))
    }
}
