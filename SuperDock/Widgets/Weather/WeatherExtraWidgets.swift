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
        WeatherReportView(settings: settings) { report, _, _ in
            ForecastView(report: report, unit: settings.unit)
        }
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(WeatherSettings(settings: settings))
    }
}

/// 7-Day W · L. W lists five days with high/low; L adds iOS-style range bars on one shared temperature scale.
struct ForecastView: View {
    @Environment(\.tile) private var tile
    let report: WeatherService.Report
    let unit: WeatherService.Unit

    private var days: [WeatherService.Report.Day] { Array(report.days.prefix(tile.size == .large ? 7 : 5)) }

    var body: some View {
        let days = days
        let range = (low: days.map(\.low).min() ?? 0, high: days.map(\.high).max() ?? 0)
        Group {
            if tile.isPortrait {
                VStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        if index > 0 { Spacer(minLength: 0) }
                        row(day, index: index)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        Group {
                            if tile.size == .large {
                                rangeColumn(day, index: index, range: range)
                            } else {
                                column(day, index: index)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(spoken(day, index: index))
                    }
                }
            }
        }
    }

    private func column(_ day: WeatherService.Report.Day, index: Int) -> some View {
        VStack(spacing: 5 * tile.scale) {
            weekday(day, index: index, today: String(localized: "Today"))
            WeatherSymbol(name: weatherSymbol(day.weatherCode), size: 15).frame(height: 17 * tile.scale)
            HStack(alignment: .firstTextBaseline, spacing: 3 * tile.scale) {
                Text(degrees(day.high)).tileStyle(.detail, color: tile.surface.primary).fontWeight(.bold)
                Text(whole(day.low)).tileStyle(.detail)
            }
        }
    }

    private func rangeColumn(_ day: WeatherService.Report.Day, index: Int, range: (low: Double, high: Double)) -> some View {
        VStack(spacing: 3 * tile.scale) {
            weekday(day, index: index, today: nil)
            WeatherSymbol(name: weatherSymbol(day.weatherCode), size: 12).frame(height: 14 * tile.scale)
            HStack(spacing: 3 * tile.scale) {
                Text(whole(day.low)).tileStyle(.detail)
                RangeBar(low: day.low, high: day.high, weekLow: range.low, weekHigh: range.high, unit: unit)
                Text(whole(day.high)).tileStyle(.body).fontWeight(.bold).monospacedDigit()
            }
        }
    }

    private func row(_ day: WeatherService.Report.Day, index: Int) -> some View {
        HStack(spacing: 3 * tile.scale) {
            weekday(day, index: index, today: nil).fixedSize()
            Spacer(minLength: 0)
            WeatherSymbol(name: weatherSymbol(day.weatherCode), size: 11)
            // One unit is too narrow for both; the low is in the VoiceOver label.
            Text(degrees(day.high)).tileStyle(.detail, color: tile.surface.primary).fontWeight(.bold)
                .frame(width: 20 * tile.scale, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(day, index: index))
    }

    private func weekday(_ day: WeatherService.Report.Day, index: Int, today: String?) -> some View {
        var style = Date.FormatStyle().weekday(.abbreviated)
        style.timeZone = report.timeZone
        let text = index == 0 ? today ?? day.date.formatted(style) : day.date.formatted(style)
        return Text(text).tileStyle(.detail, color: index == 0 ? tile.surface.primary : tile.surface.secondary)
            .fontWeight(index == 0 ? .bold : .semibold)
    }

    private func spoken(_ day: WeatherService.Report.Day, index: Int) -> String {
        var style = Date.FormatStyle().weekday(.wide)
        style.timeZone = report.timeZone
        let name = index == 0 ? String(localized: "Today") : day.date.formatted(style)
        return "\(name): high \(degrees(day.high)), low \(degrees(day.low))"
    }

    private func whole(_ value: Double) -> String { "\(Int(value.rounded()))" }
}

/// One day's low…high span, placed on the week's shared scale and cut from one fixed cold-to-hot gradient, so a
/// warm day is visibly warmer than its neighbours (iOS Weather, turned upright to fit a one-unit-tall tile).
private struct RangeBar: View {
    @Environment(\.tile) private var tile
    let low: Double
    let high: Double
    let weekLow: Double
    let weekHigh: Double
    let unit: WeatherService.Unit

    /// Celsius stops measured off the mockup: 15° reads blue, 19° yellow, 23° orange.
    private static let stops: [(celsius: Double, rgb: UInt32)] = [
        (0, 0x7A86FF), (15, 0x5AA2FF), (19, 0xFFD15C), (23, 0xFF9F43), (30, 0xFF5A4E)
    ]

    var body: some View {
        let band = 26 * tile.scale
        let width = 4 * tile.scale
        let span = max(weekHigh - weekLow, 1)
        let top = band * (weekHigh - high) / span
        let length = max(band * (high - low) / span, width)
        gradient(span: span)
            .frame(width: width, height: band)
            .mask(alignment: .top) { Capsule().frame(height: length).offset(y: top) }
            .accessibilityHidden(true)
    }

    private func gradient(span: Double) -> LinearGradient {
        let temps = Self.stops.map { unit == .fahrenheit ? $0.celsius * 9 / 5 + 32 : $0.celsius }
        let (cold, hot) = (temps[0], temps[temps.count - 1])
        let stops = zip(temps, Self.stops).map { temp, stop in
            Gradient.Stop(color: Color(rgb: stop.rgb), location: (temp - cold) / (hot - cold))
        }
        // Unit y of a temperature inside the band: weekHigh at the top, weekLow at the bottom.
        let unitY = { (temp: Double) in (weekHigh - temp) / span }
        return LinearGradient(stops: stops, startPoint: UnitPoint(x: 0.5, y: unitY(cold)), endPoint: UnitPoint(x: 0.5, y: unitY(hot)))
    }
}
