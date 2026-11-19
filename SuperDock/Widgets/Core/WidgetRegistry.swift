import SwiftUI

/// What the bar, picker and settings need to know about a widget, whether it's a built-in Swift type or a
/// JSON plugin (which has no Swift type of its own).
struct WidgetDescriptor: Identifiable {
    let id: String
    let name: String
    let category: WidgetCategory
    let symbol: String
    let supportedSizes: [TileSize]
    let usesNetwork: Bool
    let makeTile: @MainActor (TileSize, Data?) -> AnyView
    let makeSettings: @MainActor (Binding<Data?>) -> AnyView?

    @MainActor func tileView(size: TileSize, settings: Data?) -> AnyView { makeTile(size, settings) }
    @MainActor func settingsEditor(_ settings: Binding<Data?>) -> AnyView? { makeSettings(settings) }
}

extension WidgetDescriptor {
    init<W: SuperWidget>(_ widget: W.Type) {
        self.init(id: W.id, name: W.name, category: W.category, symbol: W.symbol, supportedSizes: W.supportedSizes,
                  usesNetwork: W.usesNetwork, makeTile: { W.tileView(size: $0, settings: $1) }, makeSettings: { W.settingsEditor($0) })
    }
}

/// Every widget: the built-in ones listed here, plus installed JSON plugins.
@MainActor
enum WidgetRegistry {
    private static let builtIn: [WidgetDescriptor] = [
        .init(AILimitsWidget.self), .init(AgentsBoardWidget.self),
        .init(ClockWidget.self), .init(DateWidget.self), .init(WorldClockWidget.self), .init(AnalogClockWidget.self),
        .init(ProgressWidget.self), .init(WeekNumberWidget.self), .init(UnixTimeWidget.self), .init(MoonPhaseWidget.self),
        .init(MonthCalendarWidget.self),
        .init(CPUWidget.self), .init(MemoryWidget.self), .init(NetworkWidget.self), .init(DiskWidget.self),
        .init(BatteryWidget.self), .init(UptimeWidget.self), .init(ThermalWidget.self),
        .init(WeatherWidget.self), .init(SevenDayWidget.self), .init(SunWidget.self), .init(WeatherDetailWidget.self),
        .init(NowPlayingWidget.self),
        .init(QuickActionsWidget.self), .init(VolumeWidget.self), .init(BrightnessWidget.self), .init(WiFiWidget.self),
        .init(StackWidget.self), .init(FileShelfWidget.self), .init(LaunchpadWidget.self),
        .init(PomodoroWidget.self), .init(TimerWidget.self), .init(StopwatchWidget.self), .init(WaterWidget.self),
        .init(NoteWidget.self), .init(TodoWidget.self),
        .init(UUIDWidget.self), .init(PasswordWidget.self), .init(PortsWidget.self), .init(GitStatusWidget.self),
        .init(DiceWidget.self), .init(EightBallWidget.self)
    ]

    static var all: [WidgetDescriptor] { builtIn + PluginStore.shared.descriptors }

    static func widget(_ id: String) -> WidgetDescriptor? {
        all.first { $0.id == id }
    }
}
