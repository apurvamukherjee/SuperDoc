import AppKit
import Observation
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "now-playing")

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
        /// Seconds; nil when the player doesn't say.
        var duration: Double?
    }

    /// Where playback was at a moment, so the tile can extrapolate the position instead of polling the player.
    struct Position: Equatable, Sendable {
        var seconds: Double
        var date: Date
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
    /// Cover art for `track`, fetched from the player over Apple Events (one Automation prompt per player).
    private(set) var artwork: NSImage?
    /// Top-left and bottom-right averages of `artwork`, for the tile tint. Empty without artwork.
    private(set) var artworkColors: [NSColor] = []
    private(set) var position: Position?

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
                let info = note.userInfo ?? [:]
                let track = Self.track(from: info, bundleID: bundleID)
                // Spotify reports its position; Music doesn't, so `update` asks it.
                let reported = info["Playback Position"] as? Double
                MainActor.assumeIsolated { self?.update(track, reportedPosition: reported) }
            })
        }
    }

    private func update(_ new: Track?, reportedPosition: Double?) {
        let trackChanged = new?.title != track?.title || new?.album != track?.album || new?.bundleID != track?.bundleID
        track = new
        updatePosition(for: new, reported: reportedPosition)
        guard trackChanged else { return }
        artwork = nil
        artworkColors = []
        guard let new else { return }
        Task { [weak self] in
            let image = await Self.fetchArtwork(bundleID: new.bundleID)
            // Skip stale results if the track changed again while we were fetching.
            guard let self, self.track?.title == new.title, self.track?.bundleID == new.bundleID else { return }
            self.artwork = image
            self.artworkColors = image.map(Self.cornerColors) ?? []
        }
    }

    // ponytail: re-anchored only on player notifications, so a seek inside Music drifts until the next play/pause
    // or track change; poll `player position` while playing if that matters.
    private func updatePosition(for new: Track?, reported: Double?) {
        if let reported {
            position = Position(seconds: reported, date: .now)
            return
        }
        guard let new, new.bundleID == "com.apple.Music" else {
            position = nil
            return
        }
        Task { [weak self] in
            // Same Automation permission as the artwork; a declined prompt just hides the progress bar.
            guard let seconds = Self.runScript("tell application \"Music\" to get player position")?.doubleValue,
                  let self, self.track == new else { return }
            self.position = Position(seconds: seconds, date: .now)
        }
    }

    /// Averages the artwork's top-left and bottom-right quarters on a 16 × 16 thumbnail.
    private static func cornerColors(of image: NSImage) -> [NSColor] {
        let side = 16
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return [] }
        let half = side / 2
        // Bitmap memory starts at the top row.
        return [(0, 0), (half, half)].map { originX, originY in
            var sum = [0.0, 0.0, 0.0]
            for row in originY..<originY + half {
                for column in originX..<originX + half {
                    let offset = (row * side + column) * 4
                    for channel in 0..<3 { sum[channel] += Double(pixels[offset + channel]) }
                }
            }
            let count = Double(half * half) * 255
            return NSColor(srgbRed: sum[0] / count, green: sum[1] / count, blue: sum[2] / count, alpha: 1)
        }
    }

    /// Music hands back the image bytes; Spotify only gives an https URL to its CDN.
    private static func fetchArtwork(bundleID: String) async -> NSImage? {
        switch bundleID {
        case "com.apple.Music":
            let result = runScript("tell application \"Music\" to get raw data of artwork 1 of current track")
            return result.flatMap { NSImage(data: $0.data) }
        case "com.spotify.client":
            guard let link = runScript("tell application \"Spotify\" to get artwork url of current track")?.stringValue,
                  let url = URL(string: link), url.scheme == "https" else { return nil }
            do {
                return NSImage(data: try await URLSession.shared.data(from: url).0)
            } catch {
                log.error("Spotify artwork download failed: \(error)")
                return nil
            }
        default:
            return nil
        }
    }

    private static func runScript(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        // Tracks without artwork and a declined Automation prompt both land here; the tile falls back to the app icon.
        if let error { log.info("Artwork script failed: \(error)") }
        return result
    }

    /// Music and Spotify use the same keys. "Stopped" (or quitting) clears the track.
    private nonisolated static func track(from info: [AnyHashable: Any], bundleID: String) -> Track? {
        let state = info["Player State"] as? String
        guard state != "Stopped", let title = info["Name"] as? String else { return nil }
        // Music sends "Total Time", Spotify "Duration", both in milliseconds.
        let millis = (info["Total Time"] ?? info["Duration"]) as? Double
        return Track(title: title, artist: info["Artist"] as? String ?? "", album: info["Album"] as? String ?? "",
                     isPlaying: state == "Playing", bundleID: bundleID, duration: millis.map { $0 / 1000 })
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
