import AppKit
import SwiftUI

/// Borderless, non-activating panel that sits beside the Dock.
final class BarPanel: NSPanel {
    private let content: NSView
    private var background: NSView?
    private var applied: AppearancePrefs.Values?
    private var accessibilityObserver: NSObjectProtocol?

    init(content rootView: some View) {
        let hosting = NSHostingView(rootView: rootView)
        // Without this the hosting view resizes the panel to SwiftUI's preferred size, fighting BarController.
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]
        content = hosting
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        // Leaving out .fullScreenAuxiliary is what keeps the bar off full-screen apps' Spaces.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false

        let container = AppearanceView()
        container.onAppearanceChange = { [weak self] in self?.applyAppearance() }
        container.addSubview(hosting)
        contentView = container
        // The tiles follow Reduce Transparency through SwiftUI; the AppKit background has to be told.
        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyAppearance() }
        }
        applyAppearance()
    }

    override var canBecomeKey: Bool { true }   // lets widgets host text fields

    /// Rebuilds the background when the theme settings, light/dark mode or Reduce Transparency changed. Content sits on
    /// top as a sibling, so the background's opacity never fades the tiles.
    func applyAppearance() {
        guard let container = contentView else { return }
        var values = AppearancePrefs.current
        // The view's own appearance is already updated when it reports a switch; NSApp's may still lag behind.
        values.isDark = container.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        guard values != applied else { return }
        applied = values
        background?.removeFromSuperview()
        let view = AppearancePrefs.background(for: values)
        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        container.addSubview(view, positioned: .below, relativeTo: content)
        background = view
        content.frame = container.bounds
        invalidateShadow()
    }
}

/// Reports light/dark switches, which AppKit announces per view rather than by notification.
private final class AppearanceView: NSView {
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}
