import AppKit
import Carbon.HIToolbox
import SwiftUI
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "quick-actions")

struct NowPlayingWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "media.nowPlaying"
    static var name: String { String(localized: "Now Playing") }
    static let category = WidgetCategory.media
    static let symbol = "play.circle"
    static let supportedSizes: [TileSize] = [.compact, .medium, .wide, .large]

    static func view(size: TileSize, settings: Settings) -> some View {
        NowPlayingTile()
    }
}

private struct NowPlayingTile: View {
    private let service = NowPlayingService.shared

    var body: some View {
        if let track = service.track, track.isPlaying, track.duration != nil, service.position != nil {
            // Ticks only while something plays; paused or unknown length, the tile rests.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                NowPlayingView(track: model(track, at: context.date), send: service.send)
            }
        } else {
            NowPlayingView(track: service.track.map { model($0, at: .now) }, send: service.send)
        }
    }

    private func model(_ track: NowPlayingService.Track, at date: Date) -> NowPlayingTrack {
        let elapsed = service.position.map { $0.seconds + (track.isPlaying ? date.timeIntervalSince($0.date) : 0) }
        var progress: Double?
        var time: String?
        if let elapsed, let duration = track.duration, duration > 0 {
            let clamped = min(max(elapsed, 0), duration)
            progress = clamped / duration
            time = "\(Self.clock(clamped)) / \(Self.clock(duration))"
        }
        return NowPlayingTrack(
            title: track.title, artist: track.artist, album: track.album, isPlaying: track.isPlaying,
            artwork: service.artwork.map { Image(nsImage: $0) },
            art: service.artworkColors.isEmpty ? NowPlayingTrack.fallbackArt : service.artworkColors.map { Color(nsColor: $0) },
            progress: progress, time: time)
    }

    private static func clock(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }
}

// MARK: - Quick Actions

enum QuickAction: String, Codable, CaseIterable {
    case lock, sleepDisplays, screenshot, emptyTrash, hiddenFiles, darkMode

    var title: String {
        switch self {
        case .lock: String(localized: "Lock Screen")
        case .sleepDisplays: String(localized: "Sleep Displays")
        case .screenshot: String(localized: "Screenshot")
        case .emptyTrash: String(localized: "Empty Trash")
        case .hiddenFiles: String(localized: "Show/Hide Hidden Files")
        case .darkMode: String(localized: "Toggle Dark Mode")
        }
    }

    var symbol: String {
        switch self {
        case .lock: "lock"
        case .sleepDisplays: "display"
        case .screenshot: "camera"
        case .emptyTrash: "trash"
        case .hiddenFiles: "eye"
        case .darkMode: "circle.lefthalf.filled"
        }
    }

    /// The toggles whose setting is on right now; their buttons light up.
    static func lit() -> Set<QuickAction> {
        var lit = Set<QuickAction>()
        if UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" { lit.insert(.darkMode) }
        if CFPreferencesGetAppBooleanValue("AppleShowAllFiles" as CFString, "com.apple.finder" as CFString, nil) {
            lit.insert(.hiddenFiles)
        }
        return lit
    }

    @MainActor
    func run() {
        switch self {
        case .lock:
            // Same as pressing ⌃⌘Q; there's no public lock API.
            for isDown in [true, false] {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_Q), keyDown: isDown)
                event?.flags = [.maskControl, .maskCommand]
                event?.post(tap: .cghidEventTap)
            }
        case .sleepDisplays:
            Self.launch("/usr/bin/pmset", ["displaysleepnow"])
        case .screenshot:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app"))
        case .emptyTrash:
            let alert = NSAlert()
            alert.messageText = String(localized: "Empty the Trash?")
            alert.informativeText = String(localized: "Items in the Trash will be deleted permanently.")
            alert.addButton(withTitle: String(localized: "Empty Trash"))
            alert.addButton(withTitle: String(localized: "Cancel"))
            NSApp.activate()
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            // Finder does the deleting, so SuperDock itself never removes files (hard rule 8).
            Self.appleScript(#"tell application "Finder" to empty trash"#)
        case .hiddenFiles:
            let domain = "com.apple.finder" as CFString
            let key = "AppleShowAllFiles" as CFString
            let shown = CFPreferencesGetAppBooleanValue(key, domain, nil)
            CFPreferencesSetAppValue(key, (!shown) as CFBoolean, domain)
            CFPreferencesAppSynchronize(domain)
            Self.launch("/usr/bin/killall", ["Finder"])   // Finder only rereads this on launch; launchd restarts it
        case .darkMode:
            Self.appleScript(#"tell application "System Events" to tell appearance preferences to set dark mode to not dark mode"#)
        }
    }

