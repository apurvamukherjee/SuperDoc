import AppKit

/// Pings every regular app over AX every few seconds; an app that times out twice in a row is "not responding".
@MainActor
final class FrozenAppMonitor {
    private static let interval: TimeInterval = 5
    private nonisolated static let timeout: Float = 0.5
    /// How long an app has failed to answer when it's reported: its first missed ping was this long before the last.
    static let secondsUnresponsive = Int(interval) * (FreezeCounter.threshold - 1)

    /// Called once per app when it becomes frozen.
    var onFrozen: ((NSRunningApplication) -> Void)?

    private var counter = FreezeCounter()
    private var timer: Timer?
    private var checking = false

    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            timer?.invalidate()
            timer = nil
            counter = FreezeCounter()
            WindowService.shared.frozen = []
            guard isEnabled else { return }
            timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.check() }
            }
        }
    }

    private func check() {
        guard !checking else { return }
        checking = true
        let pids = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.map(\.processIdentifier)
        Task {
            // Off the main thread: each hung app blocks its AX call for the full timeout.
            let responded = await Task.detached { Self.ping(pids) }.value
            checking = false
            for pid in counter.record(responded) {
                if let app = NSRunningApplication(processIdentifier: pid) { onFrozen?(app) }
            }
            WindowService.shared.frozen = counter.frozen
        }
    }

    private nonisolated static func ping(_ pids: [pid_t]) -> [pid_t: Bool] {
        Dictionary(uniqueKeysWithValues: pids.map { pid in
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, timeout)
            var value: CFTypeRef?
            // Only a timeout counts as frozen; apps that just don't support AX return other errors.
            let error = AXUIElementCopyAttributeValue(app, kAXRoleAttribute as CFString, &value)
            return (pid, error != .cannotComplete)
        })
    }
}
