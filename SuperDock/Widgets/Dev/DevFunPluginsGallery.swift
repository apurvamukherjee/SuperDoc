#if DEBUG
import SwiftUI

extension GallerySheets {
    /// Developer, Fun and plugin templates.
    /// Compare with design/mockups/02-catalog-media-controls-files-productivity-dev-fun-plugins.png.
    static var devFunPlugins: AnyView? {
        AnyView(VStack(alignment: .leading, spacing: 0) {
            ForEach([SurfaceStyle.glassDark, .solidLight, .paper], id: \.self) { DevFunPluginsPanel(style: $0) }
            DevFunPluginsScale()
        })
    }
}

private enum Fixtures {
    static let now = Date(timeIntervalSince1970: 1_795_600_000)
    static let dirty = GitSnapshot(
        repo: "superdock", status: .init(branch: "main", changed: 3, ahead: 1, behind: 0),
        commit: .init(hash: "a41c9e", date: now.addingTimeInterval(-12 * 60), subject: "tighten ring stroke at 56pt"),
        insertions: 142, deletions: 37)
    static var feature: GitSnapshot {
        var snapshot = dirty
        snapshot.status.branch = "feat/buddy-pill"
        return snapshot
    }
    static var clean: GitSnapshot {
        var snapshot = dirty
        snapshot.status = .init(branch: "main", changed: 0, ahead: 0, behind: 2)
        return snapshot
    }
    static let ports: [DevParsing.ListeningPort] = [
        .init(port: 3000, process: "node"), .init(port: 5432, process: "postgres"), .init(port: 8080, process: "python3"),
        .init(port: 5173, process: "vite"), .init(port: 6379, process: "redis"), .init(port: 9229, process: "node"),
        .init(port: 1313, process: "hugo")
    ]
    static let uuid = "3f2a91c4-7b1e-4d0a-9e5f-2c8d1b7a6e30"
    static let password = "k7#Rp2vQxL!m9Tw$e4Ha"

    static func display(_ label: String, _ symbol: String, _ content: PluginDisplay.Content, id: String = "x") -> PluginPhase {
        .ready(PluginDisplay(label: label, symbol: symbol, hue: PluginDisplay.hue(for: id), content: content), staleAge: nil)
    }

    static let stars = display("Stars", "star", .value("2.4k", subtitle: "+38 today", numeric: true))
    static let publicIP = display("Public IP", "network", .value("203.0.113.42", subtitle: "Wi-Fi · IPv4", numeric: false))
    static let xkcd = display("xkcd", "photo", .value("Fixing Problems", subtitle: "3052", numeric: false))
    static let sentiment = display("Sentiment", "gauge", .gauge(fraction: 0.62, value: "62", subtitle: nil, range: "0 – 100"))
    static let mood = display("Crypto mood", "gauge", .gauge(fraction: 0.62, value: "62", subtitle: "Greed", range: "0 fear · 100 greed"))
    static let fact = display("Random fact", "lightbulb", .text("Honey found in ancient tombs was still edible."))
    static let cat = display("Cat Fact", "cat", .text("Cats spend roughly two thirds of their day asleep."))
    static let hackerNews = display("Hacker News", "newspaper", .list(items([
        "Show HN: A dock for your widgets", "Writing a tiny Swift parser", "The case for boring tech"
    ], counts: nil)), id: "builtin.hackernews")
    static let lobsters = display("Lobsters", "newspaper", .list(items([
        "SwiftUI Canvas performance notes", "A gentle intro to CRDTs", "Why terminals still win"
    ], counts: ["88", "54", "31"])), id: "builtin.lobsters")
    static let dev = display("DEV", "chevron.left.forwardslash.chevron.right", .list(items([
        "Building menu bar apps without the pain", "ScreenCaptureKit in 50 lines", "My dotfiles, annotated"
    ], counts: ["212", "164", "97"])), id: "builtin.dev")
    static var stale: PluginPhase {
        guard case let .ready(display, _) = stars else { return stars }
        return .ready(display, staleAge: "9:40 PM")
    }

