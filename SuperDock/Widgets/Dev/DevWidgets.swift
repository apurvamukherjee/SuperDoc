import AppKit
import SwiftUI

/// Copies text; `concealed` marks it the way password managers do, so clipboard histories (ours included) skip it.
@MainActor
private func copy(_ text: String, concealed: Bool = false) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    if concealed { pasteboard.setData(Data(), forType: .init("org.nspasteboard.ConcealedType")) }
}

struct UUIDWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "dev.uuid"
    static var name: String { String(localized: "UUID") }
    static let category = WidgetCategory.dev
    static let symbol = "number.square"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        GenerateTile(concealed: false) { UUID().uuidString.lowercased() } content: { value, copied in
            UUIDView(value: value, copied: copied)
        }
    }
}

struct PasswordWidget: SuperWidget {
    struct Settings: Codable, Equatable { var length = 20 }
    static let id = "dev.password"
    static var name: String { String(localized: "Password Generator") }
    static let category = WidgetCategory.dev
    static let symbol = "key"
    static let supportedSizes: [TileSize] = [.compact, .medium]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        GenerateTile(concealed: true) { DevParsing.password(length: settings.length) } content: { value, copied in
            PasswordView(length: settings.length, password: value, copied: copied)
        }
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(Stepper("Length: \(settings.wrappedValue.length)", value: settings.length, in: 8...64))
    }
}

/// Tap to generate and copy. "Copied" shows for 1.5 s, then the tile rests. A password stays readable for a minute
/// only, so it isn't left on screen for anyone walking past or watching a screen share.
private struct GenerateTile<Content: View>: View {
    let concealed: Bool
    let generate: () -> String
    @ViewBuilder let content: (_ value: String?, _ copied: Bool) -> Content
    @State private var value: String?
    @State private var copiedAt: Date?

    var body: some View {
        Button {
            let next = generate()
            copy(next, concealed: concealed)
            value = next
            copiedAt = Date()
        } label: {
            content(value, copiedAt != nil).contentShape(Rectangle())
        }
        .buttonStyle(TilePressStyle())
        .tileAnimation(Motion.pop, value: copiedAt != nil)
        .task(id: copiedAt) {
            guard copiedAt != nil else { return }
            do {
                try await Task.sleep(for: .seconds(1.5))
                copiedAt = nil
                if concealed {
                    try await Task.sleep(for: .seconds(60))
                    value = nil
                }
            } catch {
                return   // tile went away or was tapped again
            }
        }
    }
}

/// The check that pops in once when something lands on the clipboard (a crossfade under Reduce Motion).
private struct CopiedMark: View {
    @Environment(\.tile) private var tile
    var size: CGFloat

    var body: some View {
        Image(systemName: "checkmark").font(.system(size: size * tile.scale, weight: .bold))
            .foregroundStyle(tile.surface.good)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
    }
}

struct UUIDView: View {
    @Environment(\.tile) private var tile
    var value: String?
    var copied: Bool

    var body: some View {
        Group {
            if tile.isCompact || tile.isPortrait {
                VStack(spacing: 5 * tile.scale) {
                    Spacer(minLength: 0)
                    if copied {
                        CopiedMark(size: 20)
                    } else {
                        braces
                    }
                    Spacer(minLength: 0)
                    Text(copied ? "Copied" : "Tap · UUID").tileStyle(.caption, color: copied ? tile.surface.good : nil)
                }
                .padding(.vertical, 3 * tile.scale)
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 10 * tile.scale) {
                    if !copied { braces.padding(.leading, 4 * tile.scale) }
                    VStack(alignment: .leading, spacing: 4 * tile.scale) {
                        HStack(spacing: 5 * tile.scale) {
                            if copied { CopiedMark(size: 12) }
                            Text(copied ? "Copied" : "UUID").tileStyle(.title, color: copied ? tile.surface.good : nil)
                        }
                        Text(value ?? "Tap to generate & copy").tileStyle(value == nil ? .detail : .mono)
                            .truncationMode(.tail)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 4 * tile.scale)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tileTint(copied ? Palette.good : nil, opacity: 0.16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copied ? "UUID copied" : "Generate and copy UUID")
        .accessibilityAddTraits(.isButton)
    }

    private var braces: some View {
        Text("{ id }").font(.system(size: 17 * tile.scale, weight: .bold, design: .monospaced))
            .foregroundStyle(Palette.codex).lineLimit(1).fixedSize()
    }
}

struct PasswordView: View {
    @Environment(\.tile) private var tile
    var length: Int
    var password: String?
    var copied: Bool

    var body: some View {
        Group {
            if tile.isCompact || tile.isPortrait { compact } else { regular }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tileTint(copied && (tile.isCompact || tile.isPortrait) ? Palette.good : nil, opacity: 0.16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copied ? "Password copied" : "Generate and copy password, \(length) characters")
        .accessibilityAddTraits(.isButton)
    }

    private var compact: some View {
        VStack(spacing: 6 * tile.scale) {
            Spacer(minLength: 0)
            if copied {
                CopiedMark(size: 20)
            } else {
                Image(systemName: "key").font(.system(size: 19 * tile.scale, weight: .semibold))
                    .foregroundStyle(Palette.amber).rotationEffect(.degrees(-45))
            }
            Spacer(minLength: 0)
            Text(copied ? "Copied" : "••••••")
                .tileStyle(copied ? .caption : .title, color: copied ? tile.surface.good : nil)
                .tracking(copied ? 1 : 2.5 * tile.scale)
        }
        .padding(.vertical, 3 * tile.scale)
    }

    private var regular: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Password · \(length)").tileStyle(.label)
                Spacer(minLength: 4)
                Group {
                    if copied {
                        CopiedMark(size: 10)
                    } else {
                        Image(systemName: "doc.on.doc").font(.system(size: 10 * tile.scale, weight: .medium))
                            .foregroundStyle(tile.surface.secondary)
                    }
                }
                .frame(height: 11 * tile.scale)
            }
            Spacer(minLength: 0)
            Group {
                if let password {
                    Text(colored(password))
                } else {
                    Text("Tap to generate").foregroundStyle(tile.surface.tertiary)
                }
            }
            .font(.system(size: 13 * tile.scale, weight: .semibold, design: .monospaced))
            .lineLimit(1).minimumScaleFactor(0.8).truncationMode(.tail)
            Spacer(minLength: 0)
            StrengthBar(segments: Self.strength(length: length))
        }
        .padding(.horizontal, 2 * tile.scale)
    }

