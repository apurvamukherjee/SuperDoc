/// Every widget the app ships. Add new widgets here.
enum WidgetRegistry {
    // Computed rather than stored: metatype arrays aren't Sendable, so a static let won't compile under Swift 6.
    static var all: [any SuperWidget.Type] {
        [
            AILimitsWidget.self,
            AgentsBoardWidget.self,
            ClockWidget.self,
            DateWidget.self,
            WorldClockWidget.self,
            AnalogClockWidget.self,
            ProgressWidget.self,
            WeekNumberWidget.self,
            UnixTimeWidget.self,
            MoonPhaseWidget.self,
            MonthCalendarWidget.self,
            CPUWidget.self,
            MemoryWidget.self,
            NetworkWidget.self,
            DiskWidget.self,
            BatteryWidget.self,
            UptimeWidget.self,
            ThermalWidget.self,
            WeatherWidget.self,
            SevenDayWidget.self,
            SunWidget.self,
            WeatherDetailWidget.self,
            NowPlayingWidget.self,
            QuickActionsWidget.self,
            VolumeWidget.self,
            BrightnessWidget.self,
            WiFiWidget.self,
            StackWidget.self,
            FileShelfWidget.self,
            LaunchpadWidget.self
        ]
    }

    static func widget(_ id: String) -> (any SuperWidget.Type)? {
        all.first { $0.id == id }
    }
}
