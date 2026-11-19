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

        var results: [ClipItem] {
            ClipboardStore.shared.items.filter { item in
                (filter == nil || item.kind == filter)
                    && (query.isEmpty || item.summary.localizedCaseInsensitiveContains(query))
            }
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
        panel.show(ClipboardHistoryView(model: model) { [weak self] item in self?.choose(item) }) { size in
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

private struct ClipboardHistoryView: View {
    @Bindable var model: ClipboardPanel.Model
    let onChoose: (ClipItem) -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            TextField("Search clipboard", text: $model.query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($searchFocused)
                .onChange(of: model.query) { model.selection = 0 }
            Picker("Type", selection: $model.filter) {
                Text("All").tag(ClipItem.Kind?.none)
                ForEach(ClipItem.Kind.allCases, id: \.self) { Text($0.title).tag(ClipItem.Kind?.some($0)) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: model.filter) { model.selection = 0 }
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, item in
                            ClipRow(item: item, isSelected: index == model.selection)
                                .id(item.id)
                                .onTapGesture { onChoose(item) }
                        }
                    }
                }
                .onChange(of: model.selection) {
                    if model.results.indices.contains(model.selection) { proxy.scrollTo(model.results[model.selection].id) }
                }
            }
            if model.results.isEmpty {
                Text(ClipboardStore.shared.items.isEmpty ? "Copy something and it'll show up here." : "No matches")
                    .foregroundStyle(.secondary).frame(maxHeight: .infinity)
            }
        }
        .padding(12)
        .frame(width: 460, height: 440)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { searchFocused = true }
    }
}

private struct ClipRow: View {
    let item: ClipItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ClipThumbnail(item: item, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.summary).lineLimit(2).truncationMode(.tail)
                Text(item.date, format: .relative(presentation: .named)).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if let slot = item.pinnedSlot {
                Text("⌃⌥⌘\(slot)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    .accessibilityLabel("Pinned to slot \(slot)")
            }
        }
        .padding(6)
        .background(isSelected ? AnyShapeStyle(.tint.opacity(0.3)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
}
