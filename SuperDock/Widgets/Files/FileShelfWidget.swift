import AppKit
import Observation
import SwiftUI

/// Staging area for files: drop files on the tile, drag them out later into another app.
/// Holds references only; files are never copied or moved.
@MainActor @Observable
final class FileShelf {
    static let shared = FileShelf()

    private(set) var files: [URL]
    private static let fileURL = URL.applicationSupportDirectory.appending(path: "SuperDock/shelf.json")

    private init() {
        // Paths that no longer exist (moved or deleted since) are dropped on load.
        files = (JSONFile.load([String].self, from: Self.fileURL) ?? [])
            .map(URL.init(fileURLWithPath:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func add(_ urls: [URL]) {
        files = urls.filter { !files.contains($0) } + files
        save()
    }

    func remove(_ url: URL) {
        files.removeAll { $0 == url }
        save()
    }

    func clear() {
        files = []
        save()
    }

    private func save() {
        JSONFile.save(files.map(\.path), to: Self.fileURL)
    }
}

struct FileShelfWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "files.shelf"
    static var name: String { String(localized: "File Shelf") }
    static let category = WidgetCategory.files
    static let symbol = "tray.and.arrow.down"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        FileShelfTile()
    }
}

/// 8 · Glyph: a tray with a count badge. Becomes a blue "Drop" target while files hover, and new files land in it.
struct ShelfFace: View {
    @Environment(\.tile) private var tile
    var count: Int
    /// Previews of the newest files, newest first; M shows three.
    var thumbnails: [FileThumbnail]
    var isTargeted: Bool

    var body: some View {
        Group {
            if isTargeted {
                dropTarget
            } else if tile.isCompact || tile.isPortrait {
                tray
                    .overlay(alignment: .topTrailing) { if count > 0 { badge.offset(x: 10 * tile.scale, y: -11 * tile.scale) } }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 10 * tile.scale) {
                    tray.padding(.leading, 4 * tile.scale)
                    VStack(alignment: .leading, spacing: 4 * tile.scale) {
                        Text(count > 0 ? String(localized: "Shelf · \(count)") : String(localized: "Shelf")).tileStyle(.title)
                            .contentTransition(.numericText())
                        if count > 0 { strip } else { Text("Drop files here").tileStyle(.detail) }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .tileAnimation(Motion.pop, value: count)
        .tileAnimation(Motion.pop, value: thumbnails.map(\.id))
        .tileAnimation(Motion.lift, value: isTargeted)
    }

    private var tray: some View {
        Image(systemName: "tray")
            .font(.system(size: 24 * tile.scale, weight: .medium))
            .foregroundStyle(count > 0 ? tile.surface.primary : tile.surface.secondary)
            .symbolEffect(.bounce, value: count)
    }

    private var badge: some View {
        let side = 17 * tile.scale
        return Text("\(count)")
            .font(.system(size: 10.5 * tile.scale, weight: .bold).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 4 * tile.scale)
            .frame(minWidth: side, minHeight: side)
            .background(Capsule().fill(Palette.coral))
            .contentTransition(.numericText())
            .accessibilityHidden(true)
    }

    private var strip: some View {
        HStack(spacing: 4 * tile.scale) {
            ForEach(thumbnails.prefix(3)) { thumb in
                thumb.image.resizable().scaledToFill()
                    .frame(width: 18 * tile.scale, height: 22 * tile.scale)
                    .clipShape(RoundedRectangle(cornerRadius: 3.5 * tile.scale, style: .continuous))
                    .transition(.asymmetric(insertion: .offset(y: -14 * tile.scale).combined(with: .scale(scale: 0.5))
                                                .combined(with: .opacity),
                                            removal: .opacity))
            }
        }
    }

    /// The kit outline has no "target" style, so the blue ring is drawn here, bled out to the tile's edge.
    private var dropTarget: some View {
        VStack(spacing: 6 * tile.scale) {
            Image(systemName: "arrow.down").font(.system(size: 18 * tile.scale, weight: .semibold))
            Text(tile.isCompact ? "Drop" : "Drop to add").tileStyle(.caption, color: Palette.progress)
        }
        .foregroundStyle(Palette.progress)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: tile.radius, style: .continuous)
                .strokeBorder(Palette.working, lineWidth: 2)
                .padding(-tile.padding)
        }
        .tileTint(Palette.working, opacity: 0.22)
    }
}

private struct FileShelfTile: View {
    @State private var isOpen = false
    @State private var isTargeted = false
    @State private var thumbnails: [FileThumbnail] = []
    private let shelf = FileShelf.shared

    var body: some View {
        Button { isOpen = !shelf.files.isEmpty } label: {
            ShelfFace(count: shelf.files.count, thumbnails: thumbnails, isTargeted: isTargeted)
        }
        .buttonStyle(.plain)
        .task(id: Array(shelf.files.prefix(3))) {
            thumbnails = await FileThumbnails.images(for: Array(shelf.files.prefix(3)))
        }
        .dropDestination(for: URL.self) { urls, _ in
            shelf.add(urls.filter(\.isFileURL))
            return true
        } isTargeted: { isTargeted = $0 }
        .accessibilityLabel("File shelf, \(shelf.files.count) files. Drop files here.")
        .popover(isPresented: $isOpen, arrowEdge: .top) { ShelfList(shelf: shelf) }
    }
}
