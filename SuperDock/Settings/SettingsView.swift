import SwiftUI

/// Stored so the bar's "Widget Settings…" menu can open Settings on the right pane.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, placement, widgets, plugins, profiles, appearance, ai, limo, windows, clipboard, about
    static let storageKey = "settings.tab"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .placement: "Placement"
        case .widgets: "Widgets"
        case .plugins: "Plugins"
        case .profiles: "Profiles"
        case .appearance: "Appearance"
        case .ai: "AI & Agents"
        case .limo: "Limo"
        case .windows: "Windows"
        case .clipboard: "Clipboard"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .placement: "dock.rectangle"
        case .widgets: "square.grid.2x2"
        case .plugins: "puzzlepiece.extension"
        case .profiles: "square.stack"
        case .appearance: "paintpalette"
        case .ai: "sparkle"
        case .limo: "face.smiling"
        case .windows: "macwindow.on.rectangle"
        case .clipboard: "list.clipboard"
        case .about: "info.circle"
        }
    }

    /// Sidebar icon tiles, System Settings style, measured off mockup 07.
    var tint: Color {
        switch self {
        case .general, .about: Color(rgb: 0x8E8E93)
        case .placement: Color(rgb: 0x5E6AE8)
        case .widgets: Color(rgb: 0xFF8A3D)
        case .plugins: Color(rgb: 0x2E9E5B)
        case .profiles: Color(rgb: 0x3A9BE0)
        case .appearance: Color(rgb: 0xE5508C)
        case .ai: Color(rgb: 0xF79C1C)
        case .limo: Palette.ink
        case .windows: Color(rgb: 0x2F7CF6)
        case .clipboard: Color(rgb: 0x19A39A)
        }
    }
}

struct SettingsView: View {
    @AppStorage(SettingsTab.storageKey) private var tab = SettingsTab.general

    var body: some View {
        SettingsWindow(tab: $tab)
    }
}

/// The window content with the pane passed in, so the gallery can draw any pane without touching user defaults.
struct SettingsWindow: View {
    @Binding var tab: SettingsTab

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { tab }, set: { if let new = $0 { tab = new } })) {
                ForEach(SettingsTab.allCases) { SettingsSidebarRow(tab: $0).tag($0) }
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) { SettingsSidebarFooter() }
            .navigationSplitViewColumnWidth(min: 200, ideal: 210, max: 260)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            SettingsPaneContent(tab: tab)
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .frame(width: 940, height: 660)
    }
}

/// The pane for one sidebar entry.
struct SettingsPaneContent: View {
    let tab: SettingsTab

    var body: some View {
        content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .general: GeneralSettings()
        case .placement: PlacementSettings()
        case .widgets: WidgetsSettings()
        case .plugins: PluginsSettings()
        case .profiles: ProfilesSettings()
        case .appearance: AppearanceSettings()
        case .ai: AISettings()
        case .limo: LimoSettings()
        case .windows: WindowSettings()
        case .clipboard: ClipboardSettings()
        case .about: AboutSettings()
        }
    }
}

struct SettingsSidebarRow: View {
    let tab: SettingsTab

    var body: some View {
        Label {
            Text(tab.title).font(.system(size: 13))
        } icon: {
            Image(systemName: tab.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(tab.tint.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.16)) }
        }
        .padding(.vertical, 2)
    }
}

struct SettingsSidebarFooter: View {
    var body: some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 12)
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 30, height: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("SuperDock").font(.system(size: 12, weight: .semibold))
                    Text("v\(AppVersion.short)").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

enum AppVersion {
    static let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
}

/// Pane header (big title, one-line explainer, optional trailing control) over the pane's content.
struct SettingsPane<Accessory: View, Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 22, weight: .bold))
                    Text(subtitle).font(.system(size: 12.5)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                accessory
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 4)
            content
        }
    }
}

extension SettingsPane where Accessory == EmptyView {
    init(title: LocalizedStringKey, subtitle: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, accessory: { EmptyView() }, content: content)
    }
}

private struct WindowSettings: View {
    @AppStorage(WindowPrefs.switcherKey) private var switcher = true
    @AppStorage(WindowPrefs.currentSpaceOnlyKey) private var currentSpaceOnly = false
    @AppStorage(WindowPrefs.previewsKey) private var previews = false
    @AppStorage(WindowPrefs.dockNumbersKey) private var dockNumbers = true
    @AppStorage(WindowPrefs.frozenKey) private var frozenAlerts = true
    @State private var hasScreenRecording = Permissions.hasScreenRecording

