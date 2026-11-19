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
        #expect(MoonPhase(date: MoonPhase.knownNewMoon).name == "New Moon")
        let full = MoonPhase.knownNewMoon.addingTimeInterval(MoonPhase.synodicMonth / 2 * 86_400)
        #expect(MoonPhase(date: full).name == "Full Moon")
        // Late morning UTC on 2026-11-24 is a full moon (published tables); the mean-month estimate should agree.
        #expect(MoonPhase(date: Date(timeIntervalSince1970: 1_795_519_800)).symbol == "moonphase.full.moon")
    }
}
