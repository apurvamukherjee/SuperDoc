import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Full-screen app grid with search, in pages: type to filter, Return opens the first match, ←/→ turn pages,
/// Esc or a background click closes.
@MainActor
final class Launchpad {
    static let shared = Launchpad()

    @MainActor @Observable
    final class Model {
        var apps: [AppEntry] = []
        var query = ""
        var page: Int? = 0
        var pageCount = 1
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
        model.page = 0
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let frame = screen?.frame ?? .zero
        panel.show(LaunchpadView(model: model, size: frame.size, icon: IconProvider.icon(for:)) { [weak self] app in
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
        // Arrows only turn pages while the search is empty; otherwise they move the text cursor.
        case kVK_LeftArrow where model.query.isEmpty: turn(by: -1)
        case kVK_RightArrow where model.query.isEmpty: turn(by: 1)
        default: return false
        }
        return true
    }

    private func turn(by delta: Int) {
        withAnimation(Motion.settle) { model.page = min(max((model.page ?? 0) + delta, 0), model.pageCount - 1) }
    }

    private func close() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel.orderOut(nil)
    }
}

struct LaunchpadView: View {
    @Bindable var model: Launchpad.Model
    let size: CGSize
    let icon: @MainActor (URL) -> NSImage
    let onPick: (AppEntry?) -> Void

    @Environment(\.surfaceSnapshot) private var snapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool

    private static let columns = 7
    private static let cell = CGSize(width: 112, height: 112)

    private var rows: Int { max(2, min(5, Int((size.height - 220) / (Self.cell.height + 18)))) }

    private var pages: [[AppEntry]] {
        let perPage = Self.columns * rows
        let results = model.results
        return stride(from: 0, to: max(results.count, 1), by: perPage).map { Array(results[$0..<min($0 + perPage, results.count)]) }
    }

    var body: some View {
        let pages = pages
        ZStack {
            backdrop.onTapGesture { onPick(nil) }   // click outside the icons closes, like Launchpad
            VStack(spacing: 28) {
                SurfaceSearchField(prompt: "Search apps", text: $model.query, focus: $searchFocused, height: 32)
                    .frame(width: 300)
                    .onChange(of: model.query) { model.page = 0 }
                pager(pages)
                dots(pages.count)
            }
            .padding(.top, size.height * 0.08)
            .padding(.bottom, 36)
        }
        .frame(width: size.width, height: size.height)
        // Always a dark, dimmed desktop, whatever the bar's style.
        .tileContext(TileContext(unit: SurfaceKit.unit, surface: SurfaceTokens(.glassDark)))
        .onAppear { searchFocused = true }
        .onChange(of: pages.count, initial: true) { model.pageCount = pages.count }
    }

    @ViewBuilder
    private var backdrop: some View {
        if snapshot != nil {
            Color.black.opacity(0.35)
        } else {
            LaunchpadBlur().overlay(Color.black.opacity(0.25))
        }
    }

    @ViewBuilder
    private func pager(_ pages: [[AppEntry]]) -> some View {
        if snapshot != nil {
            grid(pages[0]).frame(maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { index in
                        grid(pages[index]).containerRelativeFrame(.horizontal).id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.never)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $model.page)
        }
    }

    private func grid(_ apps: [AppEntry]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(Self.cell.width), spacing: 28), count: Self.columns), spacing: 18) {
            ForEach(apps) { app in
                AppCell(app: app, icon: icon(app.url), version: model.iconVersion) { onPick(app) } onIconChange: {
                    model.iconVersion += 1
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func dots(_ count: Int) -> some View {
        HStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { index in
                Button {
                    withAnimation(reduceMotion ? Motion.reduced : Motion.settle) { model.page = index }
                } label: {
                    Circle().fill(.white.opacity(index == (model.page ?? 0) ? 0.95 : 0.35)).frame(width: 7, height: 7)
                        .padding(3).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Page \(index + 1)")
            }
        }
        .opacity(count > 1 ? 1 : 0)
    }
}

/// The dimmed, blurred desktop behind the grid.
private struct LaunchpadBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct AppCell: View {
    @Environment(\.tile) private var tile
    let app: AppEntry
    let icon: NSImage
    let version: Int
    let onOpen: () -> Void
    let onIconChange: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 8) {
                Image(nsImage: icon).resizable().frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                Text(app.name).font(tile.font(.body).weight(.medium)).foregroundStyle(.white)
                    .lineLimit(1).frame(width: 108)
            }
        }
        .buttonStyle(TilePressStyle())
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
