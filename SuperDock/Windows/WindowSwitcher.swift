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

    private static let maxColumns = 6
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
        panel.show(SwitcherView(model: model, columns: min(windows.count, Self.maxColumns),
                                frozen: WindowService.shared.frozen) { [weak self] index in
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

private struct SwitcherView: View {
    let model: WindowSwitcher.Model
    let columns: Int
    let frozen: Set<pid_t>
    let onPick: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(176), spacing: 8), count: columns), spacing: 8) {
            ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                WindowCard(window: window, isSelected: index == model.selection, isFrozen: frozen.contains(window.pid),
                           thumbnailHeight: 120) { onPick(index) }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
