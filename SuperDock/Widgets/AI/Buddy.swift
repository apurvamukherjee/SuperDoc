import AppKit
import SwiftUI

// ponytail: SF Symbol stand-in until the Buddy character is designed (SUPERDOCK.md §12 #2).
/// Pops a small pill above the bar when an agent finishes or needs approval.
@MainActor
final class BuddyController {
    static let enabledKey = "buddy.alerts"

    private static let visibleFor: Duration = .seconds(5)
    private let panel: NSPanel
    private var hideTask: Task<Void, Never>?

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
    }

    func show(_ session: AgentSessionService.Session, above anchor: NSRect?) {
        let message = session.status == .needsInput
            ? String(localized: "\(session.project) needs your input (\(session.tool.title))")
            : String(localized: "\(session.project) is done (\(session.tool.title))")
        show(message: message, symbol: session.status == .needsInput ? "hand.raised.fill" : "checkmark.seal.fill",
             color: session.status.color, action: nil, above: anchor)
    }

    /// `anchor` is the bar's frame, or nil when the bar is hidden (pill goes bottom-centre of the main screen).
    /// `action` adds a button (e.g. Force Quit) that also dismisses the pill.
    func show(message: String, symbol: String, color: Color, action: (title: String, run: () -> Void)?, above anchor: NSRect?) {
        let pill = AlertPill(message: message, symbol: symbol, color: color, action: action) { [weak self] in self?.hide() }
        let content = NSHostingView(rootView: pill)
        let size = content.fittingSize
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let origin = anchor.map { NSPoint(x: $0.midX - size.width / 2, y: $0.maxY + 8) }
            ?? NSPoint(x: screen.midX - size.width / 2, y: screen.minY + 12)
        panel.contentView = content
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()

        hideTask?.cancel()
        hideTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.visibleFor)
            } catch {
                return   // cancelled because a newer alert replaced this one
            }
            self?.hide()
        }
    }

    private func hide() {
        panel.orderOut(nil)
    }
}

private struct AlertPill: View {
    let message: String
    let symbol: String
    let color: Color
    let action: (title: String, run: () -> Void)?
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color).font(.title3).accessibilityHidden(true)
            Text(message).font(.callout.weight(.medium)).fixedSize()   // the panel sizes to fit; never truncate
            if let action {
                Button(action.title) {
                    action.run()
                    dismiss()
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .contentShape(Capsule())
        .onTapGesture(perform: dismiss)
        .accessibilityElement(children: .combine)
    }
}
