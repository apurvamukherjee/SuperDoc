import SwiftUI
import Sparkle

@main
struct SuperDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Not started until Phase 9 adds SUFeedURL + SUPublicEDKey; starting without them errors on every check.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
    )

    var body: some Scene {
        MenuBarExtra("SuperDock", image: "MenuBarIcon") {
            MenuContent()
        }
        Settings {
            SettingsView()
        }
    }
}

private struct MenuContent: View {
    @Environment(\.openSettings) private var openSettings

    private let store = LayoutStore.shared

    var body: some View {
        Picker("Profile", selection: Binding(get: { store.activeProfile.id }, set: { store.activate($0) })) {
            ForEach(store.profiles) { Text($0.name).tag($0.id) }
        }
        Button("Launchpad") { Launchpad.shared.toggle() }
        Divider()
        Button("Settings…") {
            // Agent apps are never frontmost, so without this the window opens behind other apps.
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit SuperDock") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
