import SwiftUI

// These share WeatherWidget.Settings (city + units), so one fetch per city feeds them all.

struct SevenDayWidget: SuperWidget {
    typealias Settings = WeatherWidget.Settings
    static let id = "weather.sevenDay"
    static var name: String { String(localized: "7-Day Forecast") }
    static let category = WidgetCategory.weather
    static let symbol = "calendar.day.timeline.left"
    static let supportedSizes: [TileSize] = [.wide, .large]
    static let usesNetwork = true
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        WeatherReportView(settings: settings) { report, _ in
            HStack(spacing: 0) {
                ForEach(report.days.prefix(size == .wide ? 5 : 7), id: \.date) { day in
                    VStack(spacing: 2) {
                        Text(day.date, format: .dateTime.weekday(.abbreviated)).font(.caption2).foregroundStyle(.secondary)
                        Image(systemName: WeatherService.symbol(for: day.weatherCode)).symbolRenderingMode(.multicolor)
                        Text("\(degrees(day.high)) \(degrees(day.low))").font(.caption2.monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            .tileText()
        }
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(WeatherSettings(settings: settings))
    }
}

struct SunWidget: SuperWidget {
    typealias Settings = WeatherWidget.Settings
    static let id = "weather.sun"
    static var name: String { String(localized: "Sunrise & Sunset") }
    static let category = WidgetCategory.weather
    static let symbol = "sunrise"
    static let supportedSizes: [TileSize] = [.compact, .medium]
    static let usesNetwork = true
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        WeatherReportView(settings: settings) { report, _ in
            let time = Date.FormatStyle.dateTime.hour().minute()
            VStack(alignment: .leading, spacing: 4) {
                Label(report.sunrise?.formatted(time) ?? "–", systemImage: "sunrise.fill")
                Label(report.sunset?.formatted(time) ?? "–", systemImage: "sunset.fill")
            }
            .symbolRenderingMode(.multicolor)
            .font(size == .compact ? .caption2 : .callout)
            .monospacedDigit()
            .tileText()
        }
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(WeatherSettings(settings: settings))
    }
}

/// Feels Like, Wind, UV and Rain Soon in one widget with a metric picker.
struct WeatherDetailWidget: SuperWidget {
    enum Metric: String, Codable, CaseIterable {
        case feelsLike, wind, uv, rain
        var title: LocalizedStringKey {
            switch self {
            case .feelsLike: "Feels Like"
            case .wind: "Wind"
            case .uv: "UV"
            case .rain: "Rain Soon"
            }
        }
    }

    struct Settings: Codable, Equatable {
        var weather = WeatherWidget.Settings()
        var metric = Metric.feelsLike
    }
    static let id = "weather.detail"
    static var name: String { String(localized: "Feels Like / Wind / UV / Rain") }
    static let category = WidgetCategory.weather
    static let symbol = "wind"
    static let supportedSizes: [TileSize] = [.compact]
    static let usesNetwork = true
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        WeatherReportView(settings: settings.weather) { report, _ in
            StatTile(label: settings.metric.title, value: value(settings.metric, report, unit: settings.weather.unit),
                     tint: tint(settings.metric, report))
        }
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(VStack(alignment: .leading) {
            Picker("Show", selection: settings.metric) {
                ForEach(Metric.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .fixedSize()
            WeatherSettings(settings: settings.weather)
        })
    }

    private static func value(_ metric: Metric, _ report: WeatherService.Report, unit: WeatherService.Unit) -> String {
        switch metric {
        case .feelsLike: degrees(report.feelsLike)
        case .wind: "\(Int(report.windSpeed.rounded())) \(unit == .fahrenheit ? "mph" : "km/h")"
        case .uv: report.uvIndex.formatted(.number.precision(.fractionLength(0)))
        case .rain: "\(report.rainChance)%"
        }
    }

    private static func tint(_ metric: Metric, _ report: WeatherService.Report) -> Color {
        switch metric {
        case .uv: report.uvIndex >= 8 ? .red : report.uvIndex >= 6 ? .orange : .primary
        case .rain: report.rainChance >= 60 ? .blue : .primary
        case .feelsLike, .wind: .primary
        }
    }
}
