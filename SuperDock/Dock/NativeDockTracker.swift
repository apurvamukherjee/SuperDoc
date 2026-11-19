import AppKit

/// Finds the native Dock through Accessibility and reports where it is.
///
/// The Dock's icon list doesn't support AXMoved/AXResized (kAXErrorNotificationUnsupported, checked on macOS 26),
/// so the tracker combines the signals that do exist:
/// - AXCreated / AXUIElementDestroyed on the list: an icon was added or removed (app launch/quit, minimize).
/// - The cursor reaching or leaving the Dock (checked at 10 Hz, only while auto-hide is on).
/// - Screen configuration changes.
/// - A 1 s safety check for everything else (size slider, orientation change, `killall Dock`).
/// Each signal starts a 60 Hz burst of reads that runs until the Dock has been still for 0.4 s,
/// so the bar follows the Dock's own animation frame by frame.
@MainActor
final class NativeDockTracker {
    struct Dock: Equatable {
        var frame: CGRect          // AppKit coordinates
        var visibleFrame: CGRect   // usable area of the screen the Dock is on
    }

    /// Called whenever `dock` changes.
    var onChange: ((Dock?) -> Void)?
    /// nil while the Dock is hidden (auto-hide), restarting, or Accessibility hasn't been granted yet.
    private(set) var dock: Dock?

    private static let quietPeriod: TimeInterval = 0.4
    /// Auto-hide reveals only when the cursor touches the screen edge, so a hairline zone around the Dock's frame
    /// (parked just off-screen when hidden) is enough; a wider zone made ordinary mouse moves near the bottom start bursts.
    private static let cursorMargin: CGFloat = 2
    private static let cursorInterval: TimeInterval = 0.1

    private var list: AXUIElement?
    private var observer: AXObserver?
    private var lastFrame: CGRect?   // last frame read, including while hidden off-screen
    private var cursorWasNearDock = false
    private var burstTimer: Timer?
    private var burstEndsAt = Date.distantPast
    private var safetyTimer: Timer?
    private var cursorTimer: Timer?
    private var screenObserver: NSObjectProtocol?

    func start() {
        safetyTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.updateCursorWatch()
                if self.refresh() { self.follow() }
            }
        }
        updateCursorWatch()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.follow() }
        }
        follow()
    }

    /// Starts (or extends) a burst of reads at display rate.
    fileprivate func follow() {
        burstEndsAt = Date().addingTimeInterval(Self.quietPeriod)
        guard burstTimer == nil else { return }
        refresh()
        burstTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.burstTick() }
        }
    }

    private func burstTick() {
        if refresh() { burstEndsAt = Date().addingTimeInterval(Self.quietPeriod) }
        guard Date() > burstEndsAt else { return }
        burstTimer?.invalidate()
        burstTimer = nil
    }

    /// Watches the cursor only while auto-hide is on. Reading `NSEvent.mouseLocation` at 10 Hz is far cheaper than a
    /// global mouse monitor, which makes the window server deliver every mouse move in the system to us.
    private func updateCursorWatch() {
        let domain = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(domain)   // otherwise we'd keep reading a stale cached value
        let autohide = CFPreferencesGetAppBooleanValue("autohide" as CFString, domain, nil)
        if autohide, cursorTimer == nil {
            cursorTimer = Timer.scheduledTimer(withTimeInterval: Self.cursorInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.checkCursor() }
            }
        } else if !autohide, let timer = cursorTimer {
            timer.invalidate()
            cursorTimer = nil
        }
    }

    private func checkCursor() {
        guard let lastFrame else { return }
        let isNear = lastFrame.insetBy(dx: -Self.cursorMargin, dy: -Self.cursorMargin).contains(NSEvent.mouseLocation)
        // Follow on arriving (reveal) and on leaving (slide out). While the cursor waits at the edge with the Dock
        // still hidden, keep following so a non-zero `autohide-delay` can't outlast the burst's quiet period.
        if isNear != cursorWasNearDock || (isNear && dock == nil) { follow() }
        cursorWasNearDock = isNear
    }

    /// Reads the Dock once and notifies if it changed. Returns whether it changed.
    @discardableResult
    private func refresh() -> Bool {
        let next = read()
        guard next != dock else { return false }
        dock = next
        onChange?(next)
        return true
    }

    private func read() -> Dock? {
        if list == nil { attach() }
        guard let list, let axFrame = AX.frame(of: list), let primary = NSScreen.screens.first else {
            // The Dock restarted or access was revoked: drop the stale element and re-attach on the next read.
            detach()
            lastFrame = nil
            return nil
        }
        let frame = BarPlacement.appKitRect(fromAX: axFrame, primaryScreenHeight: primary.frame.height)
        lastFrame = frame
        guard let screen = NSScreen.screens.first(where: { BarPlacement.isShowing(frame, on: $0.frame) }) else { return nil }
        return Dock(frame: frame, visibleFrame: screen.visibleFrame)
    }

    // MARK: - Accessibility

    private func attach() {
        guard let (pid, list) = AX.dockList() else { return }
        self.list = list

        var observer: AXObserver?
        guard AXObserverCreate(pid, dockItemsChanged, &observer) == .success, let observer else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, list, kAXCreatedNotification as CFString, refcon)
        AXObserverAddNotification(observer, list, kAXUIElementDestroyedNotification as CFString, refcon)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        self.observer = observer
    }

    private func detach() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        list = nil
    }
}

/// AX callbacks are C function pointers and can't capture, so the tracker comes back through `refcon`.
/// The observer's run loop source is on the main run loop, so this always runs on the main thread.
private func dockItemsChanged(_: AXObserver, _: AXUIElement, _: CFString, refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let tracker = Unmanaged<NativeDockTracker>.fromOpaque(refcon).takeUnretainedValue()
    MainActor.assumeIsolated { tracker.follow() }
}
