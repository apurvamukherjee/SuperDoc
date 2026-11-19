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
    static let supportedSizes: [TileSize] = [.medium, .wide]

    static func view(size: TileSize, settings: Settings) -> some View {
        NowPlayingTile(size: size)
    }
}

private struct NowPlayingTile: View {
    let size: TileSize
    private let service = NowPlayingService.shared

    var body: some View {
        HStack(spacing: 10) {
            if let track = service.track {
                // Cover only: the title lives in the tooltip and VoiceOver label, which keeps the tile clean.
                cover(for: track)
                    .help("\(track.title) — \(track.artist)")
                    .accessibilityLabel("\(track.title), \(track.artist)")
                Spacer(minLength: 0)
            } else {
                Text("Nothing playing").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
            HStack(spacing: 4) {
                if size == .wide { control("backward.fill", "Previous", .previous) }
                control(service.track?.isPlaying == true ? "pause.fill" : "play.fill", "Play or pause", .playPause)
                control("forward.fill", "Next", .next)
            }
        }
    }

    private func cover(for track: NowPlayingService.Track) -> some View {
        Group {
            if let artwork = service.artwork {
                Image(nsImage: artwork).resizable().scaledToFill()
            } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: track.bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func control(_ symbol: String, _ label: LocalizedStringKey, _ command: NowPlayingService.Command) -> some View {
        Button { service.send(command) } label: {
            Image(systemName: symbol).font(.title3).frame(width: 30, height: 30).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Quick Actions

enum QuickAction: String, Codable, CaseIterable {
    case lock, sleepDisplays, screenshot, emptyTrash, hiddenFiles, darkMode

    var title: LocalizedStringKey {
        switch self {
        case .lock: "Lock Screen"
        case .sleepDisplays: "Sleep Displays"
        case .screenshot: "Screenshot"
        case .emptyTrash: "Empty Trash"
        case .hiddenFiles: "Show/Hide Hidden Files"
        case .darkMode: "Toggle Dark Mode"
        }
    }

    var symbol: String {
        switch self {
        case .lock: "lock.fill"
        case .sleepDisplays: "moon.fill"
        case .screenshot: "camera.viewfinder"
        case .emptyTrash: "trash"
        case .hiddenFiles: "eye"
        case .darkMode: "circle.lefthalf.filled"
        }
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
        // Two rows of buttons per column.
        let shown = settings.actions.prefix(size == .compact ? 1 : size.columns * 2)
        let columns = Array(repeating: GridItem(.flexible()), count: size == .compact ? 1 : size.columns)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(shown), id: \.self) { action in
                Button { action.run() } label: {
                    Image(systemName: action.symbol)
                        .font(size == .compact ? .title2 : .body)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .help(Text(action.title))
                .accessibilityLabel(Text(action.title))
            }
        }
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

// MARK: - Control Center

struct VolumeWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "controls.volume"
    static var name: String { String(localized: "Volume") }
    static let category = WidgetCategory.controls
    static let symbol = "speaker.wave.2"
    static let supportedSizes: [TileSize] = [.compact, .medium, .wide]

    static func view(size: TileSize, settings: Settings) -> some View {
        let audio = AudioService.shared
        let symbol = audio.isMuted ? "speaker.slash.fill" : "speaker.wave.\(min(Int(audio.volume * 3.99), 3)).fill"
        return HStack(spacing: 6) {
            Button { audio.toggleMute() } label: { Image(systemName: symbol).font(.title3).frame(width: 28) }
                .buttonStyle(.plain)
                .accessibilityLabel(audio.isMuted ? "Unmute" : "Mute")
            if size != .compact, audio.hasVolume {
                Slider(value: Binding(get: { Double(audio.volume) }, set: { audio.setVolume(Float($0)) }), in: 0...1)
                    .controlSize(.small)
                    .accessibilityLabel("Volume")
            }
        }
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
        HStack(spacing: 6) {
            Image(systemName: "sun.max.fill").font(.title3).accessibilityHidden(true)
            if let value {
                Slider(value: Binding(get: { Double(value) }, set: {
                    self.value = Float($0)
                    BrightnessControl.set(Float($0))
                }), in: 0...1)
                .controlSize(.small)
                .accessibilityLabel("Brightness")
            } else {
                Text("Not adjustable").font(.caption2).foregroundStyle(.secondary)
            }
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
        Button {
            guard let isOn else { return }
            WiFiControl.setPower(!isOn)
            self.isOn = WiFiControl.isOn
        } label: {
            Image(systemName: isOn == true ? "wifi" : "wifi.slash").font(.title2)
                .foregroundStyle(isOn == true ? Color.accentColor : .secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isOn == nil)
        .accessibilityLabel(isOn == true ? "Turn Wi-Fi off" : "Turn Wi-Fi on")
        .onAppear { isOn = WiFiControl.isOn }
    }
}
