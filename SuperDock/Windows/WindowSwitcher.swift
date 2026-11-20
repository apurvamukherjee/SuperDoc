import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Option-Tab window switcher: hold Option, tap Tab (Shift-Tab backwards) to cycle, release Option to switch, Esc cancels.
@MainActor
final class WindowSwitcher {
    @MainActor @Observable
    final class Model {
        var windows: [WindowInfo] = []
        var selection = 0
    }

    private let panel = OverlayPanel()
    private let model = Model()
    private var releaseTimer: Timer?
    private var escapeHotKey: UInt32?

    var currentSpaceOnly = false

    /// Called by the Option-Tab / Option-Shift-Tab hotkeys.
    func advance(backwards: Bool) {
        if panel.isVisible {
            model.selection = WindowRules.step(model.selection, by: backwards ? -1 : 1, count: model.windows.count)
        } else {
            open(backwards: backwards)
        }
    }

    private func open(backwards: Bool) {
        let windows = WindowService.shared.windows(currentSpaceOnly: currentSpaceOnly)
        guard !windows.isEmpty else { return }
        model.windows = windows
        // Like Cmd-Tab: the first press lands on the previous window, not the current one.
        model.selection = WindowRules.step(0, by: backwards ? -1 : 1, count: windows.count)

        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? .zero
        panel.show(SwitcherView(model: model, frozen: WindowService.shared.frozen) { [weak self] index in
            self?.model.selection = index
            self?.commit()
        }) { size in
            NSPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2)
        }
        Task { await ThumbnailService.shared.load(windows.map(\.id)) }

        // The panel never takes keyboard focus, so watch for Option being released instead of waiting for a key-up.
        releaseTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard !CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate) else { return }
                self?.commit()
            }
        }
        escapeHotKey = HotKeys.shared.register(.init(keyCode: kVK_Escape, modifiers: optionKey)) { [weak self] in self?.close() }
    }

    private func commit() {
        let window = model.windows.indices.contains(model.selection) ? model.windows[model.selection] : nil
        close()
        if let window { WindowService.shared.focus(window) }
    }

    private func close() {
        releaseTimer?.invalidate()
        releaseTimer = nil
        if let escapeHotKey { HotKeys.shared.unregister(escapeHotKey) }
        escapeHotKey = nil
        panel.orderOut(nil)
    }
}

/// The switcher panel: this Space's windows first, then a divider, then windows elsewhere (other Spaces, minimized).
struct SwitcherView: View {
    let model: WindowSwitcher.Model
    let frozen: Set<pid_t>
    var fixtureImages: WindowImages?
    let onPick: (Int) -> Void

    var body: some View {
        // `.live` is read here, inside body, so thumbnails fill in as ThumbnailService captures them.
        SwitcherContent(model: model, frozen: frozen, images: fixtureImages ?? .live, onPick: onPick).surfaceContext()
    }
}

private struct SwitcherContent: View {
    @Environment(\.tile) private var tile
    let model: WindowSwitcher.Model
    let frozen: Set<pid_t>
    let images: WindowImages
    let onPick: (Int) -> Void

    private static let maxColumns = 6
    private static let thumb = CGSize(width: 150, height: 88)
    private static let spacing: CGFloat = 14

    var body: some View {
        let count = model.windows.count
        let split = model.windows.firstIndex { !$0.isOnScreen } ?? count
        let divides = split > 0 && split < count
        Group {
            if count <= Self.maxColumns {
                HStack(alignment: .top, spacing: Self.spacing) {
                    cards(0..<split)
                    if divides { Rectangle().fill(tile.surface.divider).frame(width: 1, height: Self.thumb.height + 30) }
                    cards(split..<count)
                }
            } else {
                VStack(spacing: Self.spacing) {
                    grid(0..<split)
                    if divides { Rectangle().fill(tile.surface.divider).frame(height: 1) }
                    grid(split..<count)
                }
            }
        }
        .padding(18)
        .surfacePanel(radius: 26)
        .surfacePop(from: 0.94)
    }

    private func cards(_ range: Range<Int>) -> some View {
        ForEach(range, id: \.self) { card($0) }
    }

    private func grid(_ range: Range<Int>) -> some View {
        let columns = Array(repeating: GridItem(.fixed(Self.thumb.width + Self.spacing), spacing: Self.spacing), count: Self.maxColumns)
        return LazyVGrid(columns: columns, spacing: Self.spacing) { cards(range) }
    }

    private func card(_ index: Int) -> some View {
        let window = model.windows[index]
        let selected = index == model.selection
        return VStack(spacing: 8) {
            WindowThumb(window: window, images: images, isSelected: selected, size: Self.thumb) { onPick(index) }
            HStack(spacing: 6) {
                if frozen.contains(window.pid) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.hot)
                        .accessibilityLabel("Not responding")
                } else if window.isOnScreen, let icon = images.icon(window) {
                    Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                }
                Text(selected && window.title != window.appName ? "\(window.appName) — \(window.title)" : window.appName)
                    .font(tile.font(.body).weight(selected ? .bold : .medium))
                    .foregroundStyle(selected || window.isOnScreen ? tile.surface.primary : tile.surface.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(width: Self.thumb.width + Self.spacing)
        }
        .help(window.title)
    }
}
