import SwiftUI

/// Claude and Codex usage limits. Compact shows rings; larger sizes show bars with reset countdowns.
struct AILimitsWidget: SuperWidget {
    struct Settings: Codable, Equatable {
        var providers: Providers = .all
        var showRemaining = false
    }

    enum Providers: String, Codable, CaseIterable {
        case all, claude, codex
        var list: [AIProvider] {
            switch self {
            case .all: AIProvider.allCases
            case .claude: [.claude]
            case .codex: [.codex]
            }
        }
    }

    static let id = "ai.limits"
    static var name: String { String(localized: "AI Limits") }
    static let category = WidgetCategory.ai
    static let symbol = "gauge.with.dots.needle.50percent"
    static let supportedSizes: [TileSize] = [.compact, .medium, .wide, .large]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        AILimitsTile(size: size, settings: settings)
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(VStack(alignment: .leading) {
            Picker("Show", selection: settings.providers) {
                Text("Claude and Codex").tag(Providers.all)
                Text("Claude only").tag(Providers.claude)
                Text("Codex only").tag(Providers.codex)
            }
            .fixedSize()
            Toggle("Show remaining instead of used", isOn: settings.showRemaining)
        })
    }
}

private struct AILimitsTile: View {
    let size: TileSize
    let settings: AILimitsWidget.Settings
    private let service = AIUsageService.shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        TimelineView(.everyMinute) { context in
            let rows = settings.providers.list.flatMap { provider in
                (service.usage[provider]?.windows ?? []).map { (provider, $0) }
            }
            if settings.providers != .codex, service.usage[.claude] == nil, !ClaudeStatusLineBridge.standard.isConnected {
                Button(action: openAISettings) {
                    VStack(spacing: 2) {
                        Image(systemName: "link").font(.title3)
                        if size != .compact { Text("Connect Claude").font(.caption2) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Connect Claude Code in Settings → AI to see its limits")
            } else if rows.isEmpty {
                Image(systemName: "gauge.with.dots.needle.0percent")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .help("Use Codex to see its limits")
                    .accessibilityLabel("No AI limit data yet")
            } else if size == .compact {
                Rings(values: rows.prefix(3).map { shown($0.1, now: context.date) / 100 })
                    .accessibilityElement()
                    .accessibilityLabel(rows.map { label($0, now: context.date) }.joined(separator: ", "))
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(rows.prefix(size == .medium ? 2 : 4), id: \.1.id) { provider, window in
                        Bar(title: "\(provider.title) \(window.label)", value: shown(window, now: context.date),
                            detail: size == .medium ? nil : countdown(window, now: context.date))
                    }
                }
            }
        }
        .onAppear { service.subscribe() }
        .onDisappear { service.unsubscribe() }
    }

    private func openAISettings() {
        UserDefaults.standard.set(SettingsTab.ai.rawValue, forKey: SettingsTab.storageKey)
        NSApp.activate()   // agent apps are never frontmost, so Settings would open behind other apps
        openSettings()
    }

    private func shown(_ window: LimitWindow, now: Date) -> Double {
        let used = window.usedPercent(at: now)
        return settings.showRemaining ? 100 - used : used
    }

    private func countdown(_ window: LimitWindow, now: Date) -> String? {
        guard let resetsAt = window.resetsAt, resetsAt > now else { return nil }
        return Duration.seconds(resetsAt.timeIntervalSince(now))
            .formatted(.units(allowed: [.days, .hours, .minutes], width: .narrow, maximumUnitCount: 2))
    }

    private func label(_ row: (AIProvider, LimitWindow), now: Date) -> String {
        let verb = settings.showRemaining ? String(localized: "left") : String(localized: "used")
        return "\(row.0.title) \(row.1.label) \(Int(shown(row.1, now: now)))% \(verb)"
    }
}

private struct Bar: View {
    let title: String
    let value: Double   // 0–100
    let detail: String?

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.caption2).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
            ProgressView(value: min(max(value, 0), 100), total: 100).tint(value >= 80 ? .orange : .accentColor)
            Text("\(Int(value))%").font(.caption2.monospacedDigit()).frame(width: 30, alignment: .trailing)
            if let detail { Text(detail).font(.caption2).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing) }
        }
        .tileText()
    }
}

/// Concentric rings, outermost first.
private struct Rings: View {
    let values: [Double]   // 0–1
    private let colors: [Color] = [.orange, .blue, .green]

    var body: some View {
        ZStack {
            ForEach(values.indices, id: \.self) { index in
                let inset = CGFloat(index) * 7
                Circle().stroke(.quaternary, lineWidth: 5).padding(inset)
                Circle()
                    .trim(from: 0, to: min(max(values[index], 0), 1))
                    .stroke(colors[index % colors.count], style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(inset)
            }
        }
        .padding(4)
    }
}
