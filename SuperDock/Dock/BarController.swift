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
    /// With auto-hide, moving from the Dock onto the bar makes macOS hide the Dock. The bar stays put while the
    /// pointer, its right-click menu or one of its popovers is on it, and tucks away once all three are gone.
    private var isHovered = false
    private var menuIsOpen = false
    private var holdObservers: [NSObjectProtocol] = []
    private var releaseTask: Task<Void, Never>?
    private var isHeld: Bool { isHovered || menuIsOpen || !(panel.childWindows ?? []).isEmpty }

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
        observeHold()
        // Wait one run-loop turn: sizing the bar's hosting view inside applicationDidFinishLaunching trips a SwiftUI
        // exclusivity crash (macOS 26) whenever the Dock is already visible at launch.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.tracker.start()
            // The tracker only reports changes; in replacement mode the Dock starts (and stays) hidden, so lay out once now.
            self.layout()
        }
    }

    private func observeHold() {
        panel.onHoverChange = { [weak self] hovering in
            self?.isHovered = hovering
            self?.holdChanged()
        }
        let center = NotificationCenter.default
        let watch = { [weak self] (name: Notification.Name, change: @escaping @MainActor (BarController) -> Void) in
            guard let self else { return }
            holdObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    change(self)
                    self.holdChanged()
                }
            })
        }
        watch(NSMenu.didBeginTrackingNotification) { $0.menuIsOpen = true }
        watch(NSMenu.didEndTrackingNotification) { $0.menuIsOpen = false }
        watch(NSPopover.didCloseNotification) { _ in }
    }

    /// Releasing waits a beat: crossing the gap between Dock and bar, or a popover closing as the pointer comes back,
    /// shouldn't make the bar dip.
    private func holdChanged() {
        releaseTask?.cancel()
        guard !isHeld else { return }
        releaseTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }   // cancelled by a newer change
            self?.layout()
        }
    }

    /// Slides the bar off the screen edge it shares with the hidden Dock, then hides it.
    private func tuckAway() {
        guard panel.isVisible else { return }
        let screen = (panel.screen ?? NSScreen.main)?.frame ?? panel.frame
        var away = panel.frame
        if bar.isVertical {
            away.origin.x += panel.frame.midX < screen.midX ? -(away.width + 12) : away.width + 12
        } else {
            away.origin.y -= away.height + 12
        }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = reduceMotion ? 0.15 : 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            if reduceMotion { panel.animator().alphaValue = 0 } else { panel.animator().setFrame(away, display: true) }
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isHeld, self.tracker.dock == nil else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
                self.updateActivity()
            }
        })
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

    /// An empty bar still shows its two-column "Add widgets" invitation.
    private var tileColumns: Int { store.tiles.isEmpty ? TileSize.medium.columns : store.totalColumns }

    private func layout() {
        if DockReplacement.isEnabled { return layoutAsDock() }
        if bar.showsAppStrip { bar.showsAppStrip = false }
        guard let dock = tracker.dock else {
            // Held means the pointer just came over from the Dock; macOS hid the Dock, the bar keeps its place.
            if isHeld { return }
            tuckAway()
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
            length: BarPlacement.barLength(columns: tileColumns, thickness: thickness)
        )
        // While held, don't ride the Dock's hide slide off the screen.
        let onScreen = NSScreen.screens.contains { $0.frame.contains(frame) }
        if isHeld, panel.isVisible, !onScreen { return }
        panel.alphaValue = 1
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
        let columns = tileColumns + AppStrip.shared.items.count + 1   // + Trash
        let length = BarPlacement.barLength(columns: columns, thickness: thickness) + separator
        panel.setFrame(NSRect(x: screen.frame.midX - length / 2, y: screen.frame.minY + 4, width: length, height: thickness),
                       display: true)
        if !panel.isVisible { panel.orderFrontRegardless() }
        updateActivity()
    }
}
