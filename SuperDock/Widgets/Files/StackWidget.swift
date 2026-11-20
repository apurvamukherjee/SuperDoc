import AppKit
import QuickLookThumbnailing
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
        StackTile(settings: settings)
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(StackSettings(settings: settings))
    }
}

/// 8 · Glyph, with the glyph being a fan of the newest files. C: the fan. M: fan, name, count, age of the newest.
struct StackFace: View {
    @Environment(\.tile) private var tile
    var title: String
    /// Newest first; at most three are drawn. Empty draws a blank card while previews load.
    var thumbnails: [FileThumbnail]
    var count: Int
    /// "Newest 2m ago".
    var newest: String?

    var body: some View {
        if tile.isCompact {
            StackFan(thumbnails: thumbnails).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if tile.isPortrait {
            VStack(spacing: tile.rowSpacing) {
                StackFan(thumbnails: thumbnails).frame(height: tile.contentSize.width)
                Text(title).tileStyle(.title).minimumScaleFactor(0.8)
                Text(countText).tileStyle(.detail)
                Spacer(minLength: 0)
            }
        } else {
            HStack(spacing: 8 * tile.scale) {
                StackFan(thumbnails: thumbnails).frame(width: tile.unit * 0.62)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).tileStyle(.title)
                    Text(countText).tileStyle(.detail)
                    if let newest, tile.showsDetail { Text(newest).tileStyle(.detail) }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var countText: String {
        count == 1 ? String(localized: "1 item") : String(localized: "\(count) items")
    }
}

/// Up to three file previews fanned like a hand of cards, newest on top.
struct StackFan: View {
    @Environment(\.tile) private var tile
    var thumbnails: [FileThumbnail]

    /// Rotation and offset per card, front to back, in points at the design unit.
    private static let poses: [(angle: Double, offset: CGSize)] = [
        (-3, CGSize(width: -1, height: -1)), (-11, CGSize(width: -5, height: 3)), (9, CGSize(width: 5, height: 3))
    ]

    var body: some View {
        let height = tile.unit * 0.52
        let width = height * 0.84
        // Keyed by position so a new newest file slides the fan along instead of re-dealing it.
        ZStack {
            ForEach((0..<min(max(thumbnails.count, 1), 3)).reversed(), id: \.self) { index in
                let pose = Self.poses[index]
                card(index < thumbnails.count ? thumbnails[index].image : nil, width: width, height: height)
                    .rotationEffect(.degrees(pose.angle))
                    .offset(x: pose.offset.width * tile.scale, y: pose.offset.height * tile.scale)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .tileAnimation(Motion.settle, value: thumbnails.map(\.id))
        .accessibilityHidden(true)
    }

    private func card(_ image: Image?, width: CGFloat, height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4 * tile.scale, style: .continuous)
        return ZStack {
            shape.fill(tile.surface.skeleton)
            if let image { image.resizable().scaledToFill() }
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(tile.surface.isDark ? 0.18 : 0.7), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.28), radius: 2.5 * tile.scale, y: 1)
    }
}

/// What the tile knows about its source without opening it.
struct StackSnapshot: Sendable {
    var newest: [URL]
    var total: Int
    var newestDate: Date?
}

/// Loads a snapshot whenever the folder changes and the previews for its newest files.
private struct StackTile: View {
    let settings: StackWidget.Settings
    @State private var isOpen = false
    @State private var items: [URL] = []
    @State private var snapshot: StackSnapshot?
    @State private var thumbnails: [FileThumbnail] = []
    @State private var isDenied = false

    private var source: StackWidget.Source { settings.source }

    var body: some View {
        Group {
            if isDenied {
                TileStateView(state: .needsPermission(detail: String(localized: "Open Settings →")), action: openPrivacySettings)
            } else {
                Button {
                    items = StackContents.load(source)
                    isOpen = true
                } label: {
                    face
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(source.title)")
            }
        }
        .task(id: source) {
            for await _ in StackContents.changes(of: source) { await refresh() }
        }
        .popover(isPresented: $isOpen, arrowEdge: .top) {
            StackPopover(title: source.title, items: items, style: settings.style, folder: StackContents.folder(source))
        }
    }

    @ViewBuilder private var face: some View {
        if let snapshot {
            if snapshot.total == 0 {
                TileStateView(state: .empty(title: source.title, detail: String(localized: "Nothing here yet")))
            } else if let newestDate = snapshot.newestDate {
                TimelineView(.everyMinute) { context in
                    StackFace(title: source.title, thumbnails: thumbnails, count: snapshot.total,
                              newest: String(localized: "Newest \(ShortAge.text(since: newestDate, now: context.date))"))
                }
            } else {
                StackFace(title: source.title, thumbnails: thumbnails, count: snapshot.total)
            }
        } else {
            TileStateView(state: .loading)
        }
    }

    private func refresh() async {
        let source = source
        do {
            let next = try await Task.detached(priority: .utility) { try StackContents.snapshot(source) }.value
            isDenied = false
            if next.newest != snapshot?.newest {
                thumbnails = await FileThumbnails.images(for: next.newest)
            }
            snapshot = next
        } catch CocoaError.fileReadNoPermission {
            isDenied = true
        } catch {
            log.error("Can't read \(source.title): \(error)")
            snapshot = StackSnapshot(newest: [], total: 0)
        }
    }

    private func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") else { return }
        NSWorkspace.shared.open(url)
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

struct FileThumbnail: Identifiable {
    var id: URL
    var image: Image
}

/// Quick Look previews for the stack fan and the shelf. Quick Look falls back to the file's icon by itself.
enum FileThumbnails {
    @MainActor static func images(for urls: [URL]) async -> [FileThumbnail] {
        var thumbnails: [FileThumbnail] = []
        for url in urls {
            let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 96, height: 96), scale: 2,
                                                       representationTypes: .all)
            do {
                let cgImage = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).cgImage
                thumbnails.append(FileThumbnail(id: url, image: Image(decorative: cgImage, scale: 2)))
            } catch {
                log.error("No preview for \(url.lastPathComponent): \(error)")
                thumbnails.append(FileThumbnail(id: url, image: Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))))
            }
        }
        return thumbnails
    }
}

