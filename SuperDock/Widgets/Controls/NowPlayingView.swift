import SwiftUI

/// What the Now Playing tile shows, as plain values so the gallery can draw any state without a player.
struct NowPlayingTrack {
    var title: String
    var artist: String
    var album: String
    var isPlaying: Bool
    var artwork: Image?
    /// Tile tint, sampled from the artwork; the stand-in gradient when there is none.
    var art: [Color]
    var progress: Double?
    /// "2:08 / 4:12".
    var time: String?

    /// The stand-in when a player hands us no artwork.
    static let fallbackArt = [Color(rgb: 0x8E8E93), Color(rgb: 0x4A4B52)]
}

/// Now Playing on the Media archetype. nil track = the "Nothing playing" state.
struct NowPlayingView: View {
    @Environment(\.tile) private var tile
    var track: NowPlayingTrack?
    var send: (NowPlayingService.Command) -> Void = { _ in }

    var body: some View {
        if let track {
            MediaTile(title: track.title, artist: track.artist.isEmpty ? nil : track.artist,
                      album: track.album.isEmpty ? nil : track.album, art: track.art, artwork: track.artwork,
                      isPlaying: track.isPlaying, progress: track.progress, time: track.time,
                      waveform: Self.waveform(for: track.title),
                      onPlayPause: { send(.playPause) }, onNext: { send(.next) }, onPrevious: { send(.previous) })
                .background {
                    // Compact is all artwork; the kit only paints its tint there.
                    if tile.isCompact, let artwork = track.artwork {
                        artwork.resizable().scaledToFill().tileBleed(.all).accessibilityHidden(true)
                    }
                }
                .help(track.artist.isEmpty ? track.title : "\(track.title) — \(track.artist)")
                .accessibilityElement(children: .contain)
                .accessibilityLabel(track.artist.isEmpty ? track.title : "\(track.title), \(track.artist)")
        } else {
            NothingPlayingView()
        }
    }

    // ponytail: decorative levels seeded by the title, since real levels need an audio tap and its permission prompt.
    static func waveform(for title: String) -> [Double] {
        var seed: UInt64 = 0xCBF2_9CE4_8422_2325
        for scalar in title.unicodeScalars {
            seed = (seed ^ UInt64(scalar.value)) &* 0x100_0000_01B3
        }
        return (0..<13).map { _ in
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return 0.35 + 0.65 * Double((seed >> 33) % 1000) / 1000
        }
    }
}

/// An empty art well with a note, and a hint that any player works.
private struct NothingPlayingView: View {
    @Environment(\.tile) private var tile

    var body: some View {
        let content = tile.contentSize
        Group {
            if tile.isCompact {
                well.frame(width: content.height * 0.8, height: content.height * 0.8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tile.isPortrait {
                VStack(alignment: .leading, spacing: 6 * tile.scale) {
                    well.frame(width: content.width, height: content.width)
                    text
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 10 * tile.scale) {
                    well.frame(width: content.height * 0.8, height: content.height * 0.8)
                    text
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nothing playing")
    }

    private var well: some View {
        let shape = RoundedRectangle(cornerRadius: tile.innerRadius * 1.3, style: .continuous)
        return shape.fill(tile.surface.chipFill)
            .overlay(shape.strokeBorder(tile.surface.divider, lineWidth: 1))
            .overlay {
                Image(systemName: "music.note").font(.system(size: 18 * tile.scale, weight: .medium))
                    .foregroundStyle(tile.surface.secondary)
            }
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 2 * tile.scale) {
            Text("Nothing playing").lineLimit(2).tileStyle(.title)
            if tile.showsDetail { Text("Press play anywhere").lineLimit(2).tileStyle(.detail) }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
