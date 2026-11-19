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
    private let buddy: BuddyController
    private var buddyIsListening = false
    private var screenUnavailable = false   // locked or displays asleep
    private var powerObservers: [NSObjectProtocol] = []

    /// The bar's frame while it's on screen, for anchoring alerts.
    var visibleFrame: NSRect? { panel.isVisible ? panel.frame : nil }

    init(tracker: NativeDockTracker, buddy: BuddyController) {
        self.tracker = tracker
        self.buddy = buddy
        panel = BarPanel(content: WidgetHost(store: store, bar: bar))
        StickySpace.add(panel)
        tracker.onChange = { [weak self] _ in self?.layout() }
        store.onChange = { [weak self] in self?.layout() }
        AgentSessionService.shared.onAlert = { [weak self] session in
            guard let self else { return }
            buddy.show(session, above: panel.isVisible ? panel.frame : nil)
        }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.layout()
                self?.updateBuddy()
            }
        }
        updateBuddy()
        observeLockAndSleep()
        tracker.start()
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

    /// Buddy needs agent status even when no board tile is on the bar, so it holds its own subscription.
    private func updateBuddy() {
        let enabled = UserDefaults.standard.object(forKey: BuddyController.enabledKey) as? Bool ?? true
        guard enabled != buddyIsListening else { return }
        buddyIsListening = enabled
        if enabled { AgentSessionService.shared.subscribe() } else { AgentSessionService.shared.unsubscribe() }
    }

    private func layout() {
        guard let dock = tracker.dock else {
            panel.orderOut(nil)
            updateActivity()
            return
        }
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
}
