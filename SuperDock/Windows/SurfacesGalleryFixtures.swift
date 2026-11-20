#if DEBUG
import AppKit
import SwiftUI

/// Fixture data for the surfaces sheet: the same copies, windows, apps and files as mockup 08.
@MainActor
enum SurfaceFixtures {
    nonisolated static let now = Date(timeIntervalSinceReferenceDate: 785_000_000)

    static func image(_ view: some View, size: CGSize) -> NSImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        return renderer.nsImage ?? NSImage(size: size)
    }

    static func gradient(_ colors: [UInt32]) -> LinearGradient {
        LinearGradient(colors: colors.map { Color(rgb: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: Clipboard

    static let clips: [ClipItem] = {
        func clip(_ kind: ClipItem.Kind, _ text: String?, minutes: Double, app: String?, slot: Int? = nil,
                  image: String? = nil) -> ClipItem {
            ClipItem(kind: kind, text: text, imageFile: image, date: now.addingTimeInterval(-minutes * 60), sourceApp: app,
                     pinnedSlot: slot)
        }
        return [
            clip(.text, "npm run dev -- --port 5173", minutes: 0, app: "com.apple.Terminal"),
            clip(.text, "Ship the onboarding copy before Friday, then tidy the release notes", minutes: 2, app: "com.apple.Notes"),
            clip(.color, "#FF5A4E", minutes: 5, app: "com.apple.Preview"),
            clip(.image, nil, minutes: 9, app: "com.apple.Preview", image: "fixture-shot"),
            clip(.link, "https://github.com/superdock/superdock/pull/212", minutes: 12, app: "com.apple.Safari"),
            clip(.file, "/Users/limo/Documents/design-brief.md", minutes: 20, app: "com.apple.finder"),
            clip(.text, "Thanks, talk soon!", minutes: 300, app: "com.apple.mail", slot: 1),
            clip(.text, "1 Infinite Loop", minutes: 900, app: "com.apple.Notes", slot: 2),
            clip(.text, "ssh limo@build.local", minutes: 2000, app: "com.apple.Terminal", slot: 3)
        ]
    }()

    static func registerClipImages() {
        ClipImages.fixtures["fixture-shot"] = image(gradient([0xFF7A59, 0xD94FA0, 0x8E3BF2]), size: CGSize(width: 144, height: 90))
    }

    // MARK: Windows

    private static let shots: [CGWindowID: AnyView] = [
        1: AnyView(VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach([0xFF5F57, 0xFEBC2E, 0x28C840] as [UInt32], id: \.self) { Circle().fill(Color(rgb: $0)).frame(width: 6) }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(6).background(Color(rgb: 0xE2E2E6))
            gradient([0xF4F4F6, 0xDCDCE2])
        }),
        2: AnyView(ZStack(alignment: .topLeading) {
            gradient([0x2A2B30, 0x16171A])
            Text("$ claude\n› working on superdock…").font(.system(size: 7, design: .monospaced)).foregroundStyle(Palette.good).padding(9)
        }),
        3: AnyView(gradient([0xB18CFF, 0x6B45F0])),
        4: AnyView(gradient([0xD8667A, 0xB43A6A])),
        5: AnyView(gradient([0xF3F3F6, 0xDADAE0])),
        6: AnyView(gradient([0xE6EAF2, 0xBFC8D8]))
    ]

    static var windowImages: WindowImages {
        var thumbnails: [CGWindowID: CGImage] = [:]
        for (id, view) in shots {
            let renderer = ImageRenderer(content: view.frame(width: 136, height: 88))
            renderer.scale = 2
            thumbnails[id] = renderer.cgImage
        }
        return WindowImages(thumbnails: thumbnails) { window in appIcon(window.appName) }
    }

    static let switcherWindows = [
        WindowInfo(id: 1, pid: 1, appName: "Safari", title: "Pull request #212", bounds: .zero, isOnScreen: true),
        WindowInfo(id: 2, pid: 2, appName: "Terminal", title: "superdock", bounds: .zero, isOnScreen: true),
        WindowInfo(id: 3, pid: 3, appName: "Xcode", title: "SuperDock", bounds: .zero, isOnScreen: true),
        WindowInfo(id: 4, pid: 4, appName: "Music", title: "Music", bounds: .zero, isOnScreen: false)
    ]

    static let previewWindows = [
        WindowInfo(id: 5, pid: 1, appName: "Safari", title: "Pull request #212", bounds: .zero, isOnScreen: true),
        WindowInfo(id: 6, pid: 1, appName: "Safari", title: "Open-Meteo docs", bounds: .zero, isOnScreen: true)
    ]

    // MARK: Apps

    struct App {
        let name: String, symbol: String, colors: [UInt32]
        init(_ name: String, _ symbol: String, _ colors: [UInt32]) { (self.name, self.symbol, self.colors) = (name, symbol, colors) }
    }

    static let apps = [
        App("Files", "folder", [0x7DB7FF, 0x3A7DF0]), App("Safari", "globe", [0x5EE0D0, 0x2F6FE0]),
        App("Terminal", "chevron.right", [0x34363C, 0x15161A]),
        App("Xcode", "chevron.left.forwardslash.chevron.right", [0xB08CFF, 0x6D44F0]),
        App("Music", "music.note", [0xFF7A8A, 0xF0386B]), App("Messages", "message", [0x6EDB7E, 0x28A745]),
        App("Calendar", "calendar", [0xFFFFFF, 0xE8E8EC]), App("Photos", "photo", [0xFFD25A, 0xFF9530]),
        App("SuperDock", "face.smiling", [0xFBF9F4, 0xE4DFD3]), App("Keychain", "lock", [0x5A6378, 0x343B4C]),
        App("Mail", "tray", [0x5BC8F5, 0x2D7FE0]), App("Utilities", "wrench.and.screwdriver", [0x55606F, 0x3A4350])
    ]

    private static var iconCache: [String: NSImage] = [:]

    static func appIcon(_ name: String) -> NSImage {
        if let cached = iconCache[name] { return cached }
        let entry = apps.first { $0.name == name } ?? App(name, "app", [0x8E8E93, 0x5E5E63])
        let light = entry.colors[0] == 0xFFFFFF || entry.colors[0] == 0xFBF9F4
        let icon = image(ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(gradient(entry.colors))
            Image(systemName: entry.symbol).font(.system(size: 26, weight: .semibold))
                .foregroundStyle(light ? Palette.coral : .white)
        }.padding(4), size: CGSize(width: 64, height: 64))
        iconCache[name] = icon
        return icon
    }

    static let launchpadModel: Launchpad.Model = {
        let model = Launchpad.Model()
        model.apps = apps.map { AppEntry(url: URL(fileURLWithPath: "/Applications/\($0.name).app"), name: $0.name, bundleID: nil) }
        model.pageCount = 2
        return model
    }()

    // MARK: Files

    static let stackItems = ["Screenshot 22.46.png", "invoice-nov.pdf", "wallpaper.heic", "superdock-0.1.1.zip",
                             "design-brief.md", "cover-art.jpg", "usage-export.csv", "install.sh"]
        .map { URL(fileURLWithPath: "/tmp/superdock-gallery/\($0)") }

    /// Real files in a temp folder, so the shelf shows real sizes and item counts.
    static func shelfFiles() -> [URL] {
        let folder = FileManager.default.temporaryDirectory.appending(path: "superdock-gallery-shelf")
        let assets = folder.appending(path: "assets")
        do {
            try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        } catch {
            FileHandle.standardError.write(Data("surfaces gallery: no temp folder: \(error)\n".utf8))
        }
        let png = folder.appending(path: "hero-dark.png")
        let markdown = folder.appending(path: "design-brief.md")
        FileManager.default.createFile(atPath: png.path, contents: Data(count: 2_400_000))
        FileManager.default.createFile(atPath: markdown.path, contents: Data(count: 14_000))
        for index in 1...18 { FileManager.default.createFile(atPath: assets.appending(path: "\(index).svg").path, contents: Data()) }
        return [png, markdown, assets]
    }

    // MARK: Menu

    static let menuTitle = MenuStatus.title(
        sessions: (1...3).map { AgentSessionService.Session(id: "\($0)", tool: .claude, project: "p\($0)", status: .working) },
        usage: [.claude: AIUsageService.Usage(windows: [LimitWindow(label: "5h", usedPercent: 62, resetsAt: nil)], capturedAt: now)],
        now: now)
}
#endif
