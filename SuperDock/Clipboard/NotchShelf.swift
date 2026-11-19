import AppKit
import SwiftUI

/// Recent copies under the MacBook notch. Two styles:
/// - full: hovering the notch itself drops a wide shelf of recent copies;
/// - icon: a small clipboard icon sits just right of the notch, and only that icon opens a compact list,
///   so nothing spreads across the menu bar's right side.
@MainActor
final class NotchShelf {
    enum Style: String, CaseIterable {
        case full, icon
    }

    private static let pollInterval: TimeInterval = 0.1
    private static let grace: TimeInterval = 0.3
    private static let shownCount = 8

    private let shelf = OverlayPanel()
    private let iconPanel = OverlayPanel()
    private var timer: Timer?
    private var lastInside = Date.distantPast

    var style = Style.full {
        didSet { if style != oldValue { restart() } }
    }

    var isEnabled = false {
        didSet { if isEnabled != oldValue { restart() } }
    }

    private func restart() {
        timer?.invalidate()
        timer = nil
        shelf.orderOut(nil)
        iconPanel.orderOut(nil)
        guard isEnabled, let notch = Self.notchRect() else { return }   // Macs without a notch: nothing to do
        if style == .icon { showIcon(beside: notch) }
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        guard let notch = Self.notchRect() else { return }
        let mouse = NSEvent.mouseLocation
        let trigger = style == .icon ? iconPanel.frame : notch.insetBy(dx: 0, dy: -2)
        let inside = trigger.contains(mouse) || (shelf.isVisible && shelf.frame.insetBy(dx: -8, dy: -8).contains(mouse))
        if inside {
            lastInside = Date()
            if !shelf.isVisible { openShelf(under: style == .icon ? iconPanel.frame : notch) }
        } else if shelf.isVisible, Date().timeIntervalSince(lastInside) > Self.grace {
            shelf.orderOut(nil)
        }
    }

    private func openShelf(under anchor: NSRect) {
        let items = Array(ClipboardStore.shared.items.prefix(Self.shownCount))
        guard !items.isEmpty else { return }
        let compact = style == .icon
        shelf.show(ShelfView(items: items, vertical: compact) { [weak self] item in
            ClipboardService.shared.copy(item)
            self?.shelf.orderOut(nil)
        }) { size in
            let left = compact ? anchor.maxX - size.width : anchor.midX - size.width / 2
            return NSPoint(x: left, y: anchor.minY - size.height - 4)
        }
    }

    private func showIcon(beside notch: NSRect) {
        let size = NSSize(width: 28, height: notch.height)
        iconPanel.show(Image(systemName: "list.clipboard").font(.system(size: 13))
            .frame(width: size.width, height: size.height)
            .accessibilityLabel("Recent copies")) { _ in NSPoint(x: notch.maxX + 6, y: notch.minY) }
        iconPanel.hasShadow = false
    }

    /// The notch's rect in AppKit coordinates: the gap between the two menu bar areas either side of it.
    private static func notchRect() -> NSRect? {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }),
              let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return nil }
        return NSRect(x: left.maxX, y: screen.frame.maxY - screen.safeAreaInsets.top,
                      width: right.minX - left.maxX, height: screen.safeAreaInsets.top)
    }
}

private struct ShelfView: View {
    let items: [ClipItem]
    let vertical: Bool
    let onPick: (ClipItem) -> Void

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            ForEach(items) { item in
                Button { onPick(item) } label: {
                    if vertical {
                        HStack {
                            ClipThumbnail(item: item, size: 22)
                            Text(item.summary).lineLimit(1).frame(width: 220, alignment: .leading)
                        }
                    } else {
                        VStack(spacing: 4) {
                            ClipThumbnail(item: item, size: 48)
                            Text(item.summary).font(.caption2).lineLimit(1).frame(width: 72)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Copy")
                .accessibilityLabel("Copy \(item.summary)")
            }
        }
        .padding(10)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .environment(\.colorScheme, .dark)   // reads as an extension of the black notch
    }
}