    static func items(_ titles: [String], counts: [String]?) -> [PluginDisplay.Item] {
        titles.enumerated().map { index, title in
            PluginDisplay.Item(id: index, title: title, count: counts?[index], link: "https://example.com")
        }
    }
}

private struct DevFunPluginsPanel: View {
    let style: SurfaceStyle

    private var surface: SurfaceTokens { SurfaceTokens(style) }
    private var ink: Color { style.isDark ? .white : Palette.ink }

    private func ctx(_ size: TileSize, portrait: Bool = false) -> TileContext {
        TileContext(size: size, isPortrait: portrait, surface: surface)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Developer · Fun · Plugins — \(style.rawValue) · 85 pt").font(.system(size: 28, weight: .bold)).foregroundStyle(ink)
            section("Developer", "Git Status M · W — Local Ports M · W — UUID C · M — Password C · M") {
                GitStatusView(phase: .ready(Fixtures.dirty), now: Fixtures.now).asTile(ctx(.medium))
                GitStatusView(phase: .ready(Fixtures.feature), now: Fixtures.now).asTile(ctx(.wide))
                PortsView(ports: Array(Fixtures.ports.prefix(3))).asTile(ctx(.medium))
                PortsView(ports: Array(Fixtures.ports.prefix(7))).asTile(ctx(.wide))
                UUIDView(value: nil, copied: false).asTile(ctx(.compact))
                UUIDView(value: Fixtures.uuid, copied: true).asTile(ctx(.medium))
                PasswordView(length: 20, password: nil, copied: false).asTile(ctx(.compact))
                PasswordView(length: 20, password: Fixtures.password, copied: false).asTile(ctx(.medium))
            }
            section("Developer states", "choose repo · not a repo · loading · clean & behind · no ports · copied") {
                GitStatusView(phase: .chooseRepo, now: Fixtures.now).asTile(ctx(.medium))
                GitStatusView(phase: .notARepo(folder: "Downloads"), now: Fixtures.now).asTile(ctx(.medium))
                GitStatusView(phase: .loading, now: Fixtures.now).asTile(ctx(.medium))
                GitStatusView(phase: .ready(Fixtures.clean), now: Fixtures.now).asTile(ctx(.wide))
                PortsView(ports: []).asTile(ctx(.medium))
                UUIDView(value: Fixtures.uuid, copied: true).asTile(ctx(.compact))
                UUIDView(value: Fixtures.uuid, copied: false).asTile(ctx(.medium))
                PasswordView(length: 20, password: Fixtures.password, copied: true).asTile(ctx(.compact))
                PasswordView(length: 10, password: Fixtures.password, copied: true).asTile(ctx(.medium))
            }
            section("Fun", "Dice — Coin — 8 Ball C · M (resting frames; the roll, flip and reveal play once per tap)") {
                DieView(face: 5).asTile(ctx(.compact))
                CoinView(heads: true).asTile(ctx(.compact))
                EightBallView(answer: .init(text: "Signs point to yes", kind: .positive)).asTile(ctx(.compact))
                EightBallView(answer: .init(text: "Signs point to yes", kind: .positive)).asTile(ctx(.medium))
                DieView(face: 2).asTile(ctx(.compact))
                DieView(face: 17).asTile(ctx(.compact))
                CoinView(heads: false).asTile(ctx(.compact))
                EightBallView(answer: .init(text: "Very doubtful", kind: .negative)).asTile(ctx(.compact))
                EightBallView(answer: nil).asTile(ctx(.compact))
                EightBallView(answer: nil).asTile(ctx(.medium))
            }
            section("Plugins", "value C · M — gauge C · M") {
                PluginTileView(phase: Fixtures.stars).asTile(ctx(.compact))
                PluginTileView(phase: Fixtures.publicIP).asTile(ctx(.medium))
                PluginTileView(phase: Fixtures.sentiment).asTile(ctx(.compact))
                PluginTileView(phase: Fixtures.mood).asTile(ctx(.medium))
                PluginTileView(phase: Fixtures.xkcd).asTile(ctx(.medium))
            }
            section("Plugins", "text M · W — list M · W · L (each row opens its link)") {
                PluginTileView(phase: Fixtures.fact).asTile(ctx(.medium))
                PluginTileView(phase: Fixtures.cat).asTile(ctx(.wide))
                PluginTileView(phase: Fixtures.hackerNews).asTile(ctx(.medium))
                PluginTileView(phase: Fixtures.lobsters).asTile(ctx(.wide))
                PluginTileView(phase: Fixtures.dev).asTile(ctx(.large))
            }
            section("Plugin states", "loading · offline · stale (last value, dimmed) · invalid URL") {
                PluginTileView(phase: .loading).asTile(ctx(.compact))
                PluginTileView(phase: .offline(name: "Bitcoin")).asTile(ctx(.compact))
                PluginTileView(phase: .offline(name: "Bitcoin")).asTile(ctx(.medium))
                PluginTileView(phase: Fixtures.stale).asTile(ctx(.compact))
                PluginTileView(phase: .invalidURL).asTile(ctx(.medium))
            }
            section("Portrait (vertical bar)", "M = 73 × 152, W = 73 × 231") {
                GitStatusView(phase: .ready(Fixtures.dirty), now: Fixtures.now).asTile(ctx(.medium, portrait: true))
                PortsView(ports: Fixtures.ports).asTile(ctx(.medium, portrait: true))
                UUIDView(value: Fixtures.uuid, copied: true).asTile(ctx(.medium, portrait: true))
                PasswordView(length: 20, password: Fixtures.password, copied: false).asTile(ctx(.medium, portrait: true))
                EightBallView(answer: .init(text: "Signs point to yes", kind: .positive)).asTile(ctx(.medium, portrait: true))
                PluginTileView(phase: Fixtures.publicIP).asTile(ctx(.medium, portrait: true))
                PluginTileView(phase: Fixtures.mood).asTile(ctx(.medium, portrait: true))
                PluginTileView(phase: Fixtures.fact).asTile(ctx(.medium, portrait: true))
                PluginTileView(phase: Fixtures.lobsters).asTile(ctx(.wide, portrait: true))
            }
        }
        .padding(48)
        .frame(width: 1900, alignment: .leading)
        .background(galleryWallpaper(style))
    }

    private func section(_ title: String, _ note: String, @ViewBuilder tiles: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(note).font(.system(size: 13)).opacity(0.6)
            }
            .foregroundStyle(ink)
            GalleryBar(surface: surface) { tiles() }
        }
    }
}

