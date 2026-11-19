import AppKit
import SwiftUI

/// Settings → Profiles.
struct ProfilesSettings: View {
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

/// Settings → Appearance: bar theme and live wallpaper.
struct AppearanceSettings: View {
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
