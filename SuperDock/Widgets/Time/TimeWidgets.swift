import SwiftUI

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
        let city = settings.timeZone.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? ""
        return TimelineView(.everyMinute) { context in
            StatTile(label: LocalizedStringKey(city), value: time(context.date, in: zone),
                     detail: size == .compact ? nil : offset(zone, at: context.date))
        }
    }

    private static func time(_ date: Date, in zone: TimeZone) -> String {
        var style = Date.FormatStyle.dateTime.hour().minute()
        style.timeZone = zone
        return date.formatted(style)
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(Picker("Time zone", selection: settings.timeZone) {
            ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) }
        })
    }

    /// "+5:30h" relative to the Mac's own zone.
    private static func offset(_ zone: TimeZone, at date: Date) -> String {
        let minutes = (zone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)) / 60
        guard minutes != 0 else { return String(localized: "Same time") }
        let sign = minutes > 0 ? "+" : "−"
        let hours = abs(minutes) / 60
        return minutes % 60 == 0 ? "\(sign)\(hours)h" : "\(sign)\(hours):\(String(format: "%02d", abs(minutes) % 60))h"
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
        var title: LocalizedStringKey {
            switch self {
            case .day: "Day"
            case .week: "Week"
            case .month: "Month"
            case .year: "Year"
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
            let share = progress(of: settings.period, at: context.date)
            VStack(spacing: 4) {
                Text(settings.period.title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(share, format: .percent.precision(.fractionLength(0))).font(.title3.weight(.semibold)).monospacedDigit()
                if size != .compact { ProgressView(value: share).padding(.horizontal, 6) }
            }
            .tileText()
        }
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(Picker("Period", selection: settings.period) {
            ForEach(Period.allCases, id: \.self) { Text($0.title).tag($0) }
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
            StatTile(label: "Unix", value: String(Int(context.date.timeIntervalSince1970)))
                .textSelection(.enabled)
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
            // ISO 8601 weeks (Monday start, week 1 contains the first Thursday), the usual "week number".
            StatTile(label: "Week", value: String(Calendar(identifier: .iso8601).component(.weekOfYear, from: context.date)))
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
        TimelineView(.periodic(from: .distantPast, by: 1)) { context in
            let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: context.date)
            let seconds = Double(parts.second ?? 0)
            let minutes = Double(parts.minute ?? 0) + seconds / 60
            let hours = Double((parts.hour ?? 0) % 12) + minutes / 60
            Canvas { canvas, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 2
                canvas.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                              with: .style(.secondary), lineWidth: 1.5)
                func hand(_ turns: Double, length: CGFloat, width: CGFloat, style: GraphicsContext.Shading) {
                    let angle = turns * 2 * .pi - .pi / 2
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: CGPoint(x: center.x + cos(angle) * radius * length, y: center.y + sin(angle) * radius * length))
                    canvas.stroke(path, with: style, style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
                hand(hours / 12, length: 0.5, width: 2.5, style: .style(.primary))
                hand(minutes / 60, length: 0.78, width: 2, style: .style(.primary))
                hand(seconds / 60, length: 0.85, width: 1, style: .color(.orange))
            }
            .accessibilityLabel(context.date.formatted(date: .omitted, time: .shortened))
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
            let phase = MoonPhase(date: context.date)
            VStack(spacing: 2) {
                Image(systemName: phase.symbol).font(.title2).accessibilityHidden(true)
                if size != .compact { Text(phase.name).font(.caption2).foregroundStyle(.secondary) }
            }
            .tileText()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(phase.name)
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
            MonthGrid(date: context.date)
        }
    }
}

/// The current month as a 7-column grid. The tile is short, so days are tiny and the row count adapts.
private struct MonthGrid: View {
    let date: Date
    private let calendar = Calendar.current

    var body: some View {
        let month = calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
        let days = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        let leading = (calendar.component(.weekday, from: month.start) - calendar.firstWeekday + 7) % 7
        let today = calendar.component(.day, from: date)
        let cells: [Int?] = Array(repeating: nil, count: leading) + (1...days).map { $0 }
        Grid(horizontalSpacing: 2, verticalSpacing: 0) {
            ForEach(0..<Int((Double(cells.count) / 7).rounded(.up)), id: \.self) { row in
                GridRow {
                    ForEach(0..<7, id: \.self) { column in
                        let index = row * 7 + column
                        let day = index < cells.count ? cells[index] : nil
                        Text(day.map(String.init) ?? "")
                            .font(.system(size: 8, weight: day == today ? .bold : .regular).monospacedDigit())
                            .foregroundStyle(day == today ? Color.accentColor : .primary)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(.dateTime.month(.wide).year()))
    }
}
