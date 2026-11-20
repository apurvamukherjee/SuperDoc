import SwiftUI

/// 12/24-hour follows the system setting (System Settings → General → Date & Time).
struct ClockWidget: SuperWidget {
    struct Settings: Codable, Equatable {
        var showSeconds = false
    }

    static let id = "time.clock"
    static var name: String { String(localized: "Clock") }
    static let category = WidgetCategory.time
    static let symbol = "clock"
    static let supportedSizes: [TileSize] = [.compact, .medium]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        // Anchored at the reference date (a minute boundary) so per-minute updates land on :00.
        TimelineView(.periodic(from: .distantPast, by: settings.showSeconds ? 1 : 60)) { context in
            ClockWidgetView(date: context.date, showsSeconds: settings.showSeconds)
        }
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(Toggle("Show seconds", isOn: settings.showSeconds))
    }
}
