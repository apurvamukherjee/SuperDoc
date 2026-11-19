import AppKit
import AVFoundation

// ponytail: Lock Screen video isn't possible without replacing system wallpaper assets, so it's left out.
/// Animated desktop backgrounds: a built-in aurora, or a looping video file (MP4/MOV).
/// Drawn in a window just above the system wallpaper and below desktop icons, one per display; paused while the
/// displays sleep.
@MainActor
final class LiveWallpaper {
    enum Kind: String, CaseIterable {
        case off, aurora, video
    }

    static let kindKey = "wallpaper.kind"
    static let videoKey = "wallpaper.videoPath"

    private var windows: [NSWindow] = []
    private var players: [AVQueuePlayer] = []
    private var loopers: [AVPlayerLooper] = []
    private var auroras: [AuroraView] = []
    private var applied: (Kind, String?)?
    private var observers: [NSObjectProtocol] = []

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        observers = [
            NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.sync(force: false) }
            },
            NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                                   queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sync(force: true) }
            },
            workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setPaused(true) }
            },
            workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setPaused(false) }
            }
        ]
        sync(force: true)
    }

    private func sync(force: Bool) {
        let kind = UserDefaults.standard.string(forKey: Self.kindKey).flatMap(Kind.init) ?? .off
        let video = UserDefaults.standard.string(forKey: Self.videoKey)
        guard force || applied.map({ $0 != kind || $1 != video }) ?? true else { return }
        applied = (kind, video)
        tearDown()
        guard kind != .off else { return }
        for screen in NSScreen.screens {
            let window = Self.makeWindow(for: screen)
            switch kind {
            case .aurora:
                let aurora = AuroraView(frame: screen.frame)
                auroras.append(aurora)
                window.contentView = aurora
            case .video:
                guard let video else { continue }
                window.contentView = makePlayerView(URL(fileURLWithPath: video))
            case .off:
                continue
            }
            window.orderFront(nil)
            windows.append(window)
        }
    }

    private func setPaused(_ paused: Bool) {
        auroras.forEach { $0.setPaused(paused) }
        players.forEach { paused ? $0.pause() : $0.play() }
    }

    private func tearDown() {
        players.forEach { $0.pause() }
        players = []
        loopers = []
        auroras = []
        windows.forEach { $0.orderOut(nil) }
        windows = []
    }

    private func makePlayerView(_ url: URL) -> NSView {
        let player = AVQueuePlayer()
        player.isMuted = true
        loopers.append(AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url)))
        players.append(player)
        let view = NSView()
        view.wantsLayer = true
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        player.play()
        return view
    }

    private static func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        // Just above the real wallpaper, below Finder's desktop icons (which sit 20 levels higher).
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        // One per Space, like a real wallpaper, so it slides with Space switches.
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.setFrame(screen.frame, display: false)
        return window
    }
}

/// Slow aurora: a gradient whose colours and direction drift over a minute. It's a Core Animation animation, so the
/// system compositor runs it and SuperDock does no per-frame work (a SwiftUI timeline cost ~5% CPU full-screen).
private final class AuroraView: NSView {
    private let gradient = CAGradientLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer = gradient
        let palettes: [[CGColor]] = stride(from: 0.0, to: 1.0, by: 0.2).map { hue in
            [0, 0.18, 0.36].map {
                NSColor(hue: (hue + $0).truncatingRemainder(dividingBy: 1), saturation: 0.65, brightness: 0.45, alpha: 1).cgColor
            }
        }
        gradient.colors = palettes[0]
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }

        let colors = CAKeyframeAnimation(keyPath: "colors")
        colors.values = palettes + [palettes[0]]
        colors.duration = 90
        let start = CABasicAnimation(keyPath: "startPoint")
        start.toValue = CGPoint(x: 1, y: 1)
        let end = CABasicAnimation(keyPath: "endPoint")
        end.toValue = CGPoint(x: 0, y: 0)
        for animation in [start, end] {
            animation.duration = 45
            animation.autoreverses = true
        }
        let group = CAAnimationGroup()
        group.animations = [colors, start, end]
        group.duration = 90
        group.repeatCount = .infinity
        gradient.add(group, forKey: "aurora")
    }

    required init?(coder: NSCoder) { nil }

    /// Freezes the animation in place (displays asleep).
    func setPaused(_ paused: Bool) {
        guard paused != (gradient.speed == 0) else { return }
        if paused {
            gradient.timeOffset = gradient.convertTime(CACurrentMediaTime(), from: nil)
            gradient.speed = 0
        } else {
            let pausedAt = gradient.timeOffset
            gradient.speed = 1
            gradient.timeOffset = 0
            gradient.beginTime = 0
            gradient.beginTime = gradient.convertTime(CACurrentMediaTime(), from: nil) - pausedAt
        }
    }
}
