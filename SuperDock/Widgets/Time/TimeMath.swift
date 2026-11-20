import Foundation

// Pure date maths behind the time widgets, kept free of SwiftUI so the tests can compile it.

enum TimeMath {
    /// How far through the current day/week/month/year `date` is, 0...1.
    static func progress(through component: Calendar.Component, at date: Date, calendar: Calendar = .current) -> Double {
        guard let interval = calendar.dateInterval(of: component, for: date) else { return 0 }
        return date.timeIntervalSince(interval.start) / interval.duration
    }

    /// Time left until the current day/week/month/year ends.
    static func remaining(through component: Calendar.Component, at date: Date, calendar: Calendar = .current) -> TimeInterval {
        guard let interval = calendar.dateInterval(of: component, for: date) else { return 0 }
        return interval.end.timeIntervalSince(date)
    }

    /// Whole days left in the period, counted on the calendar so DST days don't round off.
    static func daysLeft(in component: Calendar.Component, at date: Date, calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: component, for: date) else { return 0 }
        return calendar.dateComponents([.day], from: date, to: interval.end).day ?? 0
    }

    /// The natural pieces a period's bar is cut into: hours of a day, days of a week or month, months of a year.
    static func segments(of component: Calendar.Component, at date: Date, calendar: Calendar = .current) -> Int {
        switch component {
        case .day: 24
        case .weekOfYear: 7
        case .month: calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        default: 12
        }
    }

    /// ISO 8601 week (Monday start, week 1 holds the first Thursday): the usual "week number".
    static func isoWeek(of date: Date, timeZone: TimeZone = .current) -> (week: Int, weeksInYear: Int) {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = timeZone
        let year = iso.component(.yearForWeekOfYear, from: date)
        // 28 December always falls in its year's last ISO week.
        let lastWeek = iso.date(from: DateComponents(year: year, month: 12, day: 28)).map { iso.component(.weekOfYear, from: $0) }
        return (iso.component(.weekOfYear, from: date), lastWeek ?? 52)
    }

    /// "+3½h", "−13½h", "+5:45h"; nil when the zones agree.
    static func offsetLabel(minutes: Int) -> String? {
        guard minutes != 0 else { return nil }
        let sign = minutes > 0 ? "+" : "−"
        let hours = abs(minutes) / 60
        let rest = abs(minutes) % 60
        let whole = hours == 0 ? "" : "\(hours)"
        switch rest {
        case 0: return "\(sign)\(hours)h"
        case 30: return "\(sign)\(whole)½h"
        default: return "\(sign)\(hours):\(String(format: "%02d", rest))h"
        }
    }

    /// Daylight by the clock, not the sun: the tile only needs to look like day or night in that city.
    static func isDaytime(hour: Int) -> Bool { (6..<18).contains(hour) }
}

/// Phase from the mean synodic month, counted from a known new moon (6 Jan 2000 18:14 UTC). Accurate to about a day,
/// which is all a phase icon needs.
struct MoonPhase {
    static let synodicMonth = 29.530588853
    static let knownNewMoon = Date(timeIntervalSince1970: 947_182_440)

    /// 0 = new, 0.5 = full.
    let age: Double

    init(date: Date) {
        let days = date.timeIntervalSince(Self.knownNewMoon) / 86_400
        let fraction = days.truncatingRemainder(dividingBy: Self.synodicMonth) / Self.synodicMonth
        age = fraction < 0 ? fraction + 1 : fraction
    }

    private var index: Int { Int((age * 8).rounded()) % 8 }

    /// Lit fraction of the disc, 0...1.
    var illumination: Double { (1 - cos(2 * .pi * age)) / 2 }
    var isWaxing: Bool { age < 0.5 }
    /// Whole days to the next full moon while waxing, to the next new moon while waning.
    var daysToNext: Int { Int((((isWaxing ? 0.5 : 1) - age) * Self.synodicMonth).rounded()) }

    var symbol: String {
        ["moonphase.new.moon", "moonphase.waxing.crescent", "moonphase.first.quarter", "moonphase.waxing.gibbous",
         "moonphase.full.moon", "moonphase.waning.gibbous", "moonphase.last.quarter", "moonphase.waning.crescent"][index]
    }

    var name: String {
        [String(localized: "New moon"), String(localized: "Waxing crescent"), String(localized: "First quarter"),
         String(localized: "Waxing gibbous"), String(localized: "Full moon"), String(localized: "Waning gibbous"),
         String(localized: "Last quarter"), String(localized: "Waning crescent")][index]
    }
}
