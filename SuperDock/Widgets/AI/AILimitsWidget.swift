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
        AILimitsTile(settings: settings)
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

/// Reads the service and hands plain values to `AILimitsView`.
private struct AILimitsTile: View {
    let settings: AILimitsWidget.Settings
    private let service = AIUsageService.shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        TimelineView(.everyMinute) { context in
            AILimitsView(content: content(now: context.date), showRemaining: settings.showRemaining, onConnect: openAISettings)
        }
        .onAppear { service.subscribe() }
        .onDisappear { service.unsubscribe() }
    }

    private func content(now: Date) -> AILimitsView.Content {
        if settings.providers != .codex, service.usage[.claude] == nil, !ClaudeStatusLineBridge.standard.isConnected {
            return .connect
        }
        let limits = settings.providers.list.flatMap { provider in
            (service.usage[provider]?.windows ?? []).enumerated().map { index, window in
                Self.limit(window, provider: provider, isPrimary: index == 0, now: now)
            }
        }
        return limits.isEmpty ? .noData : .limits(limits)
    }

    static func limit(_ window: LimitWindow, provider: AIProvider, isPrimary: Bool, now: Date) -> AILimit {
        let isWeek = window.label == String(localized: "Week")
        let resetsIn = window.resetsAt.map { $0.timeIntervalSince(now) }.flatMap { $0 > 0 ? $0 : nil }
        return AILimit(provider: provider, name: isWeek ? String(localized: "Wk") : window.label,
                       longName: isWeek ? String(localized: "Weekly") : window.label == String(localized: "5h")
                           ? String(localized: "5-hour") : window.label,
                       used: window.usedPercent(at: now), resetsIn: resetsIn,
                       resetDay: window.resetsAt?.formatted(.dateTime.weekday(.abbreviated)), isPrimary: isPrimary)
    }

    private func openAISettings() {
        UserDefaults.standard.set(SettingsTab.ai.rawValue, forKey: SettingsTab.storageKey)
        NSApp.activate()   // agent apps are never frontmost, so Settings would open behind other apps
        openSettings()
    }
}