    /// Digits blue and symbols amber, like a terminal's syntax colours, so look-alike characters are easier to tell apart.
    private func colored(_ password: String) -> AttributedString {
        var text = AttributedString()
        for character in password {
            var run = AttributedString(String(character))
            run.foregroundColor = character.isNumber ? Palette.progress
                : character.isLetter ? tile.surface.primary : Palette.amber
            text += run
        }
        return text
    }

    /// Filled segments out of 4, from the password's entropy (about 25 bits per segment).
    static func strength(length: Int) -> Int {
        let bits = Double(length) * log2(Double(DevParsing.passwordAlphabet.count))
        return min(max(Int(bits / 25), 1), 4)
    }
}

private struct StrengthBar: View {
    @Environment(\.tile) private var tile
    var segments: Int

    var body: some View {
        let color = segments >= 4 ? Palette.good : segments == 3 ? Palette.amber : Palette.coral
        HStack(spacing: 3 * tile.scale) {
            ForEach(0..<4, id: \.self) { index in
                Capsule().fill(index < segments ? color : tile.surface.track)
            }
        }
        .frame(height: 3.5 * tile.scale)
        .accessibilityHidden(true)
    }
}

struct PortsWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "dev.ports"
    static var name: String { String(localized: "Local Ports") }
    static let category = WidgetCategory.dev
    static let symbol = "point.3.connected.trianglepath.dotted"
    static let supportedSizes: [TileSize] = [.medium, .wide]

    static func view(size: TileSize, settings: Settings) -> some View {
        PortsTile()
    }
}

private struct PortsTile: View {
    @State private var ports: [DevParsing.ListeningPort]?

    var body: some View {
        PortsView(ports: ports) { port in
            if let url = URL(string: "http://localhost:\(port.port)") { NSWorkspace.shared.open(url) }
        }
        .task {
            while !Task.isCancelled {
                // lsof exits non-zero when nothing listens, which runCommand reports as nil.
                ports = await runCommand("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN"])
                    .map(DevParsing.listeningPorts(fromLsof:)) ?? []
                do {
                    try await Task.sleep(for: .seconds(10))
                } catch {
                    return
                }
            }
        }
    }
}

/// The List archetype in mono: green port, process trailing, "+N more". Each row opens localhost.
struct PortsView: View {
    @Environment(\.tile) private var tile
    /// nil while the first `lsof` runs.
    var ports: [DevParsing.ListeningPort]?
    var onOpen: (DevParsing.ListeningPort) -> Void = { _ in }

    private var columns: Int { tile.isPortrait ? 1 : max(tile.columns - 1, 1) }
    private var perColumn: Int { tile.isPortrait ? max(Int(tile.contentSize.height / (22 * tile.scale)), 2) : 3 }

    var body: some View {
        if let ports {
            if ports.isEmpty {
                TileStateView(state: .empty(title: "No ports", detail: "Nothing listening"))
            } else {
                list(ports)
            }
        } else {
            TileStateView(state: .loading)
        }
    }

    // ponytail: mirrors ListTile's column fill because ListTile rows can't be tapped; drop when the kit adds onTap.
    private func list(_ ports: [DevParsing.ListeningPort]) -> some View {
        let capacity = columns * perColumn
        let visible = ports.count > capacity ? capacity - 1 : ports.count
        return HStack(spacing: tile.rowSpacing) {
            ForEach(0..<columns, id: \.self) { column in
                VStack(spacing: tile.rowSpacing) {
                    ForEach(column * perColumn..<(column + 1) * perColumn, id: \.self) { index in
                        if index < visible {
                            row(ports[index])
                        } else if index == visible, ports.count > visible {
                            Text("+\(ports.count - visible) more").tileStyle(.detail)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Color.clear
                        }
                    }
                }
            }
        }
    }

    private func row(_ port: DevParsing.ListeningPort) -> some View {
        Button { onOpen(port) } label: {
            TileChip {
                HStack(spacing: 4 * tile.scale) {
                    Text(":\(String(port.port))").tileStyle(.mono, color: tile.surface.good)
                    if !tile.isPortrait {
                        Spacer(minLength: 2)
                        Text(port.process).tileStyle(.mono, color: tile.surface.secondary).truncationMode(.middle)
                    }
                }
            }
        }
        .buttonStyle(TilePressStyle())
        .help("Open http://localhost:\(String(port.port))")
        .accessibilityLabel("Port \(String(port.port)), \(port.process)")
        .accessibilityHint("Opens localhost in the browser")
    }
}
