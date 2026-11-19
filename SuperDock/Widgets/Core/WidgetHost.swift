import SwiftUI

/// Bar shape, set by BarController from the Dock's geometry.
@MainActor @Observable
final class BarModel {
    var isVertical = false
    var thickness: CGFloat = 85
    /// False while the bar is hidden, the screen is locked or the displays sleep. Tiles are unmounted then,
    /// which unsubscribes them from every service, so a hidden bar does no work at all.
    var isActive = true
}

/// Lays out the tiles inside the bar panel.
struct WidgetHost: View {
    let store: LayoutStore
    let bar: BarModel
    @Environment(\.openSettings) private var openSettings

    private var spacing: CGFloat { BarPlacement.tileSpacing }
    private var unit: CGFloat { BarPlacement.tileUnit(thickness: bar.thickness) }

    var body: some View {
        let stack = bar.isVertical ? AnyLayout(VStackLayout(spacing: spacing)) : AnyLayout(HStackLayout(spacing: spacing))
        stack {
            ForEach(bar.isActive ? store.tiles : []) { tile in
                TileView(tile: tile, frame: frame(for: tile.size))
                    .contextMenu { menu(for: tile) }
                    .draggable(tile.id.uuidString)
                    .dropDestination(for: String.self) { ids, _ in
                        guard let id = ids.first.flatMap(UUID.init(uuidString:)) else { return false }
                        store.move(id, to: tile.id)
                        return true
                    }
            }
            if store.tiles.isEmpty {
                Button(action: openWidgetSettings) {
                    Image(systemName: "plus").font(.title2).frame(width: unit, height: unit)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Widget")
            }
        }
        .padding(spacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func frame(for size: TileSize) -> CGSize {
        let length = CGFloat(size.columns) * unit + CGFloat(size.columns - 1) * spacing
        return bar.isVertical ? CGSize(width: unit, height: length) : CGSize(width: length, height: unit)
    }

    @ViewBuilder
    private func menu(for tile: Tile) -> some View {
        if let widget = WidgetRegistry.widget(tile.widgetId), widget.supportedSizes.count > 1 {
            Picker("Size", selection: Binding(get: { tile.size }, set: { store.setSize($0, for: tile.id) })) {
                ForEach(widget.supportedSizes) { Text($0.title).tag($0) }
            }
        }
        Button("Widget Settings…", action: openWidgetSettings)
        Button("Add Widget…", action: openWidgetSettings)
        Divider()
        Button("Remove", role: .destructive) { store.remove(tile.id) }
    }

    private func openWidgetSettings() {
        UserDefaults.standard.set(SettingsTab.widgets.rawValue, forKey: SettingsTab.storageKey)
        // Agent apps are never frontmost, so without this the window opens behind other apps.
        NSApp.activate()
        openSettings()
    }
}

private struct TileView: View {
    let tile: Tile
    let frame: CGSize

    var body: some View {
        Group {
            if let widget = WidgetRegistry.widget(tile.widgetId) {
                widget.tileView(size: tile.size, settings: tile.settings)
            } else {
                // Saved layout names a widget this build doesn't have; keep it so a later version can show it again.
                Image(systemName: "questionmark.square.dashed")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Unknown widget")
            }
        }
        .padding(6)
        .frame(width: frame.width, height: frame.height)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
