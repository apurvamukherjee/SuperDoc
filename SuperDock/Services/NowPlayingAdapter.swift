import Foundation
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "now-playing")

/// One now-playing update from mediaremote-adapter's `stream` command.
struct NowPlayingPayload: Equatable, Sendable {
    var title: String
    var artist: String
    var album: String
    var isPlaying: Bool
    /// The app the user thinks of: a Chrome web app reports Chrome's helper as `bundleIdentifier` and the app itself as
    /// the parent.
    var bundleID: String
    var duration: Double?
    var elapsed: Double?
    var elapsedAt: Date?
    var artworkBase64: String?

    /// nil when nothing is playing (the adapter sends an empty payload then).
    init?(json: [String: Any]) {
        guard let title = json["title"] as? String, !title.isEmpty,
              let bundleID = (json["parentApplicationBundleIdentifier"] ?? json["bundleIdentifier"]) as? String
        else { return nil }
        self.title = title
        self.bundleID = bundleID
        artist = json["artist"] as? String ?? ""
        album = json["album"] as? String ?? ""
        isPlaying = json["playing"] as? Bool ?? false
        duration = (json["durationMicros"] as? Double).map { $0 / 1_000_000 }
        elapsed = (json["elapsedTimeMicros"] as? Double).map { $0 / 1_000_000 }
        elapsedAt = (json["timestampEpochMicros"] as? Double).map { Date(timeIntervalSince1970: $0 / 1_000_000) }
        artworkBase64 = json["artworkData"] as? String
    }
}

/// Runs the bundled mediaremote-adapter (Vendor/MediaRemoteAdapter, BSD-3-Clause) under /usr/bin/perl, the only kind of
/// process MediaRemote still answers since macOS 15.4, and reports every player: browsers, web apps, Podcasts, Music.
/// ponytail: Apple can close this door in any macOS update; NowPlayingService keeps its Music/Spotify path for that.
final class NowPlayingAdapter: @unchecked Sendable {
    enum StartError: Error {
        case notBundled
        case launchFailed(Error)
    }

    // The pipe's handler runs serially on one background queue, so `buffer` needs no lock.
    private var buffer = Data()
    private let process = Process()

    /// `onPayload` gets nil when playback stops. `onExit` runs if the adapter dies, e.g. after Apple blocks it.
    init(onPayload: @escaping @Sendable (NowPlayingPayload?) -> Void, onExit: @escaping @Sendable () -> Void) throws(StartError) {
        guard let script = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
              let framework = Bundle.main.privateFrameworksURL?.appending(path: "MediaRemoteAdapter.framework"),
              FileManager.default.fileExists(atPath: framework.path) else { throw .notBundled }
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        // No diffs: every line is the whole state. Debounce folds a track change's burst of partial updates into one.
        process.arguments = [script.path, framework.path, "stream", "--no-diff", "--micros", "--debounce=150"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self?.consume(chunk, onPayload)
        }
        process.terminationHandler = { process in
            output.fileHandleForReading.readabilityHandler = nil
            // SIGTERM is our own `stop()`; anything else means the adapter couldn't run.
            guard process.terminationReason != .uncaughtSignal else { return }
            log.error("mediaremote-adapter exited with \(process.terminationStatus)")
            onExit()
        }
        do {
            try process.run()
        } catch {
            throw .launchFailed(error)
        }
    }

    func stop() {
        if process.isRunning { process.terminate() }
    }

    private func consume(_ chunk: Data, _ onPayload: (NowPlayingPayload?) -> Void) {
        buffer.append(chunk)
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let payload = message["payload"] as? [String: Any] else {
                log.error("Unreadable line from mediaremote-adapter")
                continue
            }
            onPayload(NowPlayingPayload(json: payload))
        }
    }
}
