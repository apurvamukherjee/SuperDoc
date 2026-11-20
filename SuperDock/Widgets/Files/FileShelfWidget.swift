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
        FileShelfTile(size: size)
    }
}

private struct FileShelfTile: View {
    let size: TileSize
    @State private var isOpen = false
    @State private var isTargeted = false
    private let shelf = FileShelf.shared

    var body: some View {
        Button { isOpen = !shelf.files.isEmpty } label: {
            ZStack(alignment: .topTrailing) {
                if let first = shelf.files.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: first.path)).resizable().scaledToFit().padding(4)
                } else {
                    Image(systemName: "tray.and.arrow.down").font(.title2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if shelf.files.count > 1 {
                    Text("\(shelf.files.count)").font(.caption2.bold()).padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.tint, in: Capsule()).foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isTargeted ? AnyShapeStyle(.tint.opacity(0.25)) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .dropDestination(for: URL.self) { urls, _ in
            shelf.add(urls.filter(\.isFileURL))
            return true
        } isTargeted: { isTargeted = $0 }
        .accessibilityLabel("File shelf, \(shelf.files.count) files. Drop files here.")
        .popover(isPresented: $isOpen, arrowEdge: .top) { ShelfList(shelf: shelf) }
    }
}
