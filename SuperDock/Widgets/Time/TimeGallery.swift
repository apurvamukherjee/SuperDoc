#if DEBUG
import SwiftUI

extension GallerySheets {
    /// Time widgets.
    /// Compare with design/mockups/03-catalog-time-system-weather.png.
    static var time: AnyView? { AnyView(TimeSheet()) }
}

/// The mockup's moment: Thursday 19 November 2026, 10:55 PM in India (17:25 UTC), so the San Francisco and Tokyo
/// offsets and the epoch match the catalog exactly on any Mac.
@MainActor
private enum TimeFixtures {
    static let now = Date(timeIntervalSince1970: 1_795_109_100)
    static let home = TimeZone(identifier: "Asia/Kolkata") ?? .gmt

    static func calendar(_ locale: String = "en_US") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = home
        calendar.locale = Locale(identifier: locale)
        return calendar
    }

    static func world(_ zone: String, _ city: String, at date: Date = now) -> some View {
        WorldClockView(date: date, zone: TimeZone(identifier: zone) ?? .gmt, city: city, home: home, calendar: calendar())
    }

    static func moon(daysAfterNew days: Double) -> MoonPhase {
        MoonPhase(date: MoonPhase.knownNewMoon.addingTimeInterval(days * 86_400 + MoonPhase.synodicMonth * 86_400 * 300))
    }
}

private struct TimeSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 6) {
                heading("TIME · 9 WIDGETS · EVERY SIZE AND VARIANT", size: 12, secondary: true)
                heading("Time", size: 44)
            }
            ForEach([SurfaceStyle.glassDark, .solidLight, .paper], id: \.self) { StylePanel(style: $0) }
            ScalePanel()
        }
        .padding(60)
        .background(Color(rgb: 0x11131C))
    }
}

private func heading(_ text: String, size: CGFloat, secondary: Bool = false, dark: Bool = true) -> some View {
    let ink = dark ? Color.white : Palette.ink
    return Text(text).font(.system(size: size, weight: size > 20 ? .bold : .semibold))
        .foregroundStyle(secondary ? ink.opacity(0.6) : ink)
}

/// The catalog's two Time rows, as in the mockup.
private struct CatalogRows: View {
    let style: SurfaceStyle
    var unit: CGFloat = 73
    var labelled = true

    private func tile(_ view: some View, _ size: TileSize) -> some View {
        view.asTile(TileContext(unit: unit, size: size, surface: SurfaceTokens(style)))
    }

    var body: some View {
        let now = TimeFixtures.now
        let calendar = TimeFixtures.calendar()
        let iso = TimeMath.isoWeek(of: now, timeZone: calendar.timeZone)
        VStack(alignment: .leading, spacing: 14) {
            if labelled { label("Clock C · M — Date C · M — World Clock C · M — Analog C — Progress C · M") }
            GalleryBar(surface: SurfaceTokens(style)) {
                tile(ClockWidgetView(date: now, calendar: calendar), .compact)
                tile(ClockWidgetView(date: now.addingTimeInterval(42), showsSeconds: true, calendar: calendar), .medium)
                tile(DateWidgetView(date: now, calendar: calendar), .compact)
                tile(DateWidgetView(date: now, calendar: calendar), .medium)
                tile(TimeFixtures.world("America/Los_Angeles", "San Fran"), .compact)
                tile(TimeFixtures.world("Asia/Tokyo", "Tokyo"), .medium)
                tile(AnalogClockView(date: now.addingTimeInterval(12), calendar: calendar), .compact)
                tile(PeriodProgressView(period: .day, date: now, calendar: calendar), .compact)
                tile(PeriodProgressView(period: .year, date: now, calendar: calendar), .medium)
            }
            if labelled { label("Week Number C — Unix Time M — Moon Phase C · M — Month Calendar W · L") }
            GalleryBar(surface: SurfaceTokens(style)) {
                tile(WeekNumberView(week: iso.week, weeksInYear: iso.weeksInYear), .compact)
                tile(UnixTimeView(date: now), .medium)
                tile(MoonPhaseView(phase: MoonPhase(date: now)), .compact)
                tile(MoonPhaseView(phase: MoonPhase(date: now)), .medium)
                tile(MonthCalendarView(date: now, calendar: calendar), .wide)
                tile(MonthCalendarView(date: now, calendar: calendar), .large)
            }
        }
    }

