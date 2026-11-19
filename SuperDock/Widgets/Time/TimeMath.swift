import Foundation

// Pure date maths behind the time widgets, kept free of SwiftUI so the tests can compile it.

enum TimeMath {
    /// How far through the current day/week/month/year `date` is, 0...1.
    static func progress(through component: Calendar.Component, at date: Date, calendar: Calendar = .current) -> Double {
        guard let interval = calendar.dateInterval(of: component, for: date) else { return 0 }
        return date.timeIntervalSince(interval.start) / interval.duration
    }
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

    var symbol: String {
        ["moonphase.new.moon", "moonphase.waxing.crescent", "moonphase.first.quarter", "moonphase.waxing.gibbous",
         "moonphase.full.moon", "moonphase.waning.gibbous", "moonphase.last.quarter", "moonphase.waning.crescent"][index]
    }

    var name: String {
        [String(localized: "New Moon"), String(localized: "Waxing Crescent"), String(localized: "First Quarter"),
         String(localized: "Waxing Gibbous"), String(localized: "Full Moon"), String(localized: "Waning Gibbous"),
         String(localized: "Last Quarter"), String(localized: "Waning Crescent")][index]
    }
}