/// Reads stack contents, newest first: a small snapshot for the tile, the full list when the stack is opened.
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

    static func load(_ source: StackWidget.Source) -> [URL] {
        do {
            return Array(try dated(source).prefix(limit).map(\.url))
        } catch {
            log.error("Can't list \(source.title): \(error)")
            return []
        }
    }

    /// Throws `CocoaError.fileReadNoPermission` when macOS hasn't granted access to the folder (Downloads, Desktop).
    static func snapshot(_ source: StackWidget.Source) throws -> StackSnapshot {
        let all = try dated(source)
        return StackSnapshot(newest: all.prefix(3).map(\.url), total: all.count, newestDate: all.first?.date)
    }

    /// Yields now, then whenever an entry in the folder is added, removed or renamed. Recent Files has no folder to
    /// watch, so it yields once; it refreshes when the stack is opened.
    static func changes(of source: StackWidget.Source) -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            continuation.yield()
            guard source != .recent, let folder = folder(source) else { return continuation.finish() }
            let descriptor = open(folder.path, O_EVTONLY)
            guard descriptor >= 0 else {
                log.error("Can't watch \(folder.path): errno \(errno)")
                return continuation.finish()
            }
            let watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete],
                                                                    queue: .global(qos: .utility))
            watcher.setEventHandler { continuation.yield() }
            watcher.setCancelHandler { close(descriptor) }
            continuation.onTermination = { _ in watcher.cancel() }
            watcher.resume()
        }
    }

    private static func dated(_ source: StackWidget.Source) throws -> [(url: URL, date: Date)] {
        switch source {
        case .recent: recentFiles()
        // Spotlight is asked per file, so only the newest few are checked.
        case .screenshots: try newest(in: screenshotsFolder).prefix(limit).filter { isScreenCapture($0.url) }
        case .downloads, .folder: try folder(source).map(newest(in:)) ?? []
        }
    }

    /// Where macOS saves screenshots: the user's choice in the Screenshot app, else the Desktop.
    private static var screenshotsFolder: URL {
        let custom = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        return custom.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop")
    }

    private static func newest(in folder: URL) throws -> [(url: URL, date: Date)] {
        let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .contentModificationDateKey]
        let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                               options: [.skipsHiddenFiles])
        return urls.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))   // missing dates just sort last
            return (url, values?.addedToDirectoryDate ?? values?.contentModificationDate ?? .distantPast)
        }
        .sorted { $0.date > $1.date }
    }

    /// Spotlight tags screenshots and screen recordings, which is locale-proof unlike matching "Screenshot" in names.
    private static func isScreenCapture(_ url: URL) -> Bool {
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return false }
        return (MDItemCopyAttribute(item, "kMDItemIsScreenCapture" as CFString) as? Bool) == true
    }

    /// Files used in the last week, via a synchronous Spotlight query.
    private static func recentFiles() -> [(url: URL, date: Date)] {
        let since = Date().addingTimeInterval(-7 * 86_400)
        let format = "kMDItemLastUsedDate >= $time.iso(\(ISO8601DateFormatter().string(from: since)))"
            + " && kMDItemContentTypeTree != \"public.folder\""
        guard let query = MDQueryCreate(nil, format as CFString, nil,
                                        [kMDItemLastUsedDate as String] as CFArray) else { return [] }
        MDQuerySetSearchScope(query, [kMDQueryScopeHome] as CFArray, 0)
        guard MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue)) else { return [] }
        let count = MDQueryGetResultCount(query)
        let items: [(url: URL, date: Date)] = (0..<count).compactMap { index in
            guard let raw = MDQueryGetResultAtIndex(query, index) else { return nil }
            let item = Unmanaged<MDItem>.fromOpaque(raw).takeUnretainedValue()
            guard let path = MDItemCopyAttribute(item, kMDItemPath) as? String,
                  let used = MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date,
                  !path.contains("/Library/") else { return nil }   // skip app support files
            return (URL(fileURLWithPath: path), used)
        }
        return Array(items.sorted { $0.date > $1.date }.prefix(limit))
    }
}
