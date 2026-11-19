import AppKit
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "windows")

/// Lists windows and acts on them (focus, minimize, close, quit).
@MainActor
final class WindowService {
    static let shared = WindowService()

    /// Apps in the order they were last activated, most recent first.
    private(set) var appMRU: [pid_t] = []
    /// Set by FrozenAppMonitor; AX calls to these apps are skipped so a hung app can't stall the switcher.
    var frozen: Set<pid_t> = []

    private var activationObserver: NSObjectProtocol?

    private init() {
        if let front = NSWorkspace.shared.frontmostApplication { appMRU = [front.processIdentifier] }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            MainActor.assumeIsolated {
                self?.appMRU.removeAll { $0 == pid }
                self?.appMRU.insert(pid, at: 0)
            }
        }
    }

    /// Windows of one app (`pid`) or of all regular apps, in switcher order.
    func windows(of pid: pid_t? = nil, currentSpaceOnly: Bool = false) -> [WindowInfo] {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && (pid == nil || $0.processIdentifier == pid) }
        let options: CGWindowListOption = currentSpaceOnly
            ? [.optionOnScreenOnly, .excludeDesktopElements]
            : [.optionAll, .excludeDesktopElements]
        let rows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        var axTitles: [CGWindowID: String] = [:]
        for app in apps where !frozen.contains(app.processIdentifier) {
            for (id, element) in axWindows(of: app.processIdentifier) {
                axTitles[id] = AX.attribute(kAXTitleAttribute, of: element) as? String ?? ""
            }
        }
        let names = Dictionary(apps.map { ($0.processIdentifier, $0.localizedName ?? "") }, uniquingKeysWith: { first, _ in first })
        let windows = WindowRules.windows(from: rows, appNames: names, axTitles: axTitles, ownPID: getpid())
        return WindowRules.ordered(windows, appMRU: appMRU)
    }

    func focus(_ window: WindowInfo) {
        let running = NSRunningApplication(processIdentifier: window.pid)
        if running?.isHidden == true { running?.unhide() }
        // Background apps can't reliably activate others on macOS 14+ (cooperative activation), but AX can.
        AX.set(kAXFrontmostAttribute, of: AXUIElementCreateApplication(window.pid), to: true)
        if raise(window) { return }
        // Not visible to AX: the window is on another Space. AX activation doesn't switch Spaces, but launching
        // the app through Launch Services does (System Settings → "switch to a Space with open windows").
        if let url = running?.bundleURL {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        Task {
            for _ in 0..<10 {
                do {
                    try await Task.sleep(for: .milliseconds(100))
                } catch {
                    return   // only thrown on cancellation
                }
                if raise(window) { return }
            }
            log.info("Window \(window.id) never became reachable to raise")
        }
    }

    func minimize(_ window: WindowInfo) {
        guard let element = element(for: window) else { return }
        AX.set(kAXMinimizedAttribute, of: element, to: true)
    }

    func close(_ window: WindowInfo) {
        guard let element = element(for: window),
              let raw = AX.attribute(kAXCloseButtonAttribute, of: element), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return }
        // Type-ID check above makes this downcast safe.
        AX.perform(kAXPressAction, on: unsafeDowncast(raw, to: AXUIElement.self))
    }

    func quit(_ pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.terminate()
    }

    // MARK: - Private

    @discardableResult
    private func raise(_ window: WindowInfo) -> Bool {
        guard let element = element(for: window) else { return false }
        AX.set(kAXMinimizedAttribute, of: element, to: false)
        AX.set(kAXMainAttribute, of: element, to: true)
        AX.perform(kAXRaiseAction, on: element)
        return true
    }

    private func element(for window: WindowInfo) -> AXUIElement? {
        axWindows(of: window.pid).first { $0.id == window.id }?.element
    }

    /// AX only sees windows on the current Space (plus minimized ones).
    private func axWindows(of pid: pid_t) -> [(id: CGWindowID, element: AXUIElement)] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        let elements = AX.attribute(kAXWindowsAttribute, of: app) as? [AXUIElement] ?? []
        return elements.compactMap { element in AX.windowID(of: element).map { ($0, element) } }
    }
}
