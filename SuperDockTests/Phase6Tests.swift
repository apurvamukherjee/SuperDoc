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
