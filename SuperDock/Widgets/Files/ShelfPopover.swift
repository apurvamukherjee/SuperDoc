import AppKit
import SwiftUI

/// The File Shelf popover. Owned by the around-the-bar surfaces; the tile lives in FileShelfWidget.swift.
struct ShelfList: View {
    let shelf: FileShelf

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Shelf").font(.headline)
                Spacer()
                Button("Clear") { shelf.clear() }.controlSize(.small)
            }
            Text("Drag files out to use them.").font(.caption).foregroundStyle(.secondary)
            ForEach(shelf.files, id: \.self) { url in
                HStack {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 20, height: 20)
                    Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button { shelf.remove(url) } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .accessibilityLabel("Remove \(url.lastPathComponent) from shelf")
                }
                .draggable(url)
            }
        }
        .padding(12)
        .frame(width: 300)
    }
}
