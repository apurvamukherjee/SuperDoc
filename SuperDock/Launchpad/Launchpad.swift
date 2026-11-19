import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Full-screen app grid with search: type to filter, Return opens the first match, Esc or a background click closes.
@MainActor
final class Launchpad {
    static let shared = Launchpad()

    @MainActor @Observable
    final class Model {
        var apps: [AppEntry] = []
        var query = ""
        var iconVersion = 0     // bumped when a custom icon changes, so cells redraw
        var results: [AppEntry] {
            query.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
    }

    private let panel = OverlayPanel()
    private let model = Model()
    private var keyMonitor: Any?

    private init() {
        panel.acceptsKeyboard = true
    }

    func toggle() {
        if panel.isVisible { close() } else { open() }
    }

    private func open() {
        model.apps = AppCatalog.installedApps()   // rescanned each time, so new installs show up
        model.query = ""
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let frame = screen?.frame ?? .zero
        panel.show(LaunchpadView(model: model, size: frame.size) { [weak self] app in
            self?.close()
            if let app { NSWorkspace.shared.openApplication(at: app.url, configuration: NSWorkspace.OpenConfiguration()) }
        }) { _ in frame.origin }
        panel.setFrame(frame, display: true)
        panel.makeKey()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = Int(event.keyCode)   // NSEvent isn't Sendable, so only the key code crosses into the actor
            let handled = MainActor.assumeIsolated { self?.handle(keyCode) == true }
            return handled ? nil : event
        }
    }

    private func handle(_ keyCode: Int) -> Bool {
        switch keyCode {
        case kVK_Escape: close()
        case kVK_Return:
            let first = model.results.first
            close()
            if let first { NSWorkspace.shared.openApplication(at: first.url, configuration: NSWorkspace.OpenConfiguration()) }
        default: return false
        }
        return true
    }

    private func close() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel.orderOut(nil)
    }
}

private struct LaunchpadView: View {
    @Bindable var model: Launchpad.Model
    let size: CGSize
    let onPick: (AppEntry?) -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
                .onTapGesture { onPick(nil) }   // click outside the icons closes, like Launchpad
            VStack(spacing: 24) {
                TextField("Search", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                    .focused($searchFocused)
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(120), spacing: 24), count: 7), spacing: 28) {
                        ForEach(model.results) { app in
                            AppCell(app: app, version: model.iconVersion) { onPick(app) } onIconChange: { model.iconVersion += 1 }
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
            .padding(.top, 60)
        }
        .frame(width: size.width, height: size.height)
        .onAppear { searchFocused = true }
    }
}

private struct AppCell: View {
    let app: AppEntry
    let version: Int
    let onOpen: () -> Void
    let onIconChange: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 6) {
                Image(nsImage: IconProvider.icon(for: app.url)).resizable().frame(width: 80, height: 80)
                Text(app.name).font(.callout).lineLimit(1).frame(width: 110)
            }
        }
        .buttonStyle(.plain)
        .id("\(app.id)-\(version)")
        .contextMenu {
            Button("Change Icon…") {
                IconProvider.chooseCustomIcon(for: app.url)
                onIconChange()
            }
            if IconProvider.hasCustomIcon(app.url) {
                Button("Use Original Icon") {
                    IconProvider.resetIcon(for: app.url)
                    onIconChange()
                }
            }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.url]) }
        }
        .accessibilityLabel(app.name)
    }
}

struct LaunchpadWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "files.launchpad"
    static var name: String { String(localized: "Launchpad") }
    static let category = WidgetCategory.files
    static let symbol = "square.grid.3x3"
    static let supportedSizes: [TileSize] = [.compact]

    static func view(size: TileSize, settings: Settings) -> some View {
        Button { Launchpad.shared.toggle() } label: {
            Image(systemName: "square.grid.3x3.fill").font(.title2).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .help("Launchpad (⌃⌥⌘L)")
        .accessibilityLabel("Open Launchpad")
    }
}
