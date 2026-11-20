import AppKit
import SwiftUI

/// The File Shelf popover. Owned by the around-the-bar surfaces; the tile lives in FileShelfWidget.swift.
struct ShelfList: View {
    let shelf: FileShelf

    var body: some View {
        ShelfListView(files: shelf.files, onRemove: shelf.remove, onClear: shelf.clear, onDrop: shelf.add)
    }
}

/// Plain values in, so the gallery can draw it without a real shelf.
struct ShelfListView: View {
    let files: [URL]
    let onRemove: (URL) -> Void
    let onClear: () -> Void
    let onDrop: ([URL]) -> Void

    var body: some View {
        ShelfContent(list: self).surfaceContext()
    }

    /// "2.4 MB", "Folder · 18 items"; nil when the file has moved since it was shelved.
    static func detail(for url: URL) -> String? {
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
        } catch {
            return nil   // moved or deleted since; the row still shows its name, just without a detail line
        }
        if values.isDirectory == true {
            do {
                let count = try FileManager.default.contentsOfDirectory(atPath: url.path).count
                return String(localized: "Folder · \(count) items")
            } catch {
                return String(localized: "Folder")   // unreadable folder: say what it is, skip the count
            }
        }
        return values.fileSize.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) }
    }
}

private struct ShelfContent: View {
    @Environment(\.tile) private var tile
    let list: ShelfListView
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Shelf").tileStyle(.value)
                Spacer()
                if !list.files.isEmpty {
                    Button(action: list.onClear) { Text("Clear").tileStyle(.detail) }.buttonStyle(.plain)
                }
            }
            Text("Drag files out to use them.").tileStyle(.detail).padding(.bottom, 2)
            ForEach(list.files, id: \.self) { row($0) }
            dropZone
        }
        .padding(14)
        .frame(width: 300)
    }

    private func row(_ url: URL) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: SurfaceKit.icon(for: url)).resizable().scaledToFit().frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent).tileStyle(.title).truncationMode(.middle)
                if let detail = ShelfListView.detail(for: url) { Text(detail).tileStyle(.detail) }
            }
            Spacer(minLength: 4)
            Button { list.onRemove(url) } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(tile.surface.secondary)
                    .frame(width: 18, height: 18).background(tile.surface.controlFill, in: Circle())
            }
            .buttonStyle(TilePressStyle())
            .accessibilityLabel("Remove \(url.lastPathComponent) from shelf")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tile.surface.chipFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .draggable(url)
    }

    private var dropZone: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return Text("Drop more here")
            .font(tile.font(.body).weight(.semibold))
            .foregroundStyle(Palette.progress)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Palette.progress.opacity(isTargeted ? 0.18 : 0.06), in: shape)
            .overlay(shape.strokeBorder(Palette.progress.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])))
            .modifier(DropTarget(isTargeted: $isTargeted, onDrop: list.onDrop))
            .tileAnimation(Motion.press, value: isTargeted)
    }
}

/// Accepts dropped files. Skipped in gallery snapshots, where ImageRenderer draws the AppKit drop view as a placeholder.
private struct DropTarget: ViewModifier {
    @Environment(\.surfaceSnapshot) private var snapshot
    @Binding var isTargeted: Bool
    let onDrop: ([URL]) -> Void

    func body(content: Content) -> some View {
        if snapshot != nil {
            content
        } else {
            content.dropDestination(for: URL.self) { urls, _ in
                onDrop(urls.filter(\.isFileURL))
                return true
            } isTargeted: { isTargeted = $0 }
        }
    }
}
