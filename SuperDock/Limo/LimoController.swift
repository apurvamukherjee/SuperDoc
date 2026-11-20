import AppKit
import SwiftUI

/// Pops Limo out of the bar with a pill when an agent finishes, needs input, or an app freezes, then tucks it back.
@MainActor
final class LimoController {
    /// Stored under the pre-rename key so existing users keep their choice.
    static let enabledKey = "buddy.alerts"

    private static let noticeFor: Duration = .seconds(5)
    private static let tuckDuration: Duration = .milliseconds(260)
    /// Cursor farther than this from Limo doesn't pull its eyes.
    private static let gazeReach: CGFloat = 420

    private let panel: NSPanel
    private let stage = LimoStage()
    private var hideTask: Task<Void, Never>?
    private var mouseMonitors: [Any] = []
    /// Agent names folded into one "N agents done" pill while it is up.
    private var doneProjects: [String] = []
    private var waitingSessionID: String?

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false   // the pill draws its own; a window shadow would outline the headroom too
        panel.hidesOnDeactivate = false
        let host = NSHostingView(rootView: LimoPill(stage: stage) { [weak self] in self?.hide() })
        // Limo rises from below the panel's bottom edge, which sits on the bar, so clipping is what makes it emerge.
        host.wantsLayer = true
        host.layer?.masksToBounds = true
        panel.contentView = host
    }

    func show(_ session: AgentSessionService.Session, above anchor: NSRect?) {
        if session.status == .needsInput {
            doneProjects = []
            present(LimoAlert(title: String(localized: "\(session.project) needs you"), detail: session.tool.title,
                              pose: .handUp, tint: session.status.tint), above: anchor)
            waitingSessionID = session.id
            watchUntilAnswered(session.id)
            return
        }
        if stage.alert?.isUrgent == true { return }   // a done notice never covers something that needs you
        doneProjects.append(session.project)
        let title = doneProjects.count == 1
            ? String(localized: "\(session.project) is done")
            : String(localized: "\(doneProjects.count) agents done")
        let detail = doneProjects.count == 1
            ? String(localized: "\(session.tool.title) · just now")
            : doneProjects.joined(separator: ", ")
        present(LimoAlert(title: title, detail: detail, pose: .celebrates, tint: session.status.tint), above: anchor,
                keepsDone: true)
    }

    /// `anchor` is the bar's frame, or nil when the bar is hidden (pill goes bottom-centre of the main screen).
    /// `action` adds a button (e.g. Force Quit) that also dismisses the pill. `pose` defaults to one read off `symbol`.
    func show(message: String, symbol: String, color: Color, action: (title: String, run: () -> Void)?, above anchor: NSRect?,
              detail: String? = nil, pose: LimoPose? = nil) {
        let alert = LimoAlert(title: message, detail: detail, pose: pose ?? Self.pose(for: symbol), tint: color, action: action)
        if stage.alert?.isUrgent == true, !alert.isUrgent { return }
        doneProjects = []
        present(alert, above: anchor)
    }

    private static func pose(for symbol: String) -> LimoPose {
        switch symbol {
        case "exclamationmark.triangle.fill", "snowflake": .pokesIce
        case "hand.raised.fill": .handUp
        case "checkmark.seal.fill", "checkmark.circle.fill": .celebrates
        case "drop.fill", "drop": .takesSip
        case "link", "questionmark.circle": .curious
        case "gauge.with.dots.needle.67percent", "gauge.high": .checksGauge
        default: .saysHi
        }
    }

    private func present(_ alert: LimoAlert, above anchor: NSRect?, keepsDone: Bool = false) {
        if !keepsDone { doneProjects = [] }
        waitingSessionID = nil
        let replacing = panel.isVisible && stage.isOut
        stage.presence = LimoPresence.current
        stage.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        stage.gaze = CGVector(dx: 0.5, dy: 0.2)   // first it looks at what it's saying
        stage.alert = alert
        if !replacing { stage.isOut = false }
        place(above: anchor)
        panel.orderFrontRegardless()
        if !replacing {
            // One turn later so SwiftUI has laid out the tucked-in state to animate from.
            DispatchQueue.main.async { [stage] in stage.isOut = true }
        }
        followCursor(stage.travels)

        hideTask?.cancel()
        hideTask = nil
        guard !alert.isUrgent else { return }   // urgent pills stay until handled
        hideTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.noticeFor)
            } catch {
                return   // cancelled because a newer alert replaced this one
            }
            self?.hide()
        }
    }

    private func place(above anchor: NSRect?) {
        guard let host = panel.contentView else { return }
        let size = host.fittingSize
        let screen = NSScreen.main?.visibleFrame ?? .zero
        let origin = anchor.map { NSPoint(x: $0.midX - size.width / 2, y: $0.maxY + 2 - LimoPill.margin) }
            ?? NSPoint(x: screen.midX - size.width / 2, y: screen.minY + 12 - LimoPill.margin)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func hide() {
        hideTask?.cancel()
        hideTask = nil
        followCursor(false)
        doneProjects = []
        waitingSessionID = nil
        stage.isOut = false
        hideTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.tuckDuration)
            } catch {
                return   // a new alert arrived mid-tuck and owns the panel now
            }
            self?.panel.orderOut(nil)
            self?.stage.alert = nil
        }
    }

    /// Needs-you pills leave on their own once the agent stops waiting (answered in its terminal).
    private func watchUntilAnswered(_ id: String) {
        guard waitingSessionID == id else { return }
        let waiting = withObservationTracking {
            AgentSessionService.shared.sessions.contains { $0.id == id && $0.status == .needsInput }
        } onChange: { [weak self] in
            Task { @MainActor in self?.watchUntilAnswered(id) }
        }
        if !waiting { hide() }
    }

    /// Eyes follow the cursor only while the pill is up, driven by mouse events (no polling).
    private func followCursor(_ enabled: Bool) {
        mouseMonitors.forEach(NSEvent.removeMonitor)
        mouseMonitors = []
        guard enabled else { return }
        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.lookAtCursor() }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: handler) { mouseMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { handler($0); return $0 }) {
            mouseMonitors.append(local)
        }
    }

    private func lookAtCursor() {
        let eyes = NSPoint(x: panel.frame.minX + LimoPill.margin + 37, y: panel.frame.minY + LimoPill.margin + 28)
        let mouse = NSEvent.mouseLocation
        let across = mouse.x - eyes.x, down = eyes.y - mouse.y   // screen y runs up, gaze y runs down
        let distance = hypot(across, down)
        // Quantised to half steps so tiny moves don't redraw.
        let gaze = distance > Self.gazeReach || distance < 1
            ? CGVector(dx: 0.5, dy: 0.2)
            : CGVector(dx: (across / distance * 2).rounded() / 2, dy: (down / distance * 2).rounded() / 2)
        if stage.gaze != gaze { stage.gaze = gaze }
    }
}
