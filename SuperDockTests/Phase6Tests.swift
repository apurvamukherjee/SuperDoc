import Foundation
import Testing

private let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "Fixtures")
private let utc = TimeZone(identifier: "UTC")!

struct WeatherParsingTests {
    @Test func parsesExtendedForecast() throws {
        let report = try WeatherService.report(from: Data(contentsOf: fixtures.appending(path: "open-meteo-forecast.json")),
                                               fetchedAt: Date(timeIntervalSince1970: 0))
        #expect(report.temperature == 9.0)
        #expect(report.feelsLike == 6.6)
        #expect(report.windSpeed == 11.2)
        #expect(report.rainChance == 100)          // highest of the next 3 hours
        #expect(report.days.count == 7)
        #expect(report.days[0].weatherCode == 80)
        // Open-Meteo gives local times plus an offset: 07:34 at UTC+1 is 06:34 UTC.
        let calendar = Calendar(identifier: .gregorian)
        let sunrise = calendar.dateComponents(in: utc, from: try #require(report.sunrise))
        let sunset = calendar.dateComponents(in: utc, from: try #require(report.sunset))
        #expect([sunrise.hour, sunrise.minute] == [6, 34])
        #expect([sunset.hour, sunset.minute] == [15, 7])
    }

    private func forecast(patchingHourly patch: [String: Any] = [:]) throws -> WeatherService.Report {
        let data = try Data(contentsOf: fixtures.appending(path: "open-meteo-forecast.json"))
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var hourly = try #require(json["hourly"] as? [String: Any])
        hourly.merge(patch) { $1 }
        json["hourly"] = hourly
        return try WeatherService.report(from: JSONSerialization.data(withJSONObject: json), fetchedAt: Date(timeIntervalSince1970: 0))
    }

    private func utcDate(day: Int = 19, hour: Int, minute: Int = 0) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)))
    }

    @Test func parsesHoursInThePlacesZone() throws {
        let report = try forecast()
        // The fixture's hourly block only has rain chances, like responses recorded before temperatures were requested.
        #expect(report.hours.count == 3)
        #expect(report.hours[0] == .init(date: try utcDate(hour: 12), temperature: nil, weatherCode: nil, rainChance: 83))
        #expect(report.hours.map(\.rainChance) == [83, 100, 98])
        #expect(report.timeZone.secondsFromGMT() == 3600)
    }

    @Test func hourlyNullsStayNilAndShortArraysDontShift() throws {
        let report = try forecast(patchingHourly: ["temperature_2m": [9.5, NSNull(), 8.0], "weather_code": [61, 80]])
        #expect(report.hours.map(\.temperature) == [9.5, nil, 8.0])
        #expect(report.hours.map(\.weatherCode) == [61, 80, nil])
    }

    @Test func dayIsBetweenSunriseAndSunsetOnAnyDay() throws {
        var report = try forecast()   // sunrise 06:34 UTC, sunset 15:07 UTC
        #expect(report.isDay(at: try utcDate(hour: 12)))
        #expect(!report.isDay(at: try utcDate(hour: 6, minute: 30)))
        #expect(report.isDay(at: try utcDate(hour: 6, minute: 40)))
        #expect(!report.isDay(at: try utcDate(hour: 20)))
        // Hourly and tomorrow's entries compare by time of day against today's sun times.
        #expect(report.isDay(at: try utcDate(day: 20, hour: 10)))
        #expect(!report.isDay(at: try utcDate(day: 20, hour: 22)))
        report.sunrise = nil
        #expect(report.isDay(at: try utcDate(hour: 22)))
    }

    @Test(arguments: [(0.0, "N"), (22.4, "N"), (22.6, "NE"), (90, "E"), (180, "S"), (225, "SW"), (337.4, "NW"),
                      (337.6, "N"), (359.9, "N"), (360, "N"), (405, "NE"), (-90, "W")] as [(Double, String)])
    func compass(degrees: Double, name: String) {
        #expect(WeatherService.compass(degrees) == name)
    }
}

struct TimeMathTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar
    }

    @Test func dayAndYearProgress() throws {
        let noon = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 2, hour: 12)))
        #expect(TimeMath.progress(through: .day, at: noon, calendar: calendar) == 0.5)
        // 2 July noon is day 182.5 of 365.
        #expect(abs(TimeMath.progress(through: .year, at: noon, calendar: calendar) - 182.5 / 365) < 0.0001)
    }

    @Test func moonPhases() {
        #expect(MoonPhase(date: MoonPhase.knownNewMoon).name == "New moon")
        let full = MoonPhase.knownNewMoon.addingTimeInterval(MoonPhase.synodicMonth / 2 * 86_400)
        #expect(MoonPhase(date: full).name == "Full moon")
        // Late morning UTC on 2026-11-24 is a full moon (published tables); the mean-month estimate should agree.
        #expect(MoonPhase(date: Date(timeIntervalSince1970: 1_795_519_800)).symbol == "moonphase.full.moon")
        #expect(MoonPhase(date: full).illumination > 0.999)
        #expect(MoonPhase(date: MoonPhase.knownNewMoon).illumination < 0.001)
        // The mockup's evening of 19 Nov 2026 (full moon on the 24th): about three-quarters lit.
        let mockup = MoonPhase(date: Date(timeIntervalSince1970: 1_795_109_100))
        #expect(mockup.isWaxing && mockup.daysToNext == 5)
        #expect(abs(mockup.illumination - 0.75) < 0.03)
    }

    @Test func periodsAndWeeks() throws {
        let evening = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 17, minute: 25)))
        #expect(TimeMath.daysLeft(in: .year, at: evening, calendar: calendar) == 42)
        #expect(TimeMath.segments(of: .month, at: evening, calendar: calendar) == 30)
        #expect(TimeMath.isoWeek(of: evening, timeZone: utc) == (47, 53))
        let newYear2025 = try #require(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        #expect(TimeMath.isoWeek(of: newYear2025, timeZone: utc) == (1, 52))
    }

    @Test func zoneOffsets() {
        #expect(TimeMath.offsetLabel(minutes: 0) == nil)
        #expect(TimeMath.offsetLabel(minutes: -810) == "−13½h")
        #expect(TimeMath.offsetLabel(minutes: 210) == "+3½h")
        #expect(TimeMath.offsetLabel(minutes: 30) == "+½h")
        #expect(TimeMath.offsetLabel(minutes: 345) == "+5:45h")
        #expect(TimeMath.offsetLabel(minutes: -120) == "−2h")
    }
}
