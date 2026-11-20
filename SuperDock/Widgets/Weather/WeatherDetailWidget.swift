import SwiftUI

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

        /// The tile label: one short word so it fits a compact tile at any Dock size.
        var label: String {
            switch self {
            case .feelsLike: String(localized: "Feels")
            case .wind: String(localized: "Wind")
            case .uv: String(localized: "UV")
            case .rain: String(localized: "Rain")
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
        WeatherReportView(settings: settings.weather) { report, _, _ in
            WeatherDetailView(metric: settings.metric, report: report, unit: settings.weather.unit)
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
}

/// Detail C. Archetype: Stat with a per-metric visual: wind arrow, UV scale, blue wash when rain is likely.
struct WeatherDetailView: View {
    typealias Metric = WeatherDetailWidget.Metric

    @Environment(\.tile) private var tile
    let metric: Metric
    let report: WeatherService.Report
    let unit: WeatherService.Unit

    private var rainLikely: Bool { metric == .rain && report.rainChance >= 60 }
    private var rainInk: Color { tile.surface.isDark ? Palette.progress : Palette.working }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(metric.label).tileStyle(.label, color: rainLikely ? rainInk : nil)
            Spacer(minLength: 0)
            hero
            Spacer(minLength: 0)
            if tile.showsDetail { bottom }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .tileTint(rainLikely ? Palette.working : nil, opacity: 0.18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(metric.title) + Text(" \(spokenValue)"))
    }

    @ViewBuilder private var hero: some View {
        switch metric {
        case .feelsLike:
            Text(degrees(report.feelsLike)).tileStyle(.hero)
        case .wind:
            HStack(spacing: 6 * tile.scale) {
                if let direction = report.windDirection {
                    // Points the way the wind blows, i.e. away from the compass direction it's named after.
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 13 * tile.scale, weight: .semibold))
                        .foregroundStyle(Palette.progress)
                        .rotationEffect(.degrees(direction + 180))
                }
                Text("\(Int(report.windSpeed.rounded()))").tileStyle(.hero)
            }
        case .uv:
            Text(report.uvIndex.formatted(.number.precision(.fractionLength(0)))).tileStyle(.hero, color: uvInk)
        case .rain:
            Text("\(report.rainChance)%").tileStyle(.hero, color: rainLikely ? rainInk : nil)
        }
    }

    @ViewBuilder private var bottom: some View {
        switch metric {
        case .feelsLike:
            Text(report.humidity.map { "Humid \($0)%" } ?? "Actual \(degrees(report.temperature))").tileStyle(.detail)
        case .wind:
            Text([speedUnit, report.windDirection.map(WeatherService.compass)].compactMap(\.self).joined(separator: " "))
                .tileStyle(.detail)
        case .uv:
            UVScale(index: report.uvIndex)
        case .rain:
            Text(rainStart).tileStyle(.detail)
        }
    }

    private var speedUnit: String { unit == .fahrenheit ? "mph" : "km/h" }

    private var uvInk: Color? {
        if report.uvIndex >= 8 { return tile.surface.danger }
        return report.uvIndex >= 6 ? (tile.surface.isDark ? Palette.hot : tile.surface.warning) : nil
    }

    private var rainStart: String {
        guard let first = report.hours.firstIndex(where: { ($0.rainChance ?? 0) >= 50 }) else {
            return String(localized: "next 3 h")
        }
        if first == 0 { return String(localized: "now") }
        var style = Date.FormatStyle().hour()
        style.timeZone = report.timeZone
        return String(localized: "from \(report.hours[first].date.formatted(style))")
    }

    private var spokenValue: String {
        switch metric {
        case .feelsLike: degrees(report.feelsLike)
        case .wind: "\(Int(report.windSpeed.rounded())) \(speedUnit)"
        case .uv: report.uvIndex.formatted(.number.precision(.fractionLength(0)))
        case .rain: "\(report.rainChance)%"
        }
    }
}

/// The WHO UV bands as five segments, lit up to the current one.
private struct UVScale: View {
    @Environment(\.tile) private var tile
    let index: Double

    private static let bands: [(from: Double, color: Color)] = [
        (0.5, Palette.good), (3, Palette.note), (6, Palette.hot), (8, Palette.coral), (11, Palette.codex)
    ]

    var body: some View {
        HStack(spacing: 2.5 * tile.scale) {
            ForEach(Self.bands.indices, id: \.self) { band in
                Capsule().fill(index >= Self.bands[band].from ? Self.bands[band].color : tile.surface.track)
                    .frame(height: 4 * tile.scale)
            }
        }
        .accessibilityHidden(true)
    }
}
