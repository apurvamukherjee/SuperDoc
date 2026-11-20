import AppKit
import Observation
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "now-playing")

/// What's playing, in any app.
///
/// MediaRemote (the private framework behind Control Center) returns nothing to third-party apps since macOS 15.4, so
/// while a tile is subscribed this runs the bundled mediaremote-adapter, which covers every player (YouTube Music in
/// Chrome, Safari tabs, Podcasts…). If the adapter can't run, it falls back to the track-change broadcasts Music and
/// Spotify post themselves. Controls send the hardware media keys, which reach any player.
/// ponytail: the fallback has no state until the player next changes track or play/pause.
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
    @ObservationIgnored private var adapter: NowPlayingAdapter?
    @ObservationIgnored private var subscribers = 0
    /// The artwork the adapter last sent, so an unchanged image isn't decoded again on every update.
    @ObservationIgnored private var adapterArtwork: String?

    private init() {
        for (name, bundleID) in Self.sources {
            observers.append(DistributedNotificationCenter.default().addObserver(
                forName: .init(name), object: nil, queue: .main
            ) { [weak self] note in
                let info = note.userInfo ?? [:]
                let track = Self.track(from: info, bundleID: bundleID)
                // Spotify reports its position; Music doesn't, so `update` asks it.
                let reported = info["Playback Position"] as? Double
                MainActor.assumeIsolated {
                    guard let self, self.adapter == nil else { return }
                    self.update(track, reportedPosition: reported)
                }
            })
        }
    }

    /// Tiles call these on appear/disappear; the adapter process only runs while one is on screen.
    func subscribe() {
        subscribers += 1
        guard subscribers == 1 else { return }
        do {
            adapter = try NowPlayingAdapter(onPayload: { [weak self] payload in
                Task { @MainActor in self?.apply(payload) }
            }, onExit: { [weak self] in
                Task { @MainActor in self?.adapter = nil }
            })
        } catch {
            log.error("mediaremote-adapter unavailable, using Music/Spotify broadcasts: \(String(describing: error))")
        }
    }

    func unsubscribe() {
        subscribers = max(subscribers - 1, 0)
        guard subscribers == 0 else { return }
        adapter?.stop()
        adapter = nil
    }

    private func apply(_ payload: NowPlayingPayload?) {
        guard let payload else {
            (track, position, artwork, artworkColors, adapterArtwork) = (nil, nil, nil, [], nil)
            return
        }
        let new = Track(title: payload.title, artist: payload.artist, album: payload.album, isPlaying: payload.isPlaying,
                        bundleID: payload.bundleID, duration: payload.duration)
        let sameTrack = new.title == track?.title && new.bundleID == track?.bundleID
        track = new
        position = payload.elapsed.map { Position(seconds: $0, date: payload.elapsedAt ?? .now) }
        // Artwork often arrives a moment after the title; until then keep the last image if the track hasn't changed.
        if payload.artworkBase64 == nil, sameTrack { return }
        guard payload.artworkBase64 != adapterArtwork else { return }
        adapterArtwork = payload.artworkBase64
        let image = payload.artworkBase64.flatMap { Data(base64Encoded: $0) }.flatMap(NSImage.init(data:))
        artwork = image
        artworkColors = image.map(Self.cornerColors) ?? []
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
