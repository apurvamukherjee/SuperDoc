import AppKit
import SwiftUI

/// Settings → Profiles.
struct ProfilesSettings: View {
    @Bindable private var store = LayoutStore.shared
    @State private var newName = ""

    var body: some View {
        SettingsPane(title: "Profiles", subtitle: "Named layouts. The laptop screen and external displays each keep their own.") {
            Form {
                Section {
                    ForEach(store.profiles) { profile in
                        row(profile)
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

    private func row(_ profile: Profile) -> some View {
        let isActive = profile.id == store.activeProfile.id
        return HStack(spacing: 10) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                TextField("Name", text: Binding(get: { profile.name }, set: { store.rename(profile.id, to: $0) }))
                    .textFieldStyle(.plain)
                Text("\(profile.tiles.count) tiles").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isActive {
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
}

/// Settings → Appearance: bar theme and live wallpaper, with the user's own tiles as a live preview.
struct AppearanceSettings: View {
    @AppStorage(AppearancePrefs.styleKey) private var style = BarStyle.glass
    @AppStorage(AppearancePrefs.cornerRadiusKey) private var cornerRadius = AppearancePrefs.defaultCornerRadius
    @AppStorage(AppearancePrefs.opacityKey) private var opacity = 1.0
    @AppStorage(AppearancePrefs.accentKey) private var accent = ""
    @AppStorage(AppearancePrefs.tileBackgroundsKey) private var tileBackgrounds = true
    @AppStorage(LiveWallpaper.kindKey) private var wallpaper = LiveWallpaper.Kind.off
    @AppStorage(LiveWallpaper.videoKey) private var videoPath = ""

    var body: some View {
        SettingsPane(title: "Appearance", subtitle: "How the bar looks. The preview is your bar with your tiles.") {
            Form {
                Section {
                    PreviewBar(tiles: previewTiles)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(PreviewWallpaper(cornerRadius: 0))
                        .listRowInsets(EdgeInsets())
                }
                Section("Bar") {
                    LabeledContent("Style") {
                        HStack(spacing: 8) {
                            ForEach(BarStyle.allCases, id: \.self) { option in
                                StyleSwatch(style: option, isSelected: option == style) { style = option }
                            }
                        }
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

    /// The start of the user's bar, up to what fits the preview; the starter tiles when the bar is empty.
    private var previewTiles: [PreviewTile] {
        let tiles = LayoutStore.shared.tiles.isEmpty ? LayoutStore.starterTiles : LayoutStore.shared.tiles
        var columns = 0
        return tiles.prefix { tile in
            columns += tile.size.columns
            return columns <= 7
        }
        .map(PreviewTile.init)
    }
}

/// One bar style as a small sample of its bar fill over its wallpaper.
private struct StyleSwatch: View {
    let style: BarStyle
    let isSelected: Bool
    let select: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let surface = SurfaceStyle.resolve(style, isDark: colorScheme == .dark, reduceTransparency: false)
        let tokens = SurfaceTokens(surface)
        let frame = RoundedRectangle(cornerRadius: 7, style: .continuous)
        Button(action: select) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(tokens.barFill)
                    .overlay { RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(tokens.barStroke) }
                    .padding(8)
                    .frame(width: 64, height: 38)
                    .background(LinearGradient(colors: PreviewWallpaper.colors(surface).map { Color(rgb: $0) },
                                               startPoint: .topLeading, endPoint: .bottomTrailing), in: frame)
                    .overlay {
                        frame.strokeBorder(isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                                           lineWidth: isSelected ? 2 : 1)
                    }
                Text(style.title).font(.system(size: 10.5)).foregroundStyle(isSelected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(style.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension Color {
    /// "#RRGGBB" in sRGB, for saving a picked color.
    var hexString: String? {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
    }
}
