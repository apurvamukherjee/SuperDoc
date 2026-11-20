import AppKit

/// Bar settings in UserDefaults, shared by the Settings UI (@AppStorage) and BarController.
enum BarPrefs {
    static let positionKey = "bar.position"
    static let gapKey = "bar.gap"
    static let defaultPosition = BarPosition.trailing
    static let defaultGap = 8.0

    static var position: BarPosition {
        UserDefaults.standard.string(forKey: positionKey).flatMap(BarPosition.init) ?? defaultPosition
    }
    static var gap: Double {
        UserDefaults.standard.object(forKey: gapKey) as? Double ?? defaultGap
    }
}

/// Keeps the bar panel next to the native Dock.
@MainActor
final class BarController {
    private let store = LayoutStore.shared
    private let bar = BarModel()
    private let panel: BarPanel
    private let tracker: NativeDockTracker
    private var defaultsObserver: NSObjectProtocol?
    private let limo: LimoController
    private var limoIsListening = false
    private var screenUnavailable = false   // locked or displays asleep
    private var powerObservers: [NSObjectProtocol] = []

    /// The bar's frame while it's on screen, for anchoring alerts.
    var visibleFrame: NSRect? { panel.isVisible ? panel.frame : nil }

    init(tracker: NativeDockTracker, limo: LimoController) {
        self.tracker = tracker
        self.limo = limo
        panel = BarPanel(content: WidgetHost(store: store, bar: bar))
        StickySpace.add(panel)
        tracker.onChange = { [weak self] _ in self?.layout() }
        store.onChange = { [weak self] in self?.layout() }
        AgentSessionService.shared.onAlert = { [weak self] session in
            guard let self else { return }
            limo.show(session, above: panel.isVisible ? panel.frame : nil)
        }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.panel.applyAppearance()
                self?.layout()
                self?.updateLimo()
            }
        }
        updateLimo()
        observeLockAndSleep()
        // Wait one run-loop turn: sizing the bar's hosting view inside applicationDidFinishLaunching trips a SwiftUI
        // exclusivity crash (macOS 26) whenever the Dock is already visible at launch.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.tracker.start()
            // The tracker only reports changes; in replacement mode the Dock starts (and stays) hidden, so lay out once now.
            self.layout()
        }
    }

    /// Nothing on the bar should tick while nobody can see it (SUPERDOCK.md §10).
    private func observeLockAndSleep() {
        let distributed = DistributedNotificationCenter.default()
        let workspace = NSWorkspace.shared.notificationCenter
        watch(distributed, .init("com.apple.screenIsLocked"), unavailable: true)
        watch(distributed, .init("com.apple.screenIsUnlocked"), unavailable: false)
        watch(workspace, NSWorkspace.screensDidSleepNotification, unavailable: true)
        watch(workspace, NSWorkspace.screensDidWakeNotification, unavailable: false)
    }

    private func watch(_ center: NotificationCenter, _ name: Notification.Name, unavailable: Bool) {
        powerObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.screenUnavailable = unavailable
                self?.updateActivity()
            }
        })
    }

    private func updateActivity() {
        let active = panel.isVisible && !screenUnavailable
        if bar.isActive != active { bar.isActive = active }
    }

    /// Limo needs agent status even when no board tile is on the bar, so it holds its own subscription.
    private func updateLimo() {
        let enabled = UserDefaults.standard.object(forKey: LimoController.enabledKey) as? Bool ?? true
        guard enabled != limoIsListening else { return }
        limoIsListening = enabled
        if enabled { AgentSessionService.shared.subscribe() } else { AgentSessionService.shared.unsubscribe() }
    }

    private func layout() {
        if DockReplacement.isEnabled { return layoutAsDock() }
        if bar.showsAppStrip { bar.showsAppStrip = false }
        guard let dock = tracker.dock else {
            panel.orderOut(nil)
            updateActivity()
            return
        }
        // Built-in and external displays each have their own active profile.
        let screen = NSScreen.screens.first { $0.visibleFrame == dock.visibleFrame }
        let displayID = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        let kind: DisplayKind = displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? true ? .builtIn : .external
        if store.display != kind { store.display = kind }

        let isVertical = BarPlacement.orientation(of: dock.frame, in: dock.visibleFrame) != .bottom
        let thickness = isVertical ? dock.frame.width : dock.frame.height
        // Only assign on change: layout runs at 60 Hz while the Dock animates, and each assignment re-renders the tiles.
        if bar.isVertical != isVertical { bar.isVertical = isVertical }
        if bar.thickness != thickness { bar.thickness = thickness }

        let frame = BarPlacement.barFrame(
            dock: dock.frame, bounds: dock.visibleFrame,
            position: BarPrefs.position, gap: BarPrefs.gap,
            length: BarPlacement.barLength(columns: store.totalColumns, thickness: thickness)
        )
        panel.setFrame(frame, display: true)
        if !panel.isVisible { panel.orderFrontRegardless() }
        updateActivity()
    }

    // ponytail: bottom of the main screen only; side positions and multi-display placement come later if wanted.
    /// Replacement mode: the system Dock is hidden, so the bar takes its place, centred at the bottom of the main
    /// screen with the app strip first.
    private func layoutAsDock() {
        guard let screen = NSScreen.screens.first else { return }
        AppStrip.shared.onChange = { [weak self] in self?.layout() }
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        let kind: DisplayKind = displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? true ? .builtIn : .external
        if store.display != kind { store.display = kind }

        // Icons match the size the user chose for the system Dock.
        let iconSize = (SystemDockPrefs().value("tilesize") as? Double).map { CGFloat($0) } ?? 48
        let thickness = iconSize + 2 * BarPlacement.tileSpacing
        if bar.isVertical { bar.isVertical = false }
        if bar.thickness != thickness { bar.thickness = thickness }
        if !bar.showsAppStrip { bar.showsAppStrip = true }

        let separator: CGFloat = 1 + BarPlacement.tileSpacing
        let columns = store.totalColumns + AppStrip.shared.items.count + 1   // + Trash
        let length = BarPlacement.barLength(columns: columns, thickness: thickness) + separator
        panel.setFrame(NSRect(x: screen.frame.midX - length / 2, y: screen.frame.minY + 4, width: length, height: thickness),
                       display: true)
        if !panel.isVisible { panel.orderFrontRegardless() }
        updateActivity()
    }
}
