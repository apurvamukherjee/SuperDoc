import Foundation
import Observation
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "weather")

/// Current weather from Open-Meteo (no API key). Only contacted while a Weather tile is on screen.
@MainActor @Observable
final class WeatherService {
    static let shared = WeatherService()

    struct Place: Codable, Equatable {
        var name: String
        var latitude: Double
        var longitude: Double
    }

    enum Unit: String, Codable, CaseIterable {
        case celsius, fahrenheit
    }

    struct Report: Equatable {
        struct Day: Equatable {
            var date: Date
            var weatherCode: Int
            var high: Double
            var low: Double
            var sunrise: Date?
            var sunset: Date?
        }
        struct Hour: Equatable {
            var date: Date
            var temperature: Double?
            var weatherCode: Int?
            var rainChance: Int?
        }
        var temperature: Double
        var feelsLike: Double
        var windSpeed: Double     // km/h or mph, matching the temperature unit
        var uvIndex: Double
        var rainChance: Int       // highest precipitation probability over the next 3 hours, %
        var weatherCode: Int      // WMO code
        var days: [Day]           // today first, up to 7
        var sunrise: Date?
        var sunset: Date?
        var fetchedAt: Date
        var humidity: Int?
        /// Degrees the wind blows from, meteorological convention.
        var windDirection: Double?
        /// The current hour first, up to 6.
        var hours: [Hour] = []
        /// The place's own zone: sunrise and hourly labels read in local time there, not on this Mac.
        var timeZone = TimeZone.current

        var high: Double { days.first?.high ?? temperature }
        var low: Double { days.first?.low ?? temperature }
    }

    private static let refreshInterval: Duration = .seconds(30 * 60)

    private(set) var reports: [String: Report] = [:]
    private(set) var failed: Set<String> = []

    static func key(_ place: Place, _ unit: Unit) -> String {
        "\(place.latitude),\(place.longitude),\(unit.rawValue)"
    }

    /// Runs for as long as the calling tile's `.task` lives; SwiftUI cancels it when the tile goes away.
    func keepFresh(_ place: Place, unit: Unit) async {
        while !Task.isCancelled {
            let key = Self.key(place, unit)
            // Several tiles may share a place; skip the fetch if another tile just did it.
            if let report = reports[key], Date().timeIntervalSince(report.fetchedAt) < 25 * 60 {
                // fresh enough
            } else {
                await fetch(place, unit: unit, key: key)
            }
            do {
                try await Task.sleep(for: Self.refreshInterval)
            } catch {
                return   // cancelled: the tile went away
            }
        }
    }

    func search(_ city: String) async throws -> Place? {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [.init(name: "name", value: city), .init(name: "count", value: "1"), .init(name: "format", value: "json")]
        guard let url = components?.url else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(GeocodingResponse.self, from: data).results?.first
        return result.map { Place(name: [$0.name, $0.country].compactMap { $0 }.joined(separator: ", "),
                                  latitude: $0.latitude, longitude: $0.longitude) }
    }

    private func fetch(_ place: Place, unit: Unit, key: String) async {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            .init(name: "latitude", value: String(place.latitude)),
            .init(name: "longitude", value: String(place.longitude)),
            // One request feeds every weather widget for this place.
            .init(name: "current", value: "temperature_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,uv_index,"
                   + "relative_humidity_2m"),
            .init(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability"),
            // Six hours so Rain Soon can say when rain starts, not just whether.
            .init(name: "forecast_hours", value: "6"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset"),
            .init(name: "forecast_days", value: "7"),
            .init(name: "timezone", value: "auto"),
            .init(name: "temperature_unit", value: unit.rawValue),
            .init(name: "wind_speed_unit", value: unit == .fahrenheit ? "mph" : "kmh")
        ]
        guard let url = components?.url else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            reports[key] = try Self.report(from: data, fetchedAt: Date())
            failed.remove(key)
        } catch {
            log.error("Weather fetch failed: \(error)")
            failed.insert(key)
        }
    }

