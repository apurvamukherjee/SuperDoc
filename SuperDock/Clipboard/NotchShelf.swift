import AppKit
import SwiftUI

/// Recent copies under the MacBook notch. Two styles:
/// - full: resting on the notch opens it like a pocket: the black grows down and recent copies fan out beneath;
/// - icon: a small clipboard icon sits just right of the notch, and only that icon opens a compact list,
///   so nothing spreads across the menu bar's right side.
@MainActor
final class NotchShelf {
    enum Style: String, CaseIterable {
        case full, icon
    }

    private static let pollInterval: TimeInterval = 0.1
    /// Sweeping the cursor along the menu bar shouldn't pop the shelf.
    private static let dwell: TimeInterval = 0.25
    private static let grace: TimeInterval = 0.3
    private static let shownCount = 5

    private let shelf = OverlayPanel()
    private let iconPanel = OverlayPanel()
    private var timer: Timer?
    private var hoverStart: Date?
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
        guard inside else {
            hoverStart = nil
            if shelf.isVisible, Date().timeIntervalSince(lastInside) > Self.grace { shelf.orderOut(nil) }
            return
        }
        lastInside = Date()
        let start = hoverStart ?? Date()
        hoverStart = start
        if !shelf.isVisible, Date().timeIntervalSince(start) >= Self.dwell {
            openShelf(under: style == .icon ? iconPanel.frame : notch)
        }
    }

    private func openShelf(under anchor: NSRect) {
        let items = Array(ClipboardStore.shared.items.prefix(Self.shownCount))
        guard !items.isEmpty else { return }
        let pick: (ClipItem) -> Void = { [weak self] item in
            ClipboardService.shared.copy(item)
            self?.shelf.orderOut(nil)
        }
        if style == .icon {
            shelf.show(NotchList(items: items, onPick: pick)) { size in
                NSPoint(x: anchor.maxX - size.width, y: anchor.minY - size.height - 4)
            }
        } else {
            shelf.hasShadow = false   // the pocket is drawn flush with the notch; cards carry their own shadows
            shelf.show(NotchPocket(items: items, notchWidth: anchor.width, notchHeight: anchor.height, now: Date(), onPick: pick)) { size in
                NSPoint(x: anchor.midX - size.width / 2, y: anchor.maxY - size.height)
            }
        }
    }

    private func showIcon(beside notch: NSRect) {
        let size = NSSize(width: 28, height: notch.height)
        iconPanel.show(Image(systemName: "list.clipboard").font(.system(size: 13)).foregroundStyle(.white)
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

/// The opened notch: black grows down from the hardware notch on a spring, then cards fan out 40 ms apart.
struct NotchPocket: View {
    let items: [ClipItem]
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let now: Date
    let onPick: (ClipItem) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.surfaceSnapshot) private var snapshot
    @State private var open = false

    private static let card = CGSize(width: 124, height: 96)
    private static let cardSpacing: CGFloat = 8
    private static let pocketHeight: CGFloat = 92

    private var pocketWidth: CGFloat {
        max(notchWidth, CGFloat(items.count) * (Self.card.width + Self.cardSpacing) + 40)
    }

    var body: some View {
        let isOpen = open || snapshot != nil
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous)
                .fill(.black)
                .frame(width: isOpen ? pocketWidth : notchWidth, height: isOpen ? Self.pocketHeight + notchHeight : notchHeight)
            header
                .frame(width: pocketWidth - 48)
                .padding(.top, notchHeight + 10)
                .opacity(isOpen ? 1 : 0)
            HStack(spacing: Self.cardSpacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    card(item, index: index, isOpen: isOpen)
                }
            }
            .padding(.top, notchHeight + Self.pocketHeight - 30)
        }
        .frame(width: pocketWidth + 24, height: notchHeight + Self.pocketHeight + Self.card.height, alignment: .top)
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(reduceMotion ? Motion.reduced : Motion.pop) { open = true }
        }
    }

    private var header: some View {
        HStack {
            Label("Recent copies", systemImage: "pin.fill").labelStyle(.titleAndIcon)
            Spacer()
            Text("⌥⌘V for all").foregroundStyle(.white.opacity(0.7))
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
    }

    private func card(_ item: ClipItem, index: Int, isOpen: Bool) -> some View {
        let offset = CGFloat(index) - CGFloat(items.count - 1) / 2
        let stagger = reduceMotion ? Motion.reduced : Motion.pop.delay(0.12 + Double(index) * 0.04)
        return Button { onPick(item) } label: {
            NotchCard(item: item, now: now).frame(width: Self.card.width, height: Self.card.height)
        }
        .buttonStyle(TilePressStyle())
        .rotationEffect(.degrees(isOpen ? offset * 5 : 0))
        .offset(y: isOpen ? -abs(offset) * 12 + 10 : (reduceMotion ? 0 : -70))
        .scaleEffect(isOpen || reduceMotion ? 1 : 0.6)
        .opacity(isOpen ? 1 : 0)
        .animation(stagger, value: isOpen)
        .onDrag { item.dragProvider }
        .help("Click to copy, or drag to paste")
        .accessibilityLabel("Copy \(item.summary)")
    }
}

/// One white card under the notch.
private struct NotchCard: View {
    let item: ClipItem
    let now: Date

    private var caption: String { "\(item.kind.caption) · \(ClipItem.age(of: item.date, now: now))".uppercased() }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white, in: shape)
            .clipShape(shape)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
            .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .image:
            ZStack(alignment: .bottomLeading) {
                if let image = ClipImages.image(for: item) {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Palette.hot, Palette.codex], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                Text(caption).font(.system(size: 9, weight: .bold)).tracking(0.6).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .padding(8)
            }
        case .color:
            VStack(alignment: .leading, spacing: 7) {
                captionText
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: item.text ?? "") ?? .clear).frame(height: 30)
                Text(item.summary).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Palette.ink)
            }
            .padding(10)
        case .link:
            let url = URL(string: item.text ?? "")
            VStack(alignment: .leading, spacing: 4) {
                captionText
                Text(url?.host() ?? item.summary).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                Text(url?.path() ?? "").font(.system(size: 11)).foregroundStyle(Palette.ink.opacity(0.6)).lineLimit(2)
                    .truncationMode(.middle)
            }
            .padding(10)
        case .text, .file:
            VStack(alignment: .leading, spacing: 4) {
                captionText
                Text(item.summary).font(.system(size: 12)).foregroundStyle(Palette.ink).lineLimit(3)
            }
            .padding(10)
        }
    }

    private var captionText: some View {
        Text(caption).font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(Palette.ink.opacity(0.5))
    }
}

/// The icon style's compact list, dropping from the clipboard icon beside the notch.
private struct NotchList: View {
    let items: [ClipItem]
    let onPick: (ClipItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items) { item in
                Button { onPick(item) } label: {
                    HStack(spacing: 8) {
                        ClipThumbnail(item: item, size: 22)
                        Text(item.summary).tileStyle(.body).lineLimit(1).frame(width: 220, alignment: .leading)
                    }
                    .padding(4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TilePressStyle())
                .onDrag { item.dragProvider }
                .accessibilityLabel("Copy \(item.summary)")
            }
        }
        .padding(8)
        .background(.black, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .tileContext(TileContext(unit: SurfaceKit.unit, surface: SurfaceTokens(.solidDark)))
    }
}
