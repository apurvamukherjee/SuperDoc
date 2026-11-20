import AppKit
import SwiftUI

/// Floating, non-activating panel for previews and the switcher: shows above everything, on every Space,
/// without taking focus from the app the user is in.
final class OverlayPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
    }

    /// Lets the panel take keystrokes (e.g. a search field) without activating SuperDock,
    /// so the app underneath stays frontmost and receives the paste afterwards.
    var acceptsKeyboard = false
    override var canBecomeKey: Bool { acceptsKeyboard }

    /// Replaces the content and sizes the panel to fit it.
    func show(_ view: some View, at origin: (CGSize) -> NSPoint) {
        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize
        contentView = hosting
        setFrame(NSRect(origin: origin(size), size: size), display: true)
        orderFrontRegardless()
    }
}

/// What window cards draw from, so previews and the gallery can feed fixtures instead of live captures.
struct WindowImages {
    var thumbnails: [CGWindowID: CGImage]
    var icon: @MainActor (WindowInfo) -> NSImage?

    @MainActor static var live: WindowImages {
        WindowImages(thumbnails: ThumbnailService.shared.images) { window in
            NSRunningApplication(processIdentifier: window.pid)?.bundleURL.map(IconProvider.icon(for:))
        }
    }
}

/// A window thumbnail (or its app icon on a soft well), ringed when selected, with minimize/close on hover.
struct WindowThumb: View {
    @Environment(\.tile) private var tile
    let window: WindowInfo
    let images: WindowImages
    var isSelected = false
    /// Dock previews ring the card under the cursor; the switcher rings only its selection.
    var ringsOnHover = false
    let size: CGSize
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        ZStack(alignment: .topTrailing) {
            thumbnail.frame(width: size.width, height: size.height).clipShape(shape)
            if isHovering {
                HStack(spacing: 4) {
                    SurfaceDiscButton(symbol: "minus", label: "Minimize") { WindowService.shared.minimize(window) }
                    SurfaceDiscButton(symbol: "xmark", label: "Close") { WindowService.shared.close(window) }
                }
                .padding(6)
                .transition(.opacity)
            }
        }
        .overlay {
            if isSelected || (ringsOnHover && isHovering) {
                shape.strokeBorder(tile.surface.primary, lineWidth: 2.5).padding(-3)
            }
        }
        .contentShape(shape)
        .onTapGesture(perform: onSelect)
        .onHover { hovering in withAnimation(Motion.press) { isHovering = hovering } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(window.appName): \(window.title)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = images.thumbnails[window.id] {
            Image(decorative: image, scale: 2).resizable().scaledToFill()
        } else {
            ZStack {
                tile.surface.controlFill
                if let icon = images.icon(window) {
                    Image(nsImage: icon).resizable().scaledToFit().frame(width: size.height * 0.5, height: size.height * 0.5)
                }
            }
        }
    }
}
