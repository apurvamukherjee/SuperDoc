import AppKit
import Carbon.HIToolbox
import SwiftUI

enum ClipboardPrefs {
    static let historyKey = "clipboard.history"
    static let peekKey = "clipboard.peek"
    static let notchKey = "clipboard.notch"
    static let notchStyleKey = "clipboard.notchStyle"
    static let pasteDirectlyKey = "clipboard.pasteDirectly"
}

/// Turns clipboard features on and off as settings change: history (⌥⌘V), pinned slots (⌃⌥⌘1–9),
/// Copy Peek and the notch shelf.
@MainActor
final class ClipboardFeatures {
    private static let peekDuration: Duration = .milliseconds(1500)
    private static let digitKeys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                                    kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]

    private let historyPanel = ClipboardPanel()
    private let notch = NotchShelf()
    private let peekPanel = OverlayPanel()
    private var peekTask: Task<Void, Never>?
    private var hotKeys: [UInt32] = []
    private var defaultsObserver: NSObjectProtocol?
    private var showsPeek = true

    init() {
        ClipboardService.shared.onCopied = { [weak self] item in self?.peek(item) }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        }
        sync()
    }

    private func sync() {
        let enabled = WindowPrefs.bool(ClipboardPrefs.historyKey, default: true)
        ClipboardService.shared.isEnabled = enabled
        showsPeek = WindowPrefs.bool(ClipboardPrefs.peekKey, default: true)
        historyPanel.pastesDirectly = WindowPrefs.bool(ClipboardPrefs.pasteDirectlyKey, default: true)
        notch.style = UserDefaults.standard.string(forKey: ClipboardPrefs.notchStyleKey).flatMap(NotchShelf.Style.init) ?? .full
        notch.isEnabled = enabled && WindowPrefs.bool(ClipboardPrefs.notchKey, default: true)

        if enabled, hotKeys.isEmpty {
            let history = HotKeys.shared.register(.init(keyCode: kVK_ANSI_V, modifiers: optionKey | cmdKey)) { [weak self] in
                self?.historyPanel.toggle()
            }
            let slots = Self.digitKeys.enumerated().map { index, key in
                HotKeys.shared.register(.init(keyCode: key, modifiers: controlKey | optionKey | cmdKey)) {
                    if let item = ClipboardStore.shared.item(inSlot: index + 1) { ClipboardService.shared.paste(item) }
                }
            }
            hotKeys = ([history] + slots).compactMap { $0 }
        } else if !enabled {
            hotKeys.forEach(HotKeys.shared.unregister)
            hotKeys = []
        }
    }

    /// Copy Peek: a small confirmation of what was just copied, next to the cursor.
    private func peek(_ item: ClipItem) {
        guard showsPeek else { return }
        let mouse = NSEvent.mouseLocation
        peekPanel.show(PeekView(item: item)) { size in NSPoint(x: mouse.x + 12, y: mouse.y - size.height - 12) }
        peekTask?.cancel()
        peekTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.peekDuration)
            } catch {
                return   // a newer copy replaced this peek
            }
            self?.peekPanel.orderOut(nil)
        }
    }
}

private struct PeekView: View {
    let item: ClipItem

    var body: some View {
        HStack(spacing: 8) {
            ClipThumbnail(item: item, size: 28)
            Text(item.summary).font(.callout).lineLimit(2).frame(maxWidth: 260, alignment: .leading)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Copied: \(item.summary)")
    }
}
