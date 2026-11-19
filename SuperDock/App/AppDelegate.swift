import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var barController: BarController?
    private var windowFeatures: WindowFeatures?
    private var clipboardFeatures: ClipboardFeatures?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Permissions.showAccessibilityOnboardingIfNeeded()
        // Created even without access: the tracker keeps retrying, so the bar appears as soon as access is granted.
        let tracker = NativeDockTracker()
        let buddy = BuddyController()
        let bar = BarController(tracker: tracker, buddy: buddy)
        barController = bar
        windowFeatures = WindowFeatures(tracker: tracker, alerts: buddy) { [weak bar] in bar?.visibleFrame }
        clipboardFeatures = ClipboardFeatures()
    }
}
