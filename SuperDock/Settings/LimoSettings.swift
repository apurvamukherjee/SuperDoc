import SwiftUI

/// Settings → Limo: how present the mascot is, and whether it pops up for agent alerts.
/// The Limo owner reads `limo.presence` ("lively" / "calm" / "hidden"); raw strings keep this pane independent of
/// that type.
struct LimoSettings: View {
    static let presenceKey = "limo.presence"

    @AppStorage(Self.presenceKey) private var presence = "lively"
    @AppStorage(LimoController.enabledKey) private var alerts = true

    private struct Level {
        let value: String, title: LocalizedStringKey, detail: LocalizedStringKey, symbol: String
    }

    private static let levels = [
        Level(value: "lively", title: "Lively", detail: "Looks around, reacts to what happens on your Mac and pops up with news.",
              symbol: "sparkles"),
        Level(value: "calm", title: "Calm", detail: "Sits still on the bar and only moves when something needs you.", symbol: "leaf"),
        Level(value: "hidden", title: "Hidden", detail: "Stays out of sight. Alerts still show as a small pill if they're on.",
              symbol: "eye.slash")
    ]

    var body: some View {
        SettingsPane(title: "Limo", subtitle: "The little face from the app icon. It lives on your bar and never gets in the way.") {
            Form {
                Section {
                    HStack(spacing: 18) {
                        LimoFace(snoring: false)
                            .frame(width: 64, height: 64)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("hi, i'm limo.").font(.system(size: 17, weight: .semibold))
                            Text("i'll keep an eye on your agents.").foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                Section("Presence") {
                    Picker("Presence", selection: $presence) {
                        ForEach(Self.levels, id: \.value) { level in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: level.symbol).frame(width: 16).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(level.title).font(.system(size: 13, weight: .medium))
                                    Text(level.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 3)
                            .tag(level.value)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
                Section("Alerts") {
                    Toggle("Pop up when an agent finishes or needs your input", isOn: $alerts)
                    Text("""
                        Limo reads only status and percentages, never your prompts or code. Reduce Motion turns its \
                        moves into crossfades.
                        """)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }
}
