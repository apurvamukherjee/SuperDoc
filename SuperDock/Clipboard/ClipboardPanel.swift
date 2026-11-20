import AppKit
import Carbon.HIToolbox
import SwiftUI

/// ⌥⌘V history: type to search, ↑/↓ to choose, Return to paste, Esc to close.
@MainActor
final class ClipboardPanel {
    @MainActor @Observable
    final class Model {
        var query = ""
        var filter: ClipItem.Kind?
        var selection = 0
        @ObservationIgnored let items: @MainActor () -> [ClipItem]
        /// Only the time of the last concealed copy is known; its content was never read.
        @ObservationIgnored let protectedAt: @MainActor () -> Date?

        init(items: @escaping @MainActor () -> [ClipItem] = { ClipboardStore.shared.items },
             protectedAt: @escaping @MainActor () -> Date? = { ClipboardService.shared.lastConcealedCopy }) {
            self.items = items
            self.protectedAt = protectedAt
        }

        var results: [ClipItem] {
            items().filter { item in
                (filter == nil || item.kind == filter)
                    && (query.isEmpty || item.summary.localizedCaseInsensitiveContains(query))
            }
        }

        var pinned: [ClipItem] {
            items().filter { $0.pinnedSlot != nil }.sorted { ($0.pinnedSlot ?? 0) < ($1.pinnedSlot ?? 0) }
        }
    }

    private let panel = OverlayPanel()
    private let model = Model()
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    var pastesDirectly = true

    init() {
        panel.acceptsKeyboard = true
    }

    func toggle() {
        if panel.isVisible { close() } else { open() }
    }

    private func open() {
        model.query = ""
        model.selection = 0
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? .zero
        panel.show(ClipboardHistoryView(model: model, now: Date()) { [weak self] item in self?.choose(item) }) { size in
            // Upper third of the screen, like Spotlight.
            NSPoint(x: area.midX - size.width / 2, y: area.maxY - size.height - area.height / 6)
        }
        panel.makeKey()

        // The search field has focus, so navigation keys are intercepted here before it sees them.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = Int(event.keyCode)   // NSEvent isn't Sendable, so only the key code crosses into the actor
            let handled = MainActor.assumeIsolated { self?.handle(keyCode) == true }
            return handled ? nil : event
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }   // clicked elsewhere
        }
    }

    private func handle(_ keyCode: Int) -> Bool {
        let count = model.results.count
        switch keyCode {
        case kVK_DownArrow: model.selection = min(model.selection + 1, max(count - 1, 0))
        case kVK_UpArrow: model.selection = max(model.selection - 1, 0)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if model.results.indices.contains(model.selection) { choose(model.results[model.selection]) }
        case kVK_Escape: close()
        default: return false
        }
        return true
    }

    private func choose(_ item: ClipItem) {
        close()
        if pastesDirectly { ClipboardService.shared.paste(item) } else { ClipboardService.shared.copy(item) }
    }

    private func close() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        panel.orderOut(nil)
    }
}

struct ClipboardHistoryView: View {
    let model: ClipboardPanel.Model
    let now: Date
    let onChoose: (ClipItem) -> Void

    var body: some View {
        HistoryContent(model: model, now: now, onChoose: onChoose).surfaceContext()
    }
}

