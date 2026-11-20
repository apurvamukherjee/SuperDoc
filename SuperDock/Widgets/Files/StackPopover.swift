import AppKit
import SwiftUI

/// The Folder / Smart Stack popover. Owned by the around-the-bar surfaces; the tile lives in StackWidget.swift.
struct StackPopover: View {
    let title: String
    let items: [URL]
    let style: StackWidget.Style
    let folder: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let folder { Button("Open in Finder") { NSWorkspace.shared.open(folder) }.controlSize(.small) }
            }
            if items.isEmpty {
                Text("Nothing here yet").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80)
            } else if style == .grid {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(76)), count: 4), spacing: 10) {
                    ForEach(items, id: \.self) { item(url: $0, compact: false) }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(items, id: \.self) { item(url: $0, compact: true) }
                }
                .frame(width: 300)
            }
        }
        .padding(12)
    }

    /// Click opens; drag carries the real file to other apps.
    private func item(url: URL, compact: Bool) -> some View {
        let icon = Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().scaledToFit()
        let name = Text(url.lastPathComponent).lineLimit(compact ? 1 : 2).truncationMode(.middle)
        return Button { NSWorkspace.shared.open(url) } label: {
            if compact {
                HStack { icon.frame(width: 20, height: 20); name.font(.callout) }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 4) { icon.frame(width: 48, height: 48); name.font(.caption2).multilineTextAlignment(.center) }
            }
        }
        .buttonStyle(.plain)
        .draggable(url)
        .help(url.path)
    }
}
