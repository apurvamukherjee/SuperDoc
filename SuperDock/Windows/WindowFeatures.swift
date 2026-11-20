import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Window feature settings, shared by Settings (@AppStorage) and WindowFeatures.
enum WindowPrefs {
    static let switcherKey = "windows.switcher"
    static let currentSpaceOnlyKey = "windows.currentSpaceOnly"
    static let previewsKey = "windows.dockPreviews"
    static let dockNumbersKey = "windows.dockNumbers"
    static let frozenKey = "windows.frozenAlerts"

    static func bool(_ key: String, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? value
    }
}

/// Turns window features on and off as settings change.
@MainActor
final class WindowFeatures {
    private let switcher = WindowSwitcher()
    private let previews: DockHoverPreviews
    private let frozen = FrozenAppMonitor()
    private var switcherHotKeys: [UInt32] = []
    private var numberHotKeys: [UInt32] = []
    private var defaultsObserver: NSObjectProtocol?
    private let hudPanel = OverlayPanel()
    private var hudTask: Task<Void, Never>?

    // Carbon key codes for 1–9 aren't sequential.
    private static let digitKeys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                                    kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]

    init(tracker: NativeDockTracker, alerts: LimoController, anchor: @escaping () -> NSRect?) {
        previews = DockHoverPreviews(tracker: tracker)
        hudPanel.ignoresMouseEvents = true
        frozen.onFrozen = { app in
            alerts.show(message: String(localized: "\(app.localizedName ?? "An app") is frozen"),
                        symbol: "exclamationmark.triangle.fill", color: Palette.hot,
                        action: (String(localized: "Force Quit"), { app.forceTerminate() }),
                        above: anchor(),
                        detail: String(localized: "\(FrozenAppMonitor.secondsUnresponsive)s, not responding"))
        }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        }
        sync()
    }

    private func sync() {
        switcher.currentSpaceOnly = WindowPrefs.bool(WindowPrefs.currentSpaceOnlyKey, default: false)
        // Previews need Screen Recording; Settings only turns them on after asking for it.
        previews.isEnabled = WindowPrefs.bool(WindowPrefs.previewsKey, default: false)
        frozen.isEnabled = WindowPrefs.bool(WindowPrefs.frozenKey, default: true)

        let wantsSwitcher = WindowPrefs.bool(WindowPrefs.switcherKey, default: true)
        if wantsSwitcher, switcherHotKeys.isEmpty {
            switcherHotKeys = [
                HotKeys.shared.register(.init(keyCode: kVK_Tab, modifiers: optionKey)) { [weak self] in
                    self?.switcher.advance(backwards: false)
                },
                HotKeys.shared.register(.init(keyCode: kVK_Tab, modifiers: optionKey | shiftKey)) { [weak self] in
                    self?.switcher.advance(backwards: true)
                }
            ].compactMap { $0 }
        } else if !wantsSwitcher {
            switcherHotKeys.forEach(HotKeys.shared.unregister)
            switcherHotKeys = []
        }

        let wantsNumbers = WindowPrefs.bool(WindowPrefs.dockNumbersKey, default: true)
        if wantsNumbers, numberHotKeys.isEmpty {
            numberHotKeys = Self.digitKeys.enumerated().compactMap { index, key in
                HotKeys.shared.register(.init(keyCode: key, modifiers: controlKey | optionKey)) { [weak self] in
                    self?.openDockApp(at: index)
                }
            }
        } else if !wantsNumbers {
            numberHotKeys.forEach(HotKeys.shared.unregister)
            numberHotKeys = []
        }
    }

    /// Ctrl-Opt-N: launches or switches to the Nth app icon in the native Dock, with a brief HUD saying which.
    private func openDockApp(at index: Int) {
        guard let (_, list) = AX.dockList() else { return }
        let apps = AX.children(of: list).filter { AX.subrole(of: $0) == "AXApplicationDockItem" }
        guard apps.indices.contains(index), let url = AX.url(of: apps[index]) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        showHUD(DockNumberHUD(number: index + 1, name: name, icon: IconProvider.icon(for: url)))
    }

    private func showHUD(_ hud: DockNumberHUD) {
        let area = (NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main)?.visibleFrame ?? .zero
        // Lower third, clear of the Dock, like the system's volume HUD.
        hudPanel.show(hud) { size in NSPoint(x: area.midX - size.width / 2, y: area.minY + area.height * 0.18) }
        hudTask?.cancel()
        hudTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(900))
            } catch {
                return   // a newer press replaced this HUD
            }
            self?.hudPanel.orderOut(nil)
        }
    }
}

/// ⌃⌥N confirmation: the app's icon and "3 · Terminal".
struct DockNumberHUD: View {
    let number: Int
    let name: String
    let icon: NSImage

    var body: some View {
        HUDContent(hud: self).surfaceContext()
    }
}

private struct HUDContent: View {
    let hud: DockNumberHUD

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: hud.icon).resizable().frame(width: 60, height: 60)
            Text("\(hud.number) · \(hud.name)").tileStyle(.title)
        }
        .frame(width: 132, height: 120)
        .surfacePanel(radius: 26)
        .surfacePop(from: 0.85)
        .accessibilityElement(children: .combine)
    }
}
