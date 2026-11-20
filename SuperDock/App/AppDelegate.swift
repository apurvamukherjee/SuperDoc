import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var barController: BarController?
    private var windowFeatures: WindowFeatures?
    private var clipboardFeatures: ClipboardFeatures?
    private var wallpaper: LiveWallpaper?
    private var termSignal: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        GalleryRenderer.runIfRequested()
        #endif
        // Before anything else: if SuperDock crashed while hiding the system Dock, put the user's settings back
        // (or re-hide it if replacement mode is still on). Hard rule 9.
        DockReplacement.standard.reconcile(enabled: DockReplacement.isEnabled)
        quitCleanlyOnSIGTERM()

        // First launch gets the full welcome flow (which includes Accessibility); later launches only re-ask if access was lost.
        if Onboarding.isNeeded { Onboarding.show() } else { Onboarding.showAccessibilityIfNeeded() }
        // Created even without access: the tracker keeps retrying, so the bar appears as soon as access is granted.
        let tracker = NativeDockTracker()
        let limo = LimoController()
        let bar = BarController(tracker: tracker, limo: limo)
        barController = bar
        windowFeatures = WindowFeatures(tracker: tracker, alerts: limo) { [weak bar] in bar?.visibleFrame }
        clipboardFeatures = ClipboardFeatures()
        wallpaper = LiveWallpaper()

        HotKeys.shared.register(.init(keyCode: kVK_ANSI_L, modifiers: controlKey | optionKey | cmdKey)) { Launchpad.shared.toggle() }
        HotKeys.shared.register(.init(keyCode: kVK_ANSI_P, modifiers: controlKey | optionKey | cmdKey)) {
            LayoutStore.shared.activateNext()
        }
    }

    /// `kill`, `launchctl` and some updaters send SIGTERM, which AppKit doesn't turn into a normal quit, so
    /// applicationWillTerminate (and the Dock restore) would be skipped. Route it through NSApp.terminate instead.
    private func quitCleanlyOnSIGTERM() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { NSApp.terminate(nil) } }
        source.resume()
        termSignal = source
    }

    /// The system Dock comes back whenever SuperDock isn't running; the next launch hides it again if the mode is on.
    func applicationWillTerminate(_ notification: Notification) {
        DockReplacement.standard.restore()
    }
}
