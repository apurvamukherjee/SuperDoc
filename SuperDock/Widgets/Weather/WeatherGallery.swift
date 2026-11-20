#if DEBUG
import SwiftUI

extension GallerySheets {
    /// Weather widgets.
    /// Compare with design/mockups/03-catalog-time-system-weather.png.
    static var weather: AnyView? { AnyView(WeatherSheet()) }
}

/// The mockup's own sample data: Lisbon at night, a sunny afternoon, Berlin in the rain, the week from Thu 19.
@MainActor
enum WeatherSamples {
    static func at(_ hour: Int, _ minute: Int = 0, day: Int = 19) -> Date {
        Samples.calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)) ?? .now
    }

    static let week: [WeatherService.Report.Day] = [
        (2, 22, 15), (0, 24, 16), (61, 19, 14), (3, 20, 14), (0, 23, 15), (2, 21, 16), (61, 18, 13)
    ].enumerated().map { index, day in
        WeatherService.Report.Day(date: at(0, day: 19 + index), weatherCode: day.0, high: Double(day.1), low: Double(day.2),
                                  sunrise: at(7, 31, day: 20 + index), sunset: at(18, 2, day: 20 + index))
    }

    static func report(code: Int = 0, temperature: Double = 18, hours: [WeatherService.Report.Hour] = [],
                       feelsLike: Double = 16, wind: Double = 14, direction: Double? = 315, uv: Double = 7,
                       rain: Int = 70, humidity: Int? = 71) -> WeatherService.Report {
        var days = week
        days[0].weatherCode = code
        return WeatherService.Report(
            temperature: temperature, feelsLike: feelsLike, windSpeed: wind, uvIndex: uv, rainChance: rain,
            weatherCode: code, days: days, sunrise: at(7, 31), sunset: at(18, 2), fetchedAt: at(21, 40),
            humidity: humidity, windDirection: direction,
            hours: hours)
    }

    static func hour(_ hour: Int, _ code: Int, _ temperature: Double, rain: Int) -> WeatherService.Report.Hour {
        WeatherService.Report.Hour(date: at(hour), temperature: temperature, weatherCode: code, rainChance: rain)
    }

    static let night = at(22, 55)
    static let afternoon = at(14, 10)
    static let lisbon = report(code: 0, temperature: 18)
    static let sunny = report(code: 2, temperature: 24)
    static let berlin = report(code: 61, temperature: 9,
                               hours: [hour(11, 61, 9, rain: 80), hour(12, 61, 9, rain: 70), hour(13, 3, 8, rain: 30),
                                       hour(14, 3, 8, rain: 20)])
    static var berlinRain: WeatherService.Report {
        var report = berlin
        report.days[0].high = 11
        report.days[0].low = 6
        return report
    }
    static let detail = report(code: 3, temperature: 18, hours: [hour(21, 3, 17, rain: 20), hour(22, 3, 16, rain: 40),
                                                                    hour(23, 61, 16, rain: 70)])
}

private struct WeatherSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            Text("Weather · Weather, 7-Day, Sun, Detail · every size and state").font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
            ForEach([SurfaceStyle.glassDark, .solidLight, .paper], id: \.self) { StyleBlock(style: $0) }
            ScaleBlock()
            SkiesBlock()
        }
        .padding(60)
        .background(galleryWallpaper(.glassDark))
    }
}

private struct Caption: View {
    let text: String
    var dark = true

    var body: some View {
        Text(text).font(.system(size: 14, weight: .semibold)).foregroundStyle(dark ? Color.white.opacity(0.7) : Palette.ink.opacity(0.7))
    }
}

/// Every widget at every supported size, plus the shared states, in one style.
private struct StyleBlock: View {
    let style: SurfaceStyle
    var unit: CGFloat = 73

    private var surface: SurfaceTokens { SurfaceTokens(style) }