/// A tiny (56 pt) and a huge (120 pt) Dock, glass dark.
private struct DevFunPluginsScale: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Scale: 56 pt tight · 120 pt roomy").font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
            ForEach([56, 120], id: \.self) { thickness in
                bar(unit: CGFloat(thickness) - 2 * TileContext.spacing)
            }
        }
        .padding(48)
        .frame(width: 1900, alignment: .leading)
        .background(galleryWallpaper(.glassDark))
    }

    private func bar(unit: CGFloat) -> some View {
        let ctx = { (size: TileSize) in TileContext(unit: unit, size: size, surface: SurfaceTokens(.glassDark)) }
        return GalleryBar(surface: SurfaceTokens(.glassDark)) {
            GitStatusView(phase: .ready(Fixtures.dirty), now: Fixtures.now).asTile(ctx(.medium))
            PortsView(ports: Fixtures.ports).asTile(ctx(.wide))
            UUIDView(value: nil, copied: false).asTile(ctx(.compact))
            PasswordView(length: 20, password: Fixtures.password, copied: false).asTile(ctx(.medium))
            DieView(face: 5).asTile(ctx(.compact))
            EightBallView(answer: .init(text: "Signs point to yes", kind: .positive)).asTile(ctx(.medium))
            PluginTileView(phase: Fixtures.stars).asTile(ctx(.compact))
            PluginTileView(phase: Fixtures.mood).asTile(ctx(.medium))
            PluginTileView(phase: Fixtures.hackerNews).asTile(ctx(.medium))
        }
    }
}
#endif
