import SwiftUI

/// Settings → Widgets: the current bar as a mini strip (select a tile to resize, configure, move or remove it),
/// then the gallery of every widget.
struct WidgetsSettings: View {
    @Bindable private var store = LayoutStore.shared
    @State private var search = ""
    @State private var selection: Tile.ID?

    /// `selection` opens with a bar tile already selected (the gallery uses it to draw the inspector).
    init(selection: Tile.ID? = nil) {
        _selection = State(initialValue: selection)
    }

    var body: some View {
        SettingsPane(title: "Widgets",
                     subtitle: "Click Add to put a widget on the bar, or a tile in your bar to edit it.") {
            SearchField(text: $search, prompt: "Search \(WidgetRegistry.all.count) widgets")
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    YourBarStrip(tiles: store.tiles, selection: $selection) { store.move($0, to: $1) }
                    if let tile = store.tiles.first(where: { $0.id == selection }) {
                        TileInspector(tile: binding(for: tile), store: store) { selection = nil }
                    }
                    WidgetPicker(search: search) { widget, size in
                        store.add(widget.id, size: size)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }

    /// By id, not index: a move or remove on the bar while the inspector is open must not edit a different tile.
    private func binding(for tile: Tile) -> Binding<Tile> {
        Binding(get: { store.tiles.first { $0.id == tile.id } ?? tile },
                set: { new in
                    guard let index = store.tiles.firstIndex(where: { $0.id == tile.id }) else { return }
                    store.tiles[index] = new
                })
    }
}

private struct SearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField(prompt, text: $text).textFieldStyle(.plain)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(width: 250, height: 30)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(nsColor: .separatorColor)) }
    }
}

/// "Your bar": every tile as a category-coloured chip, as wide as its column count. Drag to reorder.
private struct YourBarStrip: View {
    let tiles: [Tile]
    @Binding var selection: Tile.ID?
    let move: (Tile.ID, Tile.ID) -> Void

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Your bar").font(.system(size: 11, weight: .bold)).tracking(1)
                Text("\(tiles.count) tiles").font(.system(size: 10, weight: .semibold)).tracking(1).opacity(0.75)
            }
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .fixedSize()
            if tiles.isEmpty {
                Text("Nothing here yet. Add a widget below.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(tiles) { tile in
                            chip(tile)
                        }
                    }
                    .padding(4)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white.opacity(0.28))
                    }
                    .padding(.vertical, 2)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
        .background(Self.wallpaper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func chip(_ tile: Tile) -> some View {
        let widget = WidgetRegistry.widget(tile.widgetId)
        let tint = widget?.category.pickerTint ?? Palette.idle
        let isSelected = tile.id == selection
        return Button {
            selection = isSelected ? nil : tile.id
        } label: {
            HStack(spacing: 4) {
                Image(systemName: widget?.category.pickerSymbol ?? "questionmark.square.dashed")
                    .font(.system(size: 9.5, weight: .bold))
                if tile.size != .compact {
                    Text(widget?.name ?? tile.widgetId).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, tile.size == .compact ? 0 : 7)
            .frame(width: CGFloat(tile.size.columns) * 28 + CGFloat(tile.size.columns - 1) * 14, height: 26,
                   alignment: tile.size == .compact ? .center : .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.white, lineWidth: isSelected ? 2 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(widget?.name ?? tile.widgetId)
        .accessibilityLabel("\(widget?.name ?? tile.widgetId), \(tile.size.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .draggable(tile.id.uuidString)
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first.flatMap(UUID.init(uuidString:)) else { return false }
            move(id, tile.id)
            return true
        }
    }

    /// Coral glow into navy into violet, from mockup 07.
    private static let wallpaper = LinearGradient(
        stops: [.init(color: Color(rgb: 0x6B2C5E), location: 0), .init(color: Color(rgb: 0xE0566A), location: 0.22),
                .init(color: Color(rgb: 0x1F2B4D), location: 0.5), .init(color: Color(rgb: 0x3E3F9E), location: 0.75),
                .init(color: Color(rgb: 0x7A5CF0), location: 1)],
        startPoint: .leading, endPoint: .trailing)
}

/// The selected bar tile: live preview, size, the widget's own settings, move and remove.
private struct TileInspector: View {
    @Binding var tile: Tile
    let store: LayoutStore
    let close: () -> Void

    var body: some View {
        let widget = WidgetRegistry.widget(tile.widgetId)
        let index = store.tiles.firstIndex { $0.id == tile.id } ?? 0
        HStack(alignment: .top, spacing: 16) {
            PreviewBar(tiles: [PreviewTile(tile)])
                .frame(width: 300, height: 96)
                .background(PreviewWallpaper())
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(widget?.name ?? tile.widgetId).font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Button(action: close) { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Close")
                }
                if let widget, widget.supportedSizes.count > 1 {
                    Picker("Size", selection: $tile.size) {
                        ForEach(widget.supportedSizes) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                if let editor = widget?.settingsEditor($tile.settings) {
                    editor
                }
                HStack {
                    Button { store.move(tile.id, to: store.tiles[index - 1].id) } label: {
                        Label("Move Left", systemImage: "chevron.left")
                    }
                    .disabled(index == 0)
                    Button { store.move(tile.id, to: store.tiles[index + 1].id) } label: {
                        Label("Move Right", systemImage: "chevron.right")
                    }
                    .disabled(index >= store.tiles.count - 1)
                    Spacer()
                    Button("Remove", role: .destructive) {
                        close()
                        store.remove(tile.id)
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(nsColor: .separatorColor).opacity(0.6))
        }
    }
}
