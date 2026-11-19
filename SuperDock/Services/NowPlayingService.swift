import AppKit
import Observation

// ponytail: no state until the player next changes track or play/pause; an AppleScript query on launch would need
// Automation permission per player.
/// What's playing in Music or Spotify.
///
/// MediaRemote (the private framework behind Control Center) returns nothing to third-party apps since macOS 15.4,
/// so this listens to the track-change broadcasts Music and Spotify post themselves. Free, no permission prompt.
/// Controls send the hardware media keys, so they also reach browsers and any other player.
@MainActor @Observable
final class NowPlayingService {
    static let shared = NowPlayingService()

    struct Track: Equatable, Sendable {
        var title: String
        var artist: String
        var album: String
        var isPlaying: Bool
        var bundleID: String
    }

    enum Command {
        case playPause, next, previous

        /// NX_KEYTYPE_* values from IOKit's ev_keymap.h.
        var keyType: Int {
            switch self {
            case .playPause: 16
            case .next: 17
            case .previous: 18
            }
        }
    }

    private(set) var track: Track?

    private static let sources = [
        ("com.apple.Music.playerInfo", "com.apple.Music"),
        ("com.spotify.client.PlaybackStateChanged", "com.spotify.client")
    ]
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private init() {
        for (name, bundleID) in Self.sources {
            observers.append(DistributedNotificationCenter.default().addObserver(
                forName: .init(name), object: nil, queue: .main
            ) { [weak self] note in
                let track = Self.track(from: note.userInfo ?? [:], bundleID: bundleID)
                MainActor.assumeIsolated { self?.track = track }
            })
        }
    }

    /// Music and Spotify use the same keys. "Stopped" (or quitting) clears the track.
    private nonisolated static func track(from info: [AnyHashable: Any], bundleID: String) -> Track? {
        let state = info["Player State"] as? String
        guard state != "Stopped", let title = info["Name"] as? String else { return nil }
        return Track(title: title, artist: info["Artist"] as? String ?? "", album: info["Album"] as? String ?? "",
                     isPlaying: state == "Playing", bundleID: bundleID)
    }

    func send(_ command: Command) {
        // A media key is a system-defined event: key type in the high 16 bits of data1, 0xA/0xB for down/up.
        for isDown in [true, false] {
            let event = NSEvent.otherEvent(
                with: .systemDefined, location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: isDown ? 0xA00 : 0xB00),
                timestamp: 0, windowNumber: 0, context: nil, subtype: 8,
                data1: (command.keyType << 16) | ((isDown ? 0xA : 0xB) << 8), data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
