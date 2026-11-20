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
    private static let peekDuration: Duration = .milliseconds(1200)
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
        // The peek sits by the cursor; it must never swallow the next click.
        peekPanel.ignoresMouseEvents = true
        ClipboardService.shared.onCopied = { [weak self] item in self?.peek(item) }
        ClipboardService.shared.onConcealedCopy = { [weak self] in self?.peek(nil) }
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

    /// Copy Peek: a small confirmation of what was just copied, next to the cursor. nil = a concealed copy.
    private func peek(_ item: ClipItem?) {
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

/// Limo catching the copied card, then the card itself as a chip. Concealed copies say only that nothing was kept.
struct PeekView: View {
    let item: ClipItem?

    var body: some View {
        PeekContent(item: item).surfaceContext()
    }
}

private struct PeekContent: View {
    @Environment(\.tile) private var tile
    let item: ClipItem?

    var body: some View {
        HStack(spacing: 9) {
            LimoFigure(pose: .catchesIt).frame(width: 34, height: 34)
            if let item {
                chip(item)
                Text("copied").tileStyle(.detail)
            } else {
                Image(systemName: "lock.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(tile.surface.secondary)
                Text("Protected · not saved").tileStyle(.detail)
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 16)
        .padding(.vertical, 6)
        .surfacePanel(radius: 22)
        .surfacePop(from: 0.8, anchor: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.map { String(localized: "Copied: \($0.summary)") } ?? String(localized: "Protected item, not saved"))
    }

    private func chip(_ item: ClipItem) -> some View {
        HStack(spacing: 6) {
            switch item.kind {
            case .color, .image:
                ClipThumbnail(item: item, size: item.kind == .color ? 14 : 22)
            case .file:
                Image(nsImage: SurfaceKit.icon(for: item.fileURLs.first ?? URL(fileURLWithPath: "/")))
                    .resizable().frame(width: 18, height: 18)
            case .text, .link:
                EmptyView()
            }
            Text(chipText(item)).tileStyle(item.kind == .file || item.kind == .image ? .title : .mono)
                .truncationMode(.middle)
                .frame(maxWidth: 240, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tile.surface.controlFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func chipText(_ item: ClipItem) -> String {
        switch item.kind {
        case .link: URL(string: item.text ?? "")?.host() ?? item.summary
        case .text: String(item.summary.prefix(40))
        case .color, .image, .file: item.summary
        }
    }
}
