import SwiftUI

/// Settings → Placement: where the bar sits relative to the Dock, with a live diagram.
struct PlacementSettings: View {
    @AppStorage(BarPrefs.positionKey) private var position = BarPrefs.defaultPosition
    @AppStorage(BarPrefs.gapKey) private var gap = BarPrefs.defaultGap
    @AppStorage(DockReplacement.enabledKey) private var replaceDock = false

    var body: some View {
        SettingsPane(title: "Placement", subtitle: "The bar follows the Dock: it grows, shrinks and hides with it.") {
            Form {
                Section {
                    PlacementDiagram(position: position, gap: gap, replacesDock: replaceDock)
                        .listRowInsets(EdgeInsets())
                }
                Section {
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
                Section {
                    Toggle("Replace the system Dock", isOn: Binding(get: { replaceDock }, set: { isOn in
                        replaceDock = isOn
                        if isOn { DockReplacement.standard.apply() } else { DockReplacement.standard.restore() }
                    }))
                    Text("""
                        Hides the macOS Dock and shows your apps in SuperDock's bar instead. Your Dock settings are saved \
                        first and put back when you turn this off or quit SuperDock.
                        """)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }
}

/// A screen's bottom edge with the Dock and the bar where the current settings put them.
private struct PlacementDiagram: View {
    let position: BarPosition
    let gap: Double
    let replacesDock: Bool

    private static let appColors: [UInt32] = [0x3B82F6, 0x34C77B, 0xFF8A3D, 0xA855F7, 0xF0436A, 0x1FB3D9]

    var body: some View {
        // Half scale, so the 0–32 pt gap range stays visible without dwarfing the drawing.
        let spacing = gap / 2
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(rgb: 0x2A1F5E), Color(rgb: 0x1E2D52), Color(rgb: 0x123F4C)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Group {
                if replacesDock {
                    HStack(spacing: 6) { apps; Divider().frame(height: 26).overlay(.white.opacity(0.4)); tiles }
                        .modifier(Shelf(fill: .white.opacity(0.16)))
                } else {
                    switch position {
                    case .leading: HStack(alignment: .bottom, spacing: spacing) { bar; dock }
                    case .trailing: HStack(alignment: .bottom, spacing: spacing) { dock; bar }
                    case .outside: VStack(spacing: spacing) { bar; dock }
                    }
                }
            }
            .padding(.bottom, 10)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .tileAnimation(Motion.settle, value: position)
        .tileAnimation(Motion.settle, value: replacesDock)
        .accessibilityElement()
        .accessibilityLabel(Text("Diagram of the bar beside the Dock"))
    }

    private var dock: some View {
        apps.modifier(Shelf(fill: .white.opacity(0.16)))
    }

    private var bar: some View {
        tiles.modifier(Shelf(fill: .white.opacity(0.28)))
    }

    private var apps: some View {
        HStack(spacing: 5) {
            ForEach(Self.appColors, id: \.self) {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(rgb: $0).gradient).frame(width: 26, height: 26)
            }
        }
    }

    private var tiles: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.white.opacity(0.55))
                    .frame(width: index == 0 ? 56 : 26, height: 26)
            }
        }
    }

    private struct Shelf: ViewModifier {
        let fill: Color

        func body(content: Content) -> some View {
            content
                .padding(5)
                .background(fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.25)) }
        }
    }
}
