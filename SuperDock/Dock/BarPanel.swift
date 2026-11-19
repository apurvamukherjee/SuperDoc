import AppKit
import SwiftUI

/// Borderless, non-activating panel that sits beside the Dock on every Space.
final class BarPanel: NSPanel {
    private static let cornerRadius: CGFloat = 18

    init(content rootView: some View) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .statusBar
        // Leaving out .fullScreenAuxiliary is what keeps the bar off full-screen apps' Spaces.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false

        let content = NSHostingView(rootView: rootView)
        // Without this the hosting view resizes the panel to SwiftUI's preferred size, fighting BarController.
        content.sizingOptions = []
        contentView = Self.background(around: content)
    }

    override var canBecomeKey: Bool { true }   // lets widgets host text fields

    private static func background(around content: NSView) -> NSView {
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            glass.contentView = content
            return glass
        }
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = cornerRadius
        blur.layer?.masksToBounds = true
        content.autoresizingMask = [.width, .height]
        blur.addSubview(content)
        return blur
    }
}
