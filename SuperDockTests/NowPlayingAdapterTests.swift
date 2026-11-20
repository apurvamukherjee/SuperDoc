import Foundation
import Testing

@Test func payloadPrefersTheParentAppAndConvertsMicros() throws {
    let payload = try #require(NowPlayingPayload(json: [
        "title": "Night Drive", "artist": "Sora Vale", "playing": true,
        "bundleIdentifier": "com.google.Chrome.helper",
        "parentApplicationBundleIdentifier": "com.google.Chrome.app.cinhimbnkkaeohfgghhklpknlkffjgod",
        "durationMicros": 221_000_000.0, "elapsedTimeMicros": 84_500_000.0, "timestampEpochMicros": 1_795_109_100_000_000.0
    ]))
    #expect(payload.bundleID == "com.google.Chrome.app.cinhimbnkkaeohfgghhklpknlkffjgod")
    #expect(payload.duration == 221)
    #expect(payload.elapsed == 84.5)
    #expect(payload.elapsedAt == Date(timeIntervalSince1970: 1_795_109_100))
    #expect(payload.album.isEmpty)
}

@Test func payloadFallsBackToTheBundleID() throws {
    let payload = try #require(NowPlayingPayload(json: ["title": "Song", "playing": false, "bundleIdentifier": "com.apple.Safari"]))
    #expect(payload.bundleID == "com.apple.Safari")
    #expect(!payload.isPlaying)
    #expect(payload.duration == nil)
}

@Test func emptyOrUntitledPayloadMeansNothingPlaying() {
    #expect(NowPlayingPayload(json: [:]) == nil)
    #expect(NowPlayingPayload(json: ["title": "", "bundleIdentifier": "com.apple.Music"]) == nil)
}
