import SwiftUI

/// Stored so the bar's "Widget Settings…" menu can open Settings on the right tab.
enum SettingsTab: String {
    case placement, widgets, profiles, appearance, windows, clipboard, ai, about
    static let storageKey = "settings.tab"
}

struct SettingsView: View {
    @AppStorage(SettingsTab.storageKey) private var tab = SettingsTab.placement

    var body: some View {
        TabView(selection: $tab) {
            PlacementSettings().tabItem { Label("Placement", systemImage: "dock.rectangle") }.tag(SettingsTab.placement)
            WidgetsSettings().tabItem { Label("Widgets", systemImage: "square.grid.2x2") }.tag(SettingsTab.widgets)
            ProfilesSettings().tabItem { Label("Profiles", systemImage: "person.crop.rectangle.stack") }.tag(SettingsTab.profiles)
            AppearanceSettings().tabItem { Label("Appearance", systemImage: "paintbrush") }.tag(SettingsTab.appearance)
            WindowSettings().tabItem { Label("Windows", systemImage: "macwindow.on.rectangle") }.tag(SettingsTab.windows)
            ClipboardSettings().tabItem { Label("Clipboard", systemImage: "list.clipboard") }.tag(SettingsTab.clipboard)
            AISettings().tabItem { Label("AI", systemImage: "sparkles") }.tag(SettingsTab.ai)
            AboutSettings().tabItem { Label("About", systemImage: "info.circle") }.tag(SettingsTab.about)
        }
        .frame(width: 480)
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

private struct ClipboardSettings: View {
    @AppStorage(ClipboardPrefs.historyKey) private var history = true
    @AppStorage(ClipboardPrefs.pasteDirectlyKey) private var pasteDirectly = true
    @AppStorage(ClipboardPrefs.peekKey) private var peek = true
    @AppStorage(ClipboardPrefs.notchKey) private var notch = true
    @AppStorage(ClipboardPrefs.notchStyleKey) private var notchStyle = NotchShelf.Style.full
    @State private var confirmClear = false
    private let hasNotch = NSScreen.screens.contains { $0.safeAreaInsets.top > 0 }

    var body: some View {
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
                if !hasNotch { Text("This Mac's displays don't have a notch.").font(.caption).foregroundStyle(.secondary) }
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

private struct AISettings: View {
    @AppStorage(BuddyController.enabledKey) private var buddyAlerts = true
    @State private var claudeConnected = ClaudeStatusLineBridge.standard.isConnected
    @State private var error: String?

    var body: some View {
        Form {
            Section("Claude Code limits") {
                Text("""
                    Claude Code only shares its 5-hour and weekly usage with its status line. Connecting adds a small \
                    script in front of your current status line: it saves just those percentages for SuperDock, then runs \
                    your status line exactly as before. Nothing from your prompts or code is saved.
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
            Section("Buddy") {
                Toggle("Pop up when an agent finishes or needs your input", isOn: $buddyAlerts)
            }
            Section {
                Text("Cursor and Antigravity aren't supported yet.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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

private struct WidgetsSettings: View {
    @Bindable private var store = LayoutStore.shared
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List {
                ForEach($store.tiles) { $tile in
                    TileRow(tile: $tile) { store.remove(tile.id) }
                }
                .onMove { store.tiles.move(fromOffsets: $0, toOffset: $1) }
            }
            .frame(minHeight: 300)
            HStack {
                Text("Drag to reorder, here or on the bar. Right-click a tile on the bar for quick options.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add Widget…") { showingPicker = true }
            }
        }
        .padding(20)
        .sheet(isPresented: $showingPicker) {
            WidgetPicker { store.add($0.id, size: $0.supportedSizes[0]) }
        }
    }
}

private struct TileRow: View {
    @Binding var tile: Tile
    let remove: () -> Void

    var body: some View {
        let widget = WidgetRegistry.widget(tile.widgetId)
        let name = widget?.name ?? tile.widgetId
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(name, systemImage: widget?.symbol ?? "questionmark.square.dashed")
                Spacer()
                if let widget, widget.supportedSizes.count > 1 {
                    Picker("Size", selection: $tile.size) {
                        ForEach(widget.supportedSizes) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Button(action: remove) { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove \(name)")
            }
            if let editor = widget?.settingsEditor($tile.settings) {
                editor.padding(.leading, 28)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PlacementSettings: View {
    @AppStorage(BarPrefs.positionKey) private var position = BarPrefs.defaultPosition
    @AppStorage(BarPrefs.gapKey) private var gap = BarPrefs.defaultGap
    @AppStorage(DockReplacement.enabledKey) private var replaceDock = false

    var body: some View {
        Form {
            Toggle("Replace the system Dock", isOn: Binding(get: { replaceDock }, set: { isOn in
                replaceDock = isOn
                if isOn { DockReplacement.standard.apply() } else { DockReplacement.standard.restore() }
            }))
            Text("""
                Hides the macOS Dock and shows your apps in SuperDock's bar instead. Your Dock settings are saved \
                first and put back when you turn this off or quit SuperDock.
                """)
                .font(.caption).foregroundStyle(.secondary)
            Picker("Position", selection: $position) {
                Text("Left of the Dock (above it when the Dock is on a side)").tag(BarPosition.leading)
                Text("Right of the Dock (below it when the Dock is on a side)").tag(BarPosition.trailing)
                Text("Above the Dock (beside it when the Dock is on a side)").tag(BarPosition.outside)
            }
            .pickerStyle(.radioGroup)
            .disabled(replaceDock)
            LabeledContent("Gap") {
                HStack {
                    Slider(value: $gap, in: 0...32, step: 1)
                    Text("\(Int(gap)) pt").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
            }
        }
        .padding(20)
    }
}

private struct ProfilesSettings: View {
    @Bindable private var store = LayoutStore.shared
    @State private var newName = ""

    var body: some View {
        Form {
            Section {
                ForEach(store.profiles) { profile in
                    HStack {
                        TextField("Name", text: Binding(get: { profile.name }, set: { store.rename(profile.id, to: $0) }))
                            .textFieldStyle(.plain)
                        Spacer()
                        if profile.id == store.activeProfile.id {
                            Text("Active").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Button("Use") { store.activate(profile.id) }.controlSize(.small)
                        }
                        Button(role: .destructive) { store.deleteProfile(profile.id) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .disabled(store.profiles.count == 1)
                            .accessibilityLabel("Delete \(profile.name)")
                    }
                }
                HStack {
                    TextField("New profile, e.g. Code", text: $newName)
                    Button("Add") {
                        store.addProfile(named: newName.trimmingCharacters(in: .whitespaces))
                        newName = ""
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("""
                    Each profile has its own tiles. The laptop screen and external displays remember their own active \
                    profile and switch automatically. ⌃⌥⌘P cycles profiles; the menu bar icon lists them too. A new \
                    profile starts as a copy of the current one.
                    """)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AppearanceSettings: View {
    @AppStorage(AppearancePrefs.styleKey) private var style = BarStyle.glass
    @AppStorage(AppearancePrefs.cornerRadiusKey) private var cornerRadius = AppearancePrefs.defaultCornerRadius
    @AppStorage(AppearancePrefs.opacityKey) private var opacity = 1.0
    @AppStorage(AppearancePrefs.accentKey) private var accent = ""
    @AppStorage(AppearancePrefs.tileBackgroundsKey) private var tileBackgrounds = true
    @AppStorage(LiveWallpaper.kindKey) private var wallpaper = LiveWallpaper.Kind.off
    @AppStorage(LiveWallpaper.videoKey) private var videoPath = ""

    var body: some View {
        Form {
            Section("Bar") {
                Picker("Style", selection: $style) {
                    ForEach(BarStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                LabeledContent("Corner radius") { Slider(value: $cornerRadius, in: 4...28, step: 1) }
                LabeledContent("Background opacity") { Slider(value: $opacity, in: 0.3...1) }
                Toggle("Tile backgrounds", isOn: $tileBackgrounds)
                HStack {
                    ColorPicker("Accent color", selection: Binding(
                        get: { Color(hex: accent) ?? .accentColor },
                        set: { accent = $0.hexString ?? "" }
                    ), supportsOpacity: false)
                    if !accent.isEmpty { Button("Use System") { accent = "" }.controlSize(.small) }
                }
                Text("Reduce Transparency in Accessibility settings switches see-through styles to solid.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Live wallpaper") {
                Picker("Wallpaper", selection: $wallpaper) {
                    Text("Off").tag(LiveWallpaper.Kind.off)
                    Text("Aurora (animated)").tag(LiveWallpaper.Kind.aurora)
                    Text("Video file").tag(LiveWallpaper.Kind.video)
                }
                if wallpaper == .video {
                    LabeledContent(videoPath.isEmpty ? "No video chosen" : (videoPath as NSString).lastPathComponent) {
                        Button("Choose MP4 or MOV…") {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
                            if panel.runModal() == .OK, let url = panel.url { videoPath = url.path }
                        }
                    }
                }
                Text("Pauses while the displays sleep. Uses more battery than a still wallpaper.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

extension Color {
    /// "#RRGGBB" in sRGB, for saving a picked color.
    var hexString: String? {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
    }
}

private struct AboutSettings: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "dock.rectangle")
                .font(.system(size: 48))
                .accessibilityHidden(true)
            Text("SuperDock").font(.title.bold())
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("Free. Local-first. No accounts.")
        }
        .padding(40)
    }
}
