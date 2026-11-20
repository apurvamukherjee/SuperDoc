import SwiftUI

/// Bar shape, set by BarController from the Dock's geometry.
@MainActor @Observable
final class BarModel {
    var isVertical = false
    var thickness: CGFloat = 85
    /// False while the bar is hidden, the screen is locked or the displays sleep. Tiles are unmounted then,
    /// which unsubscribes them from every service, so a hidden bar does no work at all.
    var isActive = true
    /// Dock replacement mode: the bar starts with SuperDock's own app strip.
    var showsAppStrip = false
}

/// The live bar: turns prefs, the system's mode and the layout store into a `BarLayout`.
/// Tiles get everything through `\.tile`, so nothing below here reads prefs.
struct WidgetHost: View {
    let store: LayoutStore
    let bar: BarModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(AppearancePrefs.styleKey) private var style = BarStyle.glass
    @AppStorage(AppearancePrefs.accentKey) private var accent = ""
    @AppStorage(AppearancePrefs.tileBackgroundsKey) private var tileBackgrounds = true
    @AppStorage(AppearancePrefs.cornerRadiusKey) private var cornerRadius = AppearancePrefs.defaultCornerRadius
    @State private var isDropTargeted = false

    var body: some View {
        if bar.isActive {
            BarLayout(context: context, items: store.tiles.map(item), appStrip: bar.showsAppStrip ? AppStrip.shared.items : nil,
                      actions: actions, isDropTargeted: isDropTargeted)
                // Widget cards dragged from Settings carry their widget id.
                .dropDestination(for: String.self) { ids, _ in
                    ids.contains(where: add)
                } isTargeted: { isDropTargeted = $0 }
                // The panel can become key (for text fields), which would otherwise draw focus rings around tile buttons.
                .focusEffectDisabled()
        }
    }

    private var context: TileContext {
        .bar(surface: .bar(style, isDark: colorScheme == .dark, reduceTransparency: reduceTransparency,
                           tileBackgrounds: tileBackgrounds),
             accent: Color(hex: accent) ?? .accentColor, cornerRadius: cornerRadius, thickness: bar.thickness,
             isVertical: bar.isVertical)
    }

    private func item(_ tile: Tile) -> BarItem {
        guard let widget = WidgetRegistry.widget(tile.widgetId) else {
            // Saved layout names a widget this build doesn't have; keep it so a later version can show it again.
            return BarItem(id: tile.id, size: tile.size, name: String(localized: "Unknown widget"), supportedSizes: [tile.size],
                           view: AnyView(UnknownWidgetTile()))
        }
        return BarItem(id: tile.id, size: tile.size, name: widget.name, supportedSizes: widget.supportedSizes,
                       view: widget.tileView(size: tile.size, settings: tile.settings))
    }

    private var actions: BarActions {
        BarActions(
            move: { store.move($0, to: $1) },
            setSize: { store.setSize($0, for: $1) },
            remove: { store.remove($0) },
            openWidgets: openWidgetSettings
        )
    }

    private func add(_ widgetId: String) -> Bool {
        guard let size = WidgetRegistry.widget(widgetId)?.supportedSizes.first else { return false }
        store.add(widgetId, size: size)
        return true
    }

    private func openWidgetSettings() {
        UserDefaults.standard.set(SettingsTab.widgets.rawValue, forKey: SettingsTab.storageKey)
        // Agent apps are never frontmost, so without this the window opens behind other apps.
        NSApp.activate()
        openSettings()
    }
}

private struct UnknownWidgetTile: View {
    @Environment(\.tile) private var tile

    var body: some View {
        Image(systemName: "questionmark.square.dashed")
            .font(.system(size: 22 * tile.scale))
            .foregroundStyle(tile.surface.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Unknown widget")
    }
}