private struct HistoryContent: View {
    @Environment(\.tile) private var tile
    @Environment(\.surfaceSnapshot) private var snapshot
    @Bindable var model: ClipboardPanel.Model
    let now: Date
    let onChoose: (ClipItem) -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Clipboard").tileStyle(.value)
                Spacer()
                KeyCap("⌥⌘V")
            }
            SurfaceSearchField(prompt: "Search copies", text: $model.query, focus: $searchFocused)
                .onChange(of: model.query) { model.selection = 0 }
            filters
            if model.results.isEmpty, !showsProtected {
                empty
            } else if snapshot != nil {
                list.frame(minHeight: 0, maxHeight: .infinity, alignment: .top).clipped()
            } else {
                ScrollViewReader { proxy in
                    ScrollView { list }
                        .onChange(of: model.selection) {
                            if model.results.indices.contains(model.selection) {
                                proxy.scrollTo(model.results[model.selection].id)
                            }
                        }
                }
            }
            if !model.pinned.isEmpty { pinned }
        }
        .padding(14)
        .frame(width: 440, height: 480)
        .surfacePanel(radius: 20)
        .surfacePop(from: 0.96, anchor: .top)
        .onAppear { searchFocused = true }
    }

    private var showsProtected: Bool {
        model.protectedAt() != nil && model.filter == nil && model.query.isEmpty
    }

    private var filters: some View {
        HStack(spacing: 6) {
            chip(String(localized: "All"), kind: nil)
            ForEach(ClipItem.Kind.allCases, id: \.self) { chip($0.title, kind: $0) }
        }
    }

    private func chip(_ title: String, kind: ClipItem.Kind?) -> some View {
        let selected = model.filter == kind
        return Button {
            model.filter = kind
            model.selection = 0
        } label: {
            Text(title)
                .font(tile.font(.body).weight(.medium))
                .foregroundStyle(selected ? tile.surface.controlOnInk : tile.surface.primary)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(selected ? tile.surface.controlOn : tile.surface.controlFill, in: Capsule())
        }
        .buttonStyle(TilePressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var list: some View {
        LazyVStack(spacing: 2) {
            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, item in
                ClipRow(item: item, detail: item.detail(now: now), isSelected: index == model.selection)
                    .id(item.id)
                    .onTapGesture { onChoose(item) }
            }
            if showsProtected { ProtectedRow() }
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            LimoFace().frame(width: 34, height: 34)
            Text(model.items().isEmpty ? "Copy something and it'll show up here." : "No matches").tileStyle(.detail)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pinned: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(tile.surface.divider).frame(height: 1)
            Text("Pinned").tileStyle(.label)
            HStack(spacing: 6) {
                ForEach(model.pinned.prefix(3)) { item in
                    Button { onChoose(item) } label: {
                        HStack(spacing: 6) {
                            KeyCap("⌃⌥⌘\(item.pinnedSlot ?? 0)")
                            Text(item.summary).font(tile.font(.body).weight(.medium)).foregroundStyle(tile.surface.primary)
                                .lineLimit(1)
                        }
                        .padding(.leading, 4)
                        .padding(.trailing, 10)
                        .padding(.vertical, 4)
                        .background(tile.surface.chipFill, in: Capsule())
                    }
                    .buttonStyle(TilePressStyle())
                    .accessibilityLabel("Paste pinned item \(item.pinnedSlot ?? 0): \(item.summary)")
                }
            }
        }
    }
}

private struct ClipRow: View {
    @Environment(\.tile) private var tile
    let item: ClipItem
    let detail: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ClipThumbnail(item: item, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.summary).tileStyle(looksLikeCode ? .mono : .title).truncationMode(.tail)
                Text(detail).tileStyle(.detail)
            }
            Spacer(minLength: 0)
            if isSelected { KeyCap("↩") }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? tile.surface.controlFill : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .contextMenu {
            Menu("Pin to Slot") {
                ForEach(1...9, id: \.self) { slot in
                    Button("⌃⌥⌘\(slot)") { ClipboardStore.shared.pin(item.id, slot: slot) }
                }
            }
            if item.pinnedSlot != nil { Button("Unpin") { ClipboardStore.shared.pin(item.id, slot: nil) } }
            Divider()
            Button("Delete", role: .destructive) { ClipboardStore.shared.remove(item.id) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// Commands and snippets read better in SF Mono; prose (anything with sentence punctuation) stays proportional.
    private var looksLikeCode: Bool {
        guard item.kind == .text, let text = item.text, !text.contains("\n") else { return false }
        return ![", ", ". ", "! ", "? "].contains { text.contains($0) } && !text.hasSuffix("!")
    }
}

/// Stands in for a password-manager copy: it's acknowledged, never stored, never pasteable.
private struct ProtectedRow: View {
    var body: some View {
        HStack(spacing: 10) {
            SurfaceGlyph(symbol: "lock", size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("Protected item").tileStyle(.title)
                Text("From a password manager · not saved").tileStyle(.detail)
            }
            Spacer(minLength: 0)
        }
        .opacity(0.55)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
