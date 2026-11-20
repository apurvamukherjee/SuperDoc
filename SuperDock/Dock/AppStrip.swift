import AppKit
import Observation
import SwiftUI
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "app-strip")

/// SuperDock's own app strip for Dock replacement mode: pinned apps, then running apps that aren't pinned, then Trash.
@MainActor @Observable
final class AppStrip {
    static let shared = AppStrip()
    private static let pinnedKey = "dock.pinnedApps"

    struct Item: Identifiable, Equatable {
        var id: URL { url }
        var url: URL
        var isRunning: Bool
        var isPinned: Bool
    }

    private(set) var items: [Item] = []
    /// Called when the item count changes so the bar can resize.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private var pinned: [URL] {
        get { (UserDefaults.standard.stringArray(forKey: Self.pinnedKey) ?? []).map(URL.init(fileURLWithPath:)) }
        set { UserDefaults.standard.set(newValue.map(\.path), forKey: Self.pinnedKey) }
    }

    private init() {
        // First use starts from whatever is pinned in the system Dock.
        if UserDefaults.standard.stringArray(forKey: Self.pinnedKey) == nil {
            pinned = DockReplacement.standard.nativePinnedApps()
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.rebuild() }
            })
        }
        rebuild()
    }

    func pin(_ url: URL) {
        pinned.append(url)
        rebuild()
    }

    func unpin(_ url: URL) {
        pinned.removeAll { $0 == url }
        rebuild()
    }

    private func rebuild() {
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.compactMap(\.bundleURL)
        let pinnedURLs = pinned
        let next = pinnedURLs.map { Item(url: $0, isRunning: running.contains($0), isPinned: true) }
            + running.filter { !pinnedURLs.contains($0) }.map { Item(url: $0, isRunning: true, isPinned: false) }
        guard next != items else { return }
        let countChanged = next.count != items.count
        items = next
        if countChanged { onChange?() }
    }
}

/// Icons at the Dock's own icon size (the bar's unit), running dots in the padding below, a small magnify on hover.
struct AppStripView: View {
    let items: [AppStrip.Item]
    let context: TileContext

    var body: some View {
        let stack = context.isPortrait ? AnyLayout(VStackLayout(spacing: TileContext.spacing))
                                       : AnyLayout(HStackLayout(spacing: TileContext.spacing))
        stack {
            ForEach(items) { item in
                AppIcon(item: item, context: context)
            }
            TrashIcon(context: context)
        }
    }
}

/// The hover magnification. The panel is exactly bar-sized, so an icon may only grow into the padding above it.
private func magnification(unit: CGFloat) -> CGFloat { 1 + (TileContext.spacing - 1) / unit }

private struct AppIcon: View {
    let item: AppStrip.Item
    let context: TileContext
    @State private var isHovered = false

    var body: some View {
        Button {
            NSWorkspace.shared.openApplication(at: item.url, configuration: NSWorkspace.OpenConfiguration())
        } label: {
            Image(nsImage: IconProvider.icon(for: item.url)).resizable().scaledToFit()
                .frame(width: context.unit, height: context.unit)
                .scaleEffect(isHovered ? magnification(unit: context.unit) : 1, anchor: .bottom)
                .tileAnimation(Motion.lift, value: isHovered)
                .overlay(alignment: .bottom) {
                    if item.isRunning {
                        // Centred in the padding under the icon, where the native Dock puts it.
                        Circle().fill(context.surface.primary.opacity(0.85)).frame(width: 4, height: 4)
                            .offset(y: TileContext.spacing / 2 + 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(FileManager.default.displayName(atPath: item.url.path))
        .accessibilityLabel(FileManager.default.displayName(atPath: item.url.path) + (item.isRunning ? ", running" : ""))
        .contextMenu {
            if item.isPinned {
                Button("Remove from Dock") { AppStrip.shared.unpin(item.url) }
            } else {
                Button("Keep in Dock") { AppStrip.shared.pin(item.url) }
            }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Button("Change Icon…") { IconProvider.chooseCustomIcon(for: item.url) }
            if item.isRunning {
                Divider()
                Button("Quit") {
                    NSWorkspace.shared.runningApplications.first { $0.bundleURL == item.url }?.terminate()
                }
            }
        }
    }
}

/// Click opens the Trash; dropping files moves them to the Trash (never deletes them, hard rule 8).
private struct TrashIcon: View {
    let context: TileContext
    @State private var isTargeted = false
    @State private var isHovered = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appending(path: ".Trash"))
        } label: {
            Image(nsImage: NSImage(named: isTargeted ? NSImage.trashFullName : NSImage.trashEmptyName) ?? NSImage())
                .resizable().scaledToFit()
                .frame(width: context.unit, height: context.unit)
                .scaleEffect(isHovered || isTargeted ? magnification(unit: context.unit) : 1, anchor: .bottom)
                .tileAnimation(Motion.lift, value: isHovered || isTargeted)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .dropDestination(for: URL.self) { urls, _ in
            for url in urls where url.isFileURL {
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                } catch {
                    log.error("Couldn't move \(url.lastPathComponent) to the Trash: \(error)")
                }
            }
            return true
        } isTargeted: { isTargeted = $0 }
        .accessibilityLabel("Trash")
    }
}