    private func label(_ text: String) -> some View { heading(text, size: 13, secondary: true, dark: style.isDark) }
}

/// The catalog rows, then every variant, then the vertical bar, all in one style.
private struct StylePanel: View {
    let style: SurfaceStyle

    private func tile(_ view: some View, _ size: TileSize, portrait: Bool = false) -> some View {
        view.asTile(TileContext(size: size, isPortrait: portrait, surface: SurfaceTokens(style)))
    }

    var body: some View {
        let now = TimeFixtures.now
        let calendar = TimeFixtures.calendar()
        VStack(alignment: .leading, spacing: 14) {
            heading(style.rawValue, size: 17, dark: style.isDark)
            CatalogRows(style: style)
            label("Variants: no seconds · 24-hour · seconds in compact · night C / day M · progress periods")
            GalleryBar(surface: SurfaceTokens(style)) {
                tile(ClockWidgetView(date: now, calendar: calendar), .medium)
                tile(ClockWidgetView(date: now, calendar: TimeFixtures.calendar("en_GB")), .medium)
                tile(ClockWidgetView(date: now.addingTimeInterval(42), showsSeconds: true, calendar: calendar), .compact)
                tile(TimeFixtures.world("Europe/London", "London"), .compact)
                tile(TimeFixtures.world("America/New_York", "New York"), .medium)
                tile(TimeFixtures.world("Asia/Kolkata", "Bengaluru"), .compact)
                tile(PeriodProgressView(period: .year, date: now, calendar: calendar), .compact)
                tile(PeriodProgressView(period: .day, date: now, calendar: calendar), .medium)
                tile(PeriodProgressView(period: .week, date: now, calendar: calendar), .medium)
                tile(PeriodProgressView(period: .month, date: now, calendar: calendar), .medium)
            }
            label("Moon: new · waxing crescent · first quarter · waxing gibbous · full · waning gibbous · last quarter · waning crescent")
            GalleryBar(surface: SurfaceTokens(style)) {
                ForEach([0.0, 4, 7.4, 11, 14.8, 19, 22.1, 26], id: \.self) { days in
                    tile(MoonPhaseView(phase: TimeFixtures.moon(daysAfterNew: days)), .compact)
                }
                tile(MoonPhaseView(phase: TimeFixtures.moon(daysAfterNew: 26)), .medium)
            }
            label("Vertical bar (portrait): Clock · Date · World Clock · Progress · Unix · Moon M — Month W · L")
            GalleryBar(surface: SurfaceTokens(style)) {
                HStack(alignment: .top, spacing: TileContext.spacing) {
                    tile(ClockWidgetView(date: now.addingTimeInterval(42), showsSeconds: true, calendar: calendar), .medium, portrait: true)
                    tile(DateWidgetView(date: now, calendar: calendar), .medium, portrait: true)
                    tile(TimeFixtures.world("Asia/Tokyo", "Tokyo"), .medium, portrait: true)
                    tile(PeriodProgressView(period: .year, date: now, calendar: calendar), .medium, portrait: true)
                    tile(UnixTimeView(date: now), .medium, portrait: true)
                    tile(MoonPhaseView(phase: MoonPhase(date: now)), .medium, portrait: true)
                    tile(MonthCalendarView(date: now, calendar: calendar), .wide, portrait: true)
                    tile(MonthCalendarView(date: now, calendar: calendar), .large, portrait: true)
                }
            }
        }
        .padding(28)
        .background(galleryWallpaper(style), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func label(_ text: String) -> some View { heading(text, size: 13, secondary: true, dark: style.isDark) }
}

/// Both catalog rows at a tiny (56 pt) and a huge (120 pt) Dock.
private struct ScalePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Scale: 56 pt tight · 120 pt roomy (glass-dark)", size: 17)
            ForEach([56, 120], id: \.self) { bar in
                CatalogRows(style: .glassDark, unit: CGFloat(bar) - 2 * TileContext.spacing, labelled: false)
            }
        }
        .padding(28)
        .background(galleryWallpaper(.glassDark), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
#endif
