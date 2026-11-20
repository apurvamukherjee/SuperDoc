import AppKit
import SwiftUI

/// First-run flow, hosted by Limo (design/mockups/09-onboarding.png): welcome → placement → Accessibility → starter set.
@MainActor
enum Onboarding {
    /// Unchanged from the first onboarding, so people who finished that one never see this one.
    static let doneKey = "onboarding.done"

    private static var window: NSWindow?

    static var isNeeded: Bool { !UserDefaults.standard.bool(forKey: doneKey) }

    static func show() {
        present(OnboardingView(onFinish: finish))
    }

    /// After onboarding, a lost Accessibility grant (every ad-hoc-signed update loses it) gets the same Paper step
    /// on its own, which closes itself once access is back.
    static func showAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        present(OnboardingView(step: .accessibility, onAccessGranted: {
            window?.close()
            window = nil
        }, onFinish: { _ in }))
    }

    private static func present(_ view: OnboardingView) {
        let hosting = NSHostingView(rootView: view)
        // No size constraints from SwiftUI, or AppKit refuses the shrink-into-the-bar frame at the end.
        hosting.sizingOptions = []
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: OnboardingTheme.windowSize),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.contentView = hosting
        window.title = String(localized: "Welcome to SuperDock")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(Palette.cream)
        window.isReleasedWhenClosed = false
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    /// Saves first, so closing the window mid-animation can't lose the choice; then lets the confetti play and
    /// shrinks the window into the bar.
    private static func finish(_ starter: StarterSet) {
        LayoutStore.shared.tiles = starter.tiles()
        UserDefaults.standard.set(true, forKey: doneKey)
        guard let window else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        Task { @MainActor in
            // Nothing cancels this task; if something ever did, closing straight away is the right fallback.
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 750))
            await NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion ? 0.2 : 0.45
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                if !reduceMotion { window.animator().setFrame(barTarget(for: window), display: true) }
                window.animator().alphaValue = 0
            }
            window.close()
            self.window = nil
        }
    }

    /// The live bar if it's on screen (it isn't until Accessibility is granted), else the bottom middle of the
    /// screen, where the Dock is.
    private static func barTarget(for window: NSWindow) -> NSRect {
        if let bar = NSApp.windows.first(where: { $0 is BarPanel && $0.isVisible }) { return bar.frame }
        let screen = (window.screen ?? NSScreen.main)?.visibleFrame ?? window.frame
        return NSRect(x: screen.midX - 60, y: screen.minY + 8, width: 120, height: 40)
    }
}
