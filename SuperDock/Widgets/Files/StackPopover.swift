import AppKit
import SwiftUI

/// The Folder / Smart Stack popover. Owned by the around-the-bar surfaces; the tile lives in StackWidget.swift.
/// NSPopover draws the material, so this is content only.
struct StackPopover: View {
    let title: String
    let items: [URL]
    let style: StackWidget.Style
    let folder: URL?

    var body: some View {
        StackContent(popover: self).surfaceContext()
    }
}

private struct StackContent: View {
    @Environment(\.tile) private var tile
    let popover: StackPopover

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(popover.title).tileStyle(.value)
                Spacer()
                if let folder = popover.folder {
                    Button { NSWorkspace.shared.open(folder) } label: {
                        Text("Open in Finder ›").tileStyle(.detail)
                    }
                    .buttonStyle(.plain)
                }
            }
            if popover.items.isEmpty {
                VStack(spacing: 8) {
                    LimoFace().frame(width: 36, height: 36)
                    Text("Nothing here yet").tileStyle(.detail)
                }
                .frame(width: 300, height: 110)
            } else if popover.style == .grid {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(96), spacing: 10), count: 4), spacing: 12) {
                    ForEach(popover.items, id: \.self) { item(url: $0, compact: false) }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(popover.items, id: \.self) { item(url: $0, compact: true) }
                }
                .frame(width: 300)
            }
        }
        .padding(14)
    }

    /// Click opens; drag carries the real file to other apps.
    private func item(url: URL, compact: Bool) -> some View {
        let icon = Image(nsImage: SurfaceKit.icon(for: url)).resizable().scaledToFit()
        let name = url.deletingPathExtension().lastPathComponent
        return Button { NSWorkspace.shared.open(url) } label: {
            if compact {
                HStack(spacing: 8) {
                    icon.frame(width: 20, height: 20)
                    Text(name).tileStyle(.body).lineLimit(1).truncationMode(.middle)
                }
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            } else {
                VStack(spacing: 5) {
                    icon.frame(width: 48, height: 48)
                    Text(name).font(tile.font(.detail).weight(.medium)).foregroundStyle(tile.surface.primary)
                        .lineLimit(2).truncationMode(.middle).multilineTextAlignment(.center)
                }
                .frame(width: 96)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(TilePressStyle())
        .draggable(url)
        .help(url.path)
    }
}
