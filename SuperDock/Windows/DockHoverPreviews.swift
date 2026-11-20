import AppKit
import SwiftUI

/// Shows an app's windows when the cursor rests on its icon in the native Dock.
@MainActor
final class DockHoverPreviews {
    private static let pollInterval: TimeInterval = 1.0 / 20
    private static let dwell: TimeInterval = 0.12        // avoids flashing previews while sweeping across the Dock
    private static let grace: TimeInterval = 0.25        // time to move from the icon into the preview
    private static let gap: CGFloat = 6

    private let tracker: NativeDockTracker
    private let panel = OverlayPanel()
    private var timer: Timer?
    private var hovered: (url: URL, frame: CGRect)?      // AppKit coordinates
    private var hoverStart = Date.distantPast
    private var lastInside = Date.distantPast
    private var shownURL: URL?

    init(tracker: NativeDockTracker) {
        self.tracker = tracker
    }

    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            timer?.invalidate()
            timer = nil
            hide()
            guard isEnabled else { return }
            // Polling the cursor position is a cheap read; AX hit tests only happen while it's over the Dock.
            timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        }
    }

    private func tick() {
        let mouse = NSEvent.mouseLocation
        let now = Date()
        if panel.isVisible, panel.frame.insetBy(dx: -Self.gap, dy: -Self.gap).contains(mouse) {
            lastInside = now
            return
        }
        guard let dock = tracker.dock, dock.frame.contains(mouse), let item = appItem(at: mouse) else {
            hovered = nil
            if panel.isVisible, now.timeIntervalSince(lastInside) > Self.grace { hide() }
            return
        }
        lastInside = now
        if item.url != hovered?.url {
            hovered = item
            hoverStart = now
            // Already showing another app's previews: switch straight away, like the Dock's own labels.
            if panel.isVisible { show(item, dock: dock) }
        } else if shownURL != item.url, now.timeIntervalSince(hoverStart) >= Self.dwell {
            show(item, dock: dock)
        }
    }

    private func show(_ item: (url: URL, frame: CGRect), dock: NativeDockTracker.Dock) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL == item.url }) else { return hide() }
        let windows = WindowService.shared.windows(of: app.processIdentifier)
        guard !windows.isEmpty else { return hide() }
        shownURL = item.url

        let frozen = WindowService.shared.frozen.contains(app.processIdentifier)
        let view = PreviewsView(appName: app.localizedName ?? "", windows: windows, frozen: frozen) { [weak self] window in
            self?.hide()
            WindowService.shared.focus(window)
        } onQuit: { [weak self] in
            self?.hide()
            app.terminate()
        } onForceQuit: { [weak self] in
            self?.hide()
            app.forceTerminate()
        }
        let orientation = BarPlacement.orientation(of: dock.frame, in: dock.visibleFrame)
        panel.show(view) { size in
            var origin: NSPoint
            switch orientation {
            case .bottom: origin = NSPoint(x: item.frame.midX - size.width / 2, y: dock.frame.maxY + Self.gap)
            case .left: origin = NSPoint(x: dock.frame.maxX + Self.gap, y: item.frame.midY - size.height / 2)
            case .right: origin = NSPoint(x: dock.frame.minX - Self.gap - size.width, y: item.frame.midY - size.height / 2)
            }
            let area = dock.visibleFrame
            origin.x = min(max(origin.x, area.minX), area.maxX - size.width)
            origin.y = min(max(origin.y, area.minY), area.maxY - size.height)
            return origin
        }
        Task { await ThumbnailService.shared.load(windows.map(\.id)) }
    }

    private func hide() {
        panel.orderOut(nil)
        shownURL = nil
    }

    /// The application icon under `point` (AppKit coordinates), via an AX hit test on the Dock.
    private func appItem(at point: NSPoint) -> (url: URL, frame: CGRect)? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let height = AX.primaryScreenHeight
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateApplication(dock.processIdentifier),
                                               Float(point.x), Float(height - point.y), &element) == .success,
              let element, AX.subrole(of: element) == "AXApplicationDockItem",
              let url = AX.url(of: element), let axFrame = AX.frame(of: element) else { return nil }
        return (url, BarPlacement.appKitRect(fromAX: axFrame, primaryScreenHeight: height))
    }
}

/// Window cards above a Dock icon, the app's name and window count, and Quit (Force Quit when it's frozen).
struct PreviewsView: View {
    let appName: String
    let windows: [WindowInfo]
    let frozen: Bool
    var fixtureImages: WindowImages?
    let onPick: (WindowInfo) -> Void
    let onQuit: () -> Void
    let onForceQuit: () -> Void

    var body: some View {
        // `.live` is read here, inside body, so thumbnails fill in as ThumbnailService captures them.
        PreviewsContent(view: self, images: fixtureImages ?? .live).surfaceContext()
    }
}

private struct PreviewsContent: View {
    @Environment(\.tile) private var tile
    let view: PreviewsView
    let images: WindowImages

    private static let thumb = CGSize(width: 136, height: 76)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(view.windows) { window in
                    VStack(alignment: .leading, spacing: 6) {
                        WindowThumb(window: window, images: images, ringsOnHover: true, size: Self.thumb) { view.onPick(window) }
                        Text(window.title).tileStyle(.body).lineLimit(1).frame(width: Self.thumb.width, alignment: .leading)
                    }
                }
            }
            HStack(spacing: 8) {
                if view.frozen {
                    Label("Not responding", systemImage: "exclamationmark.triangle.fill")
                        .font(tile.font(.detail).weight(.semibold)).foregroundStyle(tile.surface.warning)
                } else {
                    Text(view.windows.count == 1 ? "\(view.appName) · 1 window" : "\(view.appName) · \(view.windows.count) windows")
                        .tileStyle(.detail)
                }
                Spacer(minLength: 8)
                if view.frozen { pill("Force Quit", tint: tile.surface.danger, action: view.onForceQuit) }
                pill("Quit", tint: tile.surface.primary, action: view.onQuit)
            }
        }
        .fixedSize()
        .padding(12)
        .surfacePanel(radius: 18)
        .surfacePop(from: 0.9, anchor: .bottom)
    }

    private func pill(_ title: LocalizedStringKey, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(tile.font(.body).weight(.semibold)).foregroundStyle(tint)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(tile.surface.controlFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(TilePressStyle())
    }
}
