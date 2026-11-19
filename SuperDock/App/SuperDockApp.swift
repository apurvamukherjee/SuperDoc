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

    var body: some View {
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