    var body: some View {
        SettingsPane(title: "Windows", subtitle: "Switch between windows, peek at them from the Dock, jump to apps.") {
            Form {
                Section {
                    Toggle("Window switcher (⌥Tab, ⌥⇧Tab to go back)", isOn: $switcher)
                    Toggle("Only show windows on the current Space", isOn: $currentSpaceOnly).disabled(!switcher)
                }
                Section {
                    Toggle("Show window previews when hovering Dock icons", isOn: Binding(
                        get: { previews },
                        set: { isOn in
                            // Ask for Screen Recording only when the user turns previews on (hard rule 7).
                            previews = isOn && Permissions.requestScreenRecording()
                            hasScreenRecording = Permissions.hasScreenRecording
                        }
                    ))
                    LabeledContent("Screen Recording") {
                        Text(hasScreenRecording ? "Allowed" : "Not allowed — previews show icons only")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Toggle("⌃⌥1–9 opens the app in that Dock position", isOn: $dockNumbers)
                    Toggle("Warn when an app stops responding", isOn: $frozenAlerts)
                }
            }
            .formStyle(.grouped)
        }
    }
}

private struct ClipboardSettings: View {
    @AppStorage(ClipboardPrefs.historyKey) private var history = true
    @AppStorage(ClipboardPrefs.pasteDirectlyKey) private var pasteDirectly = true
    @AppStorage(ClipboardPrefs.peekKey) private var peek = true
    @AppStorage(ClipboardPrefs.notchKey) private var notch = true
    @AppStorage(ClipboardPrefs.notchStyleKey) private var notchStyle = NotchShelf.Style.full
    @State private var confirmClear = false
    private let hasNotch = NSScreen.screens.contains { $0.safeAreaInsets.top > 0 }

    var body: some View {
        SettingsPane(title: "Clipboard", subtitle: "History, Copy Peek and the notch shelf. Everything stays on this Mac.") {
            Form {
                Section {
                    Toggle("Keep clipboard history (⌥⌘V)", isOn: $history)
                    Text("""
                        Stored only on this Mac. Items that password managers mark as concealed or transient are never \
                        read or saved. ⌥⌘V replaces Finder's "Move Item Here" shortcut while history is on.
                        """)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Paste straight into the app when choosing an item", isOn: $pasteDirectly).disabled(!history)
                    Toggle("Copy Peek: show what was just copied", isOn: $peek).disabled(!history)
                }
                Section("Notch") {
                    Toggle("Recent copies under the notch", isOn: $notch).disabled(!history || !hasNotch)
                    Picker("Style", selection: $notchStyle) {
                        Text("Full: hover the notch to show a wide shelf").tag(NotchShelf.Style.full)
                        Text("Icon only: a small icon beside the notch, nothing else").tag(NotchShelf.Style.icon)
                    }
                    .pickerStyle(.radioGroup)
                    .disabled(!history || !notch || !hasNotch)
                    if !hasNotch {
                        Text("This Mac's displays don't have a notch.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Pinned items") {
                    Text("Right-click an item in the history to pin it to ⌃⌥⌘1–9 for one-keystroke pasting.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Clear History…", role: .destructive) { confirmClear = true }
                        .confirmationDialog("Clear clipboard history? Pinned items are kept.", isPresented: $confirmClear) {
                            Button("Clear History", role: .destructive) { ClipboardStore.shared.clearUnpinned() }
                        }
                }
            }
            .formStyle(.grouped)
        }
    }
}

private struct AISettings: View {
    @State private var claudeConnected = ClaudeStatusLineBridge.standard.isConnected
    @State private var error: String?

    var body: some View {
        SettingsPane(title: "AI & Agents", subtitle: "Usage limits and live sessions. SuperDock reads status and percentages only.") {
            Form {
                Section("Claude Code limits") {
                    Text("""
                        Claude Code only shares its 5-hour and weekly usage with its status line. Connecting adds a small \
                        script in front of your current status line: it saves just those percentages for SuperDock, then \
                        runs your status line exactly as before. Nothing from your prompts or code is saved.
                        """)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    LabeledContent(claudeConnected ? "Connected" : "Not connected") {
                        Button(claudeConnected ? "Disconnect" : "Connect Claude Code", action: toggleClaude)
                    }
                    if let error { Text(error).font(.caption).foregroundStyle(.red) }
                }
                Section("Codex") {
                    Text("Limits and sessions are read from ~/.codex/sessions automatically. No setup needed.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Text("Limo's agent alerts are in the Limo pane. Cursor and Antigravity aren't supported yet.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }

    private func toggleClaude() {
        let bridge = ClaudeStatusLineBridge.standard
        do {
            if claudeConnected { try bridge.disconnect() } else { try bridge.connect() }
            error = nil
        } catch ClaudeStatusLineBridge.BridgeError.changedSinceConnect {
            error = String(localized: "Your Claude status line was changed after connecting, so SuperDock left it alone.")
        } catch {
            self.error = String(localized: "Couldn't update ~/.claude/settings.json: \(error.localizedDescription)")
        }
        claudeConnected = bridge.isConnected
    }
}

private struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("SuperDock").font(.system(size: 26, weight: .bold))
            Text("Version \(AppVersion.short)").foregroundStyle(.secondary)
            Text("Free. Local-first. No accounts, no analytics.").padding(.top, 4)
            HStack(spacing: 10) {
                CheckForUpdatesButton()
                Link("GitHub", destination: Links.repo)
                Link("MIT License", destination: Links.license)
            }
            .padding(.top, 10)
            if !Updates.isConfigured {
                Text("Updates are checked in release builds only.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private enum Links {
        static let repo = URL(string: "https://github.com/apurvamukherjee/SuperDoc") ?? URL(fileURLWithPath: "/")
        static let license = URL(string: "https://github.com/apurvamukherjee/SuperDoc/blob/main/LICENSE")
            ?? URL(fileURLWithPath: "/")
    }
}
