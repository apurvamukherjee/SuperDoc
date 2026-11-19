import AppKit
import SwiftUI

/// Borderless, non-activating panel that sits beside the Dock.
final class BarPanel: NSPanel {
    private let content: NSView
    private var background: NSView?
    private var applied: AppearancePrefs.Values?

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

        let container = NSView()
        container.addSubview(hosting)
        contentView = container
        applyAppearance()
    }

    override var canBecomeKey: Bool { true }   // lets widgets host text fields

    /// Rebuilds the background when the theme settings changed. Content sits on top as a sibling,
    /// so the background's opacity never fades the tiles.
    func applyAppearance() {
        let values = AppearancePrefs.current
        guard values != applied, let container = contentView else { return }
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
