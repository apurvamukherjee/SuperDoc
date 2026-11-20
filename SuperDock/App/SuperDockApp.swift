import SwiftUI

@main
struct SuperDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let updates = Updates.shared

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
        // Section headers are plain text in an NSMenu; the agents/limit summary rides along when there's data.
        Section(MenuStatus.title(sessions: AgentSessionService.shared.sessions, usage: AIUsageService.shared.usage)) {
            Picker("Profile: \(store.activeProfile.name)",
                   selection: Binding(get: { store.activeProfile.id }, set: { store.activate($0) })) {
                ForEach(store.profiles) { Text($0.name).tag($0.id) }
            }
            Button("Launchpad") { Launchpad.shared.toggle() }
        }
        Divider()
        Button("Settings…") {
            // Agent apps are never frontmost, so without this the window opens behind other apps.
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        CheckForUpdatesButton()
        Divider()
        Button("Quit SuperDock") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
