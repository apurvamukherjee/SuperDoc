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

/// Thumbnail (or app icon) + title, with minimize/close on hover.
struct WindowCard: View {
    let window: WindowInfo
    var isSelected = false
    var isFrozen = false
    let thumbnailHeight: CGFloat
    let onSelect: () -> Void

    @State private var isHovering = false
    private let thumbnails = ThumbnailService.shared

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                thumbnail
                    .frame(width: thumbnailHeight * 4 / 3, height: thumbnailHeight)
                if isHovering {
                    HStack(spacing: 4) {
                        control("minus", label: "Minimize") { WindowService.shared.minimize(window) }
                        control("xmark", label: "Close") { WindowService.shared.close(window) }
                    }
                    .padding(4)
                }
            }
            HStack(spacing: 4) {
                if isFrozen {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        .help("Not responding")
                        .accessibilityLabel("Not responding")
                }
                Text(window.title).font(.caption).lineLimit(1).truncationMode(.middle)
            }
            .frame(width: thumbnailHeight * 4 / 3)
        }
        .padding(8)
        .background(isSelected ? AnyShapeStyle(.tint.opacity(0.35)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(window.appName): \(window.title)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = thumbnails.images[window.id] {
            Image(decorative: image, scale: 2).resizable().scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(nsImage: NSRunningApplication(processIdentifier: window.pid)?.icon ?? NSImage())
                .resizable().scaledToFit().padding(thumbnailHeight / 5)
        }
    }

    private func control(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.caption2.weight(.bold)).frame(width: 18, height: 18)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