    /// Parses an Open-Meteo forecast response. Times come back in the place's local time with a separate UTC offset.
    nonisolated static func report(from data: Data, fetchedAt: Date) throws -> Report {
        let response = try JSONDecoder().decode(ForecastResponse.self, from: data)
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = TimeZone(secondsFromGMT: response.utc_offset_seconds)
        local.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let day = DateFormatter()
        day.locale = local.locale
        day.timeZone = local.timeZone
        day.dateFormat = "yyyy-MM-dd"
        let daily = response.daily
        let days = daily.time.indices.compactMap { index -> Report.Day? in
            guard let date = day.date(from: daily.time[index]), index < daily.weather_code.count,
                  index < daily.temperature_2m_max.count, index < daily.temperature_2m_min.count else { return nil }
            return Report.Day(date: date, weatherCode: daily.weather_code[index],
                              high: daily.temperature_2m_max[index], low: daily.temperature_2m_min[index],
                              sunrise: daily.sunrise[safe: index].flatMap(local.date(from:)),
                              sunset: daily.sunset[safe: index].flatMap(local.date(from:)))
        }
        let hourly = response.hourly
        let hours = (hourly.time ?? []).enumerated().compactMap { index, time -> Report.Hour? in
            guard let date = local.date(from: time) else { return nil }
            return Report.Hour(date: date, temperature: hourly.temperature_2m?[safe: index] ?? nil,
                               weatherCode: hourly.weather_code?[safe: index] ?? nil,
                               rainChance: hourly.precipitation_probability[safe: index] ?? nil)
        }
        return Report(
            temperature: response.current.temperature_2m,
            feelsLike: response.current.apparent_temperature,
            windSpeed: response.current.wind_speed_10m,
            uvIndex: response.current.uv_index,
            rainChance: response.hourly.precipitation_probability.prefix(3).compactMap { $0 }.max() ?? 0,
            weatherCode: response.current.weather_code,
            days: days,
            sunrise: daily.sunrise.first.flatMap(local.date(from:)),
            sunset: daily.sunset.first.flatMap(local.date(from:)),
            fetchedAt: fetchedAt,
            humidity: response.current.relative_humidity_2m.map { Int($0.rounded()) },
            windDirection: response.current.wind_direction_10m,
            hours: hours,
            timeZone: local.timeZone
        )
    }

    /// SF Symbol for a WMO weather code.
    nonisolated static func symbol(for code: Int) -> String {
        switch code {
        case 0: "sun.max"
        case 1, 2: "cloud.sun"
        case 3: "cloud"
        case 45, 48: "cloud.fog"
        case 51...57: "cloud.drizzle"
        case 61...67, 80...82: "cloud.rain"
        case 71...77, 85, 86: "cloud.snow"
        case 95...99: "cloud.bolt.rain"
        default: "questionmark"
        }
    }

    /// Eight-point compass name for a wind direction in degrees: 0 → "N", 225 → "SW".
    nonisolated static func compass(_ degrees: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 45 + 0.5)
        return points[index % 8]
    }
}

extension WeatherService.Report {
    func isDay(at date: Date) -> Bool {
        guard let sunrise, let sunset else { return true }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        // Sunrise/sunset are today's; compare times of day so a later hour or tomorrow's forecast still reads right.
        let seconds = { (date: Date) in date.timeIntervalSince(calendar.startOfDay(for: date)) }
        let (rise, set) = (seconds(sunrise), seconds(sunset))
        return rise < set ? (rise..<set).contains(seconds(date)) : true
    }
}

// Field names mirror the Open-Meteo JSON.
// swiftlint:disable identifier_name
private struct ForecastResponse: Decodable {
    struct Current: Decodable {
        var temperature_2m: Double
        var apparent_temperature: Double
        var weather_code: Int
        var wind_speed_10m: Double
        var uv_index: Double
        // Optional: responses cached or recorded before these were requested don't carry them.
        var relative_humidity_2m: Double?
        var wind_direction_10m: Double?
    }
    struct Hourly: Decodable {
        var time: [String]?
        var temperature_2m: [Double?]?
        var weather_code: [Int?]?
        var precipitation_probability: [Int?]
    }
    struct Daily: Decodable {
        var time: [String]
        var weather_code: [Int]
        var temperature_2m_max: [Double]
        var temperature_2m_min: [Double]
        var sunrise: [String]
        var sunset: [String]
    }
    var utc_offset_seconds: Int
    var current: Current
    var hourly: Hourly
    var daily: Daily
}
// swiftlint:enable identifier_name

private struct GeocodingResponse: Decodable {
    struct Result: Decodable {
        var name: String
        var country: String?
        var latitude: Double
        var longitude: Double
    }
    var results: [Result]?
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
