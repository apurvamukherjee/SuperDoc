import AppKit
import Carbon.HIToolbox
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "clipboard")

/// Watches the system pasteboard and writes items back to it.
@MainActor
final class ClipboardService {
    static let shared = ClipboardService()

    /// macOS has no pasteboard-changed notification; comparing `changeCount` twice a second is the standard approach and costs nothing.
    private static let pollInterval: TimeInterval = 0.5

    /// Fires for copies made in other apps (not for SuperDock re-copying a history item). Copy Peek listens.
    var onCopied: ((ClipItem) -> Void)?

    private let store = ClipboardStore.shared
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var ownChangeCount: Int?

    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            timer?.invalidate()
            timer = nil
            guard isEnabled else { return }
            lastChangeCount = NSPasteboard.general.changeCount   // don't record whatever was copied while it was off
            timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.check() }
            }
        }
    }

    private func check() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let content = ClipboardCapture.read(pasteboard),
              let item = store.add(content, sourceApp: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) else { return }
        if pasteboard.changeCount != ownChangeCount { onCopied?(item) }
    }

    /// Puts the item on the system pasteboard.
    func copy(_ item: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.kind {
        case .text, .link, .color:
            pasteboard.setString(item.text ?? "", forType: .string)
        case .file:
            pasteboard.writeObjects(item.fileURLs as [NSURL])
        case .image:
            guard let url = store.imageURL(for: item) else { return }
            do {
                pasteboard.setData(try Data(contentsOf: url), forType: .png)
            } catch {
                log.error("Clipboard image missing: \(error)")
            }
        }
        ownChangeCount = pasteboard.changeCount
    }

    /// Copies, then presses ⌘V in the frontmost app (needs Accessibility, which the bar already has).
    func paste(_ item: ClipItem) {
        copy(item)
        Task {
            // Give the history panel time to close so the keystroke lands in the app underneath.
            do {
                try await Task.sleep(for: .milliseconds(80))
            } catch {
                return   // only thrown on cancellation
            }
            let source = CGEventSource(stateID: .combinedSessionState)
            for isDown in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: isDown)
                event?.flags = .maskCommand
                event?.post(tap: .cghidEventTap)
            }
        }
    }
}
