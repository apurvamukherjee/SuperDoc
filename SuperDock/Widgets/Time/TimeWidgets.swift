import AppKit
import SwiftUI

// Thin wrappers: each widget is a TimelineView around its pure view in TimeTiles.swift. Ticking clocks wake once a
// minute, or once a second only when they show seconds.

struct WorldClockWidget: SuperWidget {
    struct Settings: Codable, Equatable {
        var timeZone = "Europe/London"
    }
    static let id = "time.worldClock"
    static var name: String { String(localized: "World Clock") }
    static let category = WidgetCategory.time
    static let symbol = "globe"
    static let supportedSizes: [TileSize] = [.compact, .medium]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        let zone = TimeZone(identifier: settings.timeZone) ?? .current
        return TimelineView(.everyMinute) { context in
            WorldClockView(date: context.date, zone: zone, city: city(settings.timeZone))
        }
    }

    /// "America/Los_Angeles" → "Los Angeles".
    static func city(_ identifier: String) -> String {
        identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? identifier
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(Picker("Time zone", selection: settings.timeZone) {
            ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) }
        })
    }
}

struct ProgressWidget: SuperWidget {
    enum Period: String, Codable, CaseIterable {
        case day, week, month, year
        var component: Calendar.Component {
            switch self {
            case .day: .day
            case .week: .weekOfYear
            case .month: .month
            case .year: .year
            }
        }
        var label: String {
            switch self {
            case .day: String(localized: "Day")
            case .week: String(localized: "Week")
            case .month: String(localized: "Month")
            case .year: String(localized: "Year")
            }
        }
    }

    struct Settings: Codable, Equatable {
        var period = Period.year
    }
    static let id = "time.progress"
    static var name: String { String(localized: "Day / Month / Year Progress") }
    static let category = WidgetCategory.time
    static let symbol = "hourglass"
    static let supportedSizes: [TileSize] = [.compact, .medium]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        TimelineView(.everyMinute) { context in
            PeriodProgressView(period: settings.period, date: context.date)
        }
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(Picker("Period", selection: settings.period) {
            ForEach(Period.allCases, id: \.self) { Text($0.label).tag($0) }
        }.pickerStyle(.segmented).fixedSize())
    }

    static func progress(of period: Period, at date: Date) -> Double {
        TimeMath.progress(through: period.component, at: date)
    }
}

struct UnixTimeWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "time.unix"
    static var name: String { String(localized: "Unix Time") }
    static let category = WidgetCategory.time
    static let symbol = "number"
    static let supportedSizes: [TileSize] = [.medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        TimelineView(.periodic(from: .distantPast, by: 1)) { context in
            UnixTimeView(date: context.date) { epoch in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(epoch, forType: .string)
            }
        }
    }
}

struct WeekNumberWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "time.weekNumber"
    static var name: String { String(localized: "Week Number") }
    static let category = WidgetCategory.time
    static let symbol = "calendar.badge.clock"
    static let supportedSizes: [TileSize] = [.compact]

    static func view(size: TileSize, settings: Settings) -> some View {
        TimelineView(.everyMinute) { context in
            let iso = TimeMath.isoWeek(of: context.date)
            WeekNumberView(week: iso.week, weeksInYear: iso.weeksInYear)
        }
    }
}

struct AnalogClockWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "time.analog"
    static var name: String { String(localized: "Analog Clock") }
    static let category = WidgetCategory.time
    static let symbol = "clock.circle"
    static let supportedSizes: [TileSize] = [.compact]

    static func view(size: TileSize, settings: Settings) -> some View {
        // The face always has a second hand, so it is the one clock that ticks every second.
        TimelineView(.periodic(from: .distantPast, by: 1)) { context in
            AnalogClockView(date: context.date)
        }
    }
}

struct MoonPhaseWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "time.moon"
    static var name: String { String(localized: "Moon Phase") }
    static let category = WidgetCategory.time
    static let symbol = "moonphase.waxing.gibbous"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        TimelineView(.everyMinute) { context in
            MoonPhaseView(phase: MoonPhase(date: context.date))
        }
    }
}

struct MonthCalendarWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "time.monthCalendar"
    static var name: String { String(localized: "Month Calendar") }
    static let category = WidgetCategory.time
    static let symbol = "calendar"
    static let supportedSizes: [TileSize] = [.wide, .large]

    static func view(size: TileSize, settings: Settings) -> some View {
        TimelineView(.everyMinute) { context in
            MonthCalendarView(date: context.date)
        }
    }
}
