import AppKit
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "apps")

struct AppEntry: Identifiable, Hashable {
    var id: URL { url }
    var url: URL
    var name: String
    var bundleID: String?
}

/// Installed apps, found by scanning the standard application folders (what Launchpad shows).
enum AppCatalog {
    private static var folders: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities"]
            .map(URL.init(fileURLWithPath:)) + [home.appending(path: "Applications")]
    }

    static func installedApps() -> [AppEntry] {
        var seen = Set<String>()
        return folders.flatMap { folder -> [URL] in
            guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
            do {
                return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            } catch {
                log.error("Can't list \(folder.path): \(error)")
                return []
            }
        }
        .filter { $0.pathExtension == "app" }
        .compactMap { url in
            let bundleID = Bundle(url: url)?.bundleIdentifier
            // The same app can appear twice (e.g. a Safari copy in /Applications and /System/Applications).
            guard seen.insert(bundleID ?? url.path).inserted else { return nil }
            return AppEntry(url: url, name: FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: ""), bundleID: bundleID)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

/// App icons for SuperDock's own UI (Launchpad, the replacement Dock, the switcher), honouring custom icons.
/// Custom icons only change what SuperDock draws; the apps themselves are never modified.
@MainActor
enum IconProvider {
    private static let folder = URL.applicationSupportDirectory.appending(path: "SuperDock/Icons")
    private static var cache: [String: NSImage] = [:]

    static func icon(for appURL: URL) -> NSImage {
        let key = Bundle(url: appURL)?.bundleIdentifier ?? appURL.path
        if let cached = cache[key] { return cached }
        let custom = NSImage(contentsOf: customFile(key))
        let icon = custom ?? NSWorkspace.shared.icon(forFile: appURL.path)
        cache[key] = icon
        return icon
    }

    static func hasCustomIcon(_ appURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: customFile(key(for: appURL)).path)
    }

    /// Asks for an image and stores a PNG copy, so the original can move or be deleted.
    static func chooseCustomIcon(for appURL: URL) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.message = String(localized: "Choose an image to use as this app's icon in SuperDock")
        NSApp.activate()
        guard panel.runModal() == .OK, let source = panel.url, let image = NSImage(contentsOf: source),
              let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { return }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: customFile(key(for: appURL)), options: .atomic)
        } catch {
            log.error("Couldn't save custom icon: \(error)")
        }
        cache[key(for: appURL)] = nil
    }

    static func resetIcon(for appURL: URL) {
        let file = customFile(key(for: appURL))
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                try FileManager.default.removeItem(at: file)
            } catch {
                log.error("Couldn't remove custom icon: \(error)")
            }
        }
        cache[key(for: appURL)] = nil
    }

    private static func key(for appURL: URL) -> String {
        Bundle(url: appURL)?.bundleIdentifier ?? appURL.path
    }

    private static func customFile(_ key: String) -> URL {
        folder.appending(path: key.replacingOccurrences(of: "/", with: "_") + ".png")
    }
}