    private func ctx(_ size: TileSize, portrait: Bool = false) -> TileContext {
        TileContext(unit: unit, size: size, isPortrait: portrait, surface: surface)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 30) {
            VStack(alignment: .leading, spacing: 14) {
                Caption(text: "\(style.rawValue.uppercased()) · Weather C · M · W — 7-Day W · L", dark: style.isDark)
                WeatherRow(unit: unit, surface: surface)
                Caption(text: "Sun C · M — Detail C × 4 — loading · offline · stale · no city", dark: style.isDark)
                GalleryBar(surface: surface) {
                    SunView(report: WeatherSamples.lisbon, now: WeatherSamples.night).asTile(ctx(.compact))
                    SunView(report: WeatherSamples.lisbon, now: WeatherSamples.night).asTile(ctx(.medium))
                    SunView(report: WeatherSamples.lisbon, now: WeatherSamples.afternoon).asTile(ctx(.compact))
                    SunView(report: WeatherSamples.lisbon, now: WeatherSamples.afternoon).asTile(ctx(.medium))
                    ForEach(WeatherDetailWidget.Metric.allCases, id: \.self) { metric in
                        WeatherDetailView(metric: metric, report: WeatherSamples.detail, unit: .celsius).asTile(ctx(.compact))
                    }
                }
                GalleryBar(surface: surface) {
                    TileStateView(state: .loading).asTile(ctx(.compact))
                    TileStateView(state: .offline(detail: "Can't reach Open-Meteo")).asTile(ctx(.compact))
                    TileStateView(state: .loading).asTile(ctx(.medium))
                    CurrentWeatherView(report: WeatherSamples.lisbon, city: "Lisbon", now: WeatherSamples.night)
                        .tileStale("9:40 PM").asTile(ctx(.medium))
                    ForecastView(report: WeatherSamples.lisbon, unit: .celsius).tileStale("9:40 PM").asTile(ctx(.wide))
                    WeatherNoCityView().asTile(ctx(.compact))
                    WeatherNoCityView().asTile(ctx(.medium))
                }
            }
            if style == .glassDark {
                VStack(alignment: .leading, spacing: 14) {
                    Caption(text: "Vertical bar")
                    GalleryBar(surface: surface, vertical: true) {
                        CurrentWeatherView(report: WeatherSamples.lisbon, city: "Lisbon", now: WeatherSamples.night)
                            .asTile(ctx(.compact))
                        CurrentWeatherView(report: WeatherSamples.lisbon, city: "Lisbon", now: WeatherSamples.night)
                            .asTile(ctx(.medium, portrait: true))
                        SunView(report: WeatherSamples.lisbon, now: WeatherSamples.afternoon).asTile(ctx(.medium, portrait: true))
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    Caption(text: " ")
                    GalleryBar(surface: surface, vertical: true) {
                        CurrentWeatherView(report: WeatherSamples.berlinRain, city: "Berlin", now: WeatherSamples.at(11, 5))
                            .asTile(ctx(.wide, portrait: true))
                        ForecastView(report: WeatherSamples.lisbon, unit: .celsius).asTile(ctx(.wide, portrait: true))
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    Caption(text: " ")
                    GalleryBar(surface: surface, vertical: true) {
                        ForecastView(report: WeatherSamples.lisbon, unit: .celsius).asTile(ctx(.large, portrait: true))
                    }
                }
            }
        }
        .padding(24)
        .background(galleryWallpaper(style), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct WeatherRow: View {
    let unit: CGFloat
    let surface: SurfaceTokens

    private func ctx(_ size: TileSize) -> TileContext { TileContext(unit: unit, size: size, surface: surface) }

    var body: some View {
        GalleryBar(surface: surface) {
            CurrentWeatherView(report: WeatherSamples.sunny, city: "Lisbon", now: WeatherSamples.afternoon).asTile(ctx(.compact))
            CurrentWeatherView(report: WeatherSamples.lisbon, city: "Lisbon", now: WeatherSamples.night).asTile(ctx(.medium))
            CurrentWeatherView(report: WeatherSamples.berlinRain, city: "Berlin", now: WeatherSamples.at(11, 5)).asTile(ctx(.wide))
            ForecastView(report: WeatherSamples.lisbon, unit: .celsius).asTile(ctx(.wide))
            ForecastView(report: WeatherSamples.lisbon, unit: .celsius).asTile(ctx(.large))
        }
    }
}

/// 56 pt tight and 120 pt roomy, like mockup 01.
private struct ScaleBlock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach([56, 120], id: \.self) { bar in
                let unit = CGFloat(bar) - 2 * TileContext.spacing
                let surface = SurfaceTokens(.glassDark)
                Caption(text: "\(bar) PT · GLASS-DARK")
                WeatherRow(unit: unit, surface: surface)
                GalleryBar(surface: surface) {
                    let ctx = { (size: TileSize) in TileContext(unit: unit, size: size, surface: surface) }
                    SunView(report: WeatherSamples.lisbon, now: WeatherSamples.night).asTile(ctx(.compact))
                    SunView(report: WeatherSamples.lisbon, now: WeatherSamples.afternoon).asTile(ctx(.medium))
                    ForEach(WeatherDetailWidget.Metric.allCases, id: \.self) { metric in
                        WeatherDetailView(metric: metric, report: WeatherSamples.detail, unit: .celsius).asTile(ctx(.compact))
                    }
                }
            }
        }
    }
}

/// The sky for each condition by day, twilight and night.
private struct SkiesBlock: View {
    private let codes: [(Int, String)] = [(0, "Clear"), (2, "Partly"), (3, "Cloudy"), (61, "Rain"), (71, "Snow"), (95, "Storm")]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Caption(text: "SKIES · day · twilight (18:20) · night, then °F")
            ForEach([WeatherSamples.afternoon, WeatherSamples.at(18, 20), WeatherSamples.night], id: \.self) { now in
                GalleryBar(surface: SurfaceTokens(.glassDark)) {
                    ForEach(codes, id: \.0) { code, _ in
                        CurrentWeatherView(report: WeatherSamples.report(code: code, temperature: 12), city: "Oslo", now: now)
                            .asTile(TileContext(size: .compact))
                    }
                    ForEach(codes.prefix(2), id: \.0) { code, _ in
                        CurrentWeatherView(report: WeatherSamples.report(code: code, temperature: 12), city: "Oslo", now: now)
                            .asTile(TileContext(size: .medium))
                    }
                }
            }
            GalleryBar(surface: SurfaceTokens(.glassDark)) {
                ForecastView(report: fahrenheit, unit: .fahrenheit).asTile(TileContext(size: .large))
                WeatherDetailView(metric: .wind, report: fahrenheit, unit: .fahrenheit).asTile(TileContext(size: .compact))
                WeatherDetailView(metric: .uv, report: WeatherSamples.report(uv: 9), unit: .celsius).asTile(TileContext(size: .compact))
                WeatherDetailView(metric: .rain, report: WeatherSamples.report(rain: 20), unit: .celsius)
                    .asTile(TileContext(size: .compact))
            }
        }
    }

    private var fahrenheit: WeatherService.Report {
        var report = WeatherSamples.report(wind: 9, direction: 200)
        for index in report.days.indices {
            report.days[index].high = report.days[index].high * 9 / 5 + 32
            report.days[index].low = report.days[index].low * 9 / 5 + 32
        }
        return report
    }
}
#endif