    private static func launch(_ path: String, _ arguments: [String]) {
        do {
            try Process.run(URL(fileURLWithPath: path), arguments: arguments)
        } catch {
            log.error("\(path) failed: \(error)")
        }
    }

    /// The first run asks for Automation permission for the target app (Finder or System Events).
    private static func appleScript(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { log.error("AppleScript failed: \(error)") }
    }
}

struct QuickActionsWidget: SuperWidget {
    struct Settings: Codable, Equatable {
        var actions: [QuickAction] = [.lock, .screenshot, .darkMode, .emptyTrash]
    }
    static let id = "controls.quickActions"
    static var name: String { String(localized: "Quick Actions") }
    static let category = WidgetCategory.controls
    static let symbol = "bolt.circle"
    static let supportedSizes: [TileSize] = [.compact, .medium, .wide]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        QuickActionsTile(actions: settings.actions)
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(VStack(alignment: .leading) {
            ForEach(QuickAction.allCases, id: \.self) { action in
                Toggle(isOn: Binding(
                    get: { settings.wrappedValue.actions.contains(action) },
                    set: { isOn in
                        settings.wrappedValue.actions.removeAll { $0 == action }
                        if isOn { settings.wrappedValue.actions.append(action) }
                    }
                )) { Label(action.title, systemImage: action.symbol) }
            }
            Text("Empty Trash and Dark Mode ask for permission to control Finder / System Events the first time.")
                .font(.caption).foregroundStyle(.secondary)
        })
    }
}

private struct QuickActionsTile: View {
    let actions: [QuickAction]
    @State private var lit = QuickAction.lit()

    var body: some View {
        QuickActionsView(items: actions.map { action in
            QuickActionsView.Item(id: action.rawValue, symbol: action.symbol, label: action.title,
                                  isOn: lit.contains(action)) {
                action.run()
                lit = QuickAction.lit()
            }
        })
        // Dark Mode can change elsewhere while the tile is hidden.
        .onAppear { lit = QuickAction.lit() }
    }
}

// MARK: - Control Center

struct VolumeWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "controls.volume"
    static var name: String { String(localized: "Volume") }
    static let category = WidgetCategory.controls
    static let symbol = "speaker.wave.2"
    static let supportedSizes: [TileSize] = [.compact, .medium, .wide]

    static func view(size: TileSize, settings: Settings) -> some View {
        VolumeTile()
    }
}

private struct VolumeTile: View {
    private let audio = AudioService.shared

    var body: some View {
        VolumeView(level: Double(audio.volume), isMuted: audio.isMuted, isAdjustable: audio.hasVolume,
                   setLevel: { audio.setVolume(Float($0)) }, toggleMute: audio.toggleMute)
    }
}

struct BrightnessWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "controls.brightness"
    static var name: String { String(localized: "Brightness") }
    static let category = WidgetCategory.controls
    static let symbol = "sun.max"
    static let supportedSizes: [TileSize] = [.medium, .wide]

    static func view(size: TileSize, settings: Settings) -> some View {
        BrightnessTile()
    }
}

private struct BrightnessTile: View {
    @State private var value = BrightnessControl.brightness

    var body: some View {
        BrightnessView(level: value.map(Double.init)) { level in
            value = Float(level)
            BrightnessControl.set(Float(level))
        }
        // Re-read when shown, since brightness keys change it behind our back.
        .onAppear { value = BrightnessControl.brightness }
    }
}

struct WiFiWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "controls.wifi"
    static var name: String { String(localized: "Wi-Fi") }
    static let category = WidgetCategory.controls
    static let symbol = "wifi"
    static let supportedSizes: [TileSize] = [.compact]

    static func view(size: TileSize, settings: Settings) -> some View {
        WiFiTile()
    }
}

private struct WiFiTile: View {
    @State private var isOn = WiFiControl.isOn

    var body: some View {
        WiFiView(isOn: isOn) {
            guard let isOn else { return }
            WiFiControl.setPower(!isOn)
            self.isOn = WiFiControl.isOn
        }
        .onAppear { isOn = WiFiControl.isOn }
    }
}
