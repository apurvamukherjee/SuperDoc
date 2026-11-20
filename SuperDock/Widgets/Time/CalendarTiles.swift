import SwiftUI

// Pure calendar tiles (Date, Progress, Week Number, Month): plain values in, kit archetypes out.

// MARK: - Date

/// Compact is a tear-off leaf; M is a coral stub torn along a dashed perforation.
struct DateWidgetView: View {
    @Environment(\.tile) private var tile
    var date: Date
    var calendar = Calendar.current

    var body: some View {
        Group {
            if tile.isCompact {
                leaf
            } else if tile.isPortrait {
                VStack(spacing: 8 * tile.scale) {
                    stub.frame(height: 0.72 * tile.unit)
                        .background { Palette.today.tileBleed([.top, .horizontal]) }
                        .overlay(alignment: .bottom) { perforation(.horizontal).tileBleed(.horizontal) }
                    lines(alignment: .center).minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 12 * tile.scale) {
                    stub.frame(width: 0.72 * tile.unit - tile.padding)
                        .background { Palette.today.tileBleed([.leading, .vertical]) }
                        .overlay(alignment: .trailing) { perforation(.vertical).tileBleed(.vertical) }
                    lines(alignment: .leading)
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TimeText.string(date, .dateTime.weekday(.wide).day().month(.wide), calendar: calendar))
    }

    /// Same leaf as the kit's `CalendarTile`, except the coral band runs to the tile's edges as in the mockup
    /// (the kit's leaf stays inside the padding).
    private var leaf: some View {
        VStack(spacing: 0) {
            Text(TimeText.weekday(date, .abbreviated, calendar: calendar))
                .tileStyle(.label, color: .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 1.5 * tile.scale)
                .background { Palette.today.tileBleed([.top, .horizontal]) }
            Text("\(calendar.component(.day, from: date))").tileStyle(.display)
                .frame(maxHeight: .infinity)
        }
    }

    private var stub: some View {
        VStack(spacing: -2 * tile.scale) {
            Text(TimeText.string(date, .dateTime.month(.abbreviated), calendar: calendar))
                .tileStyle(.label, color: .white.opacity(0.9))
            Text("\(calendar.component(.day, from: date))").tileStyle(.display, color: .white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func lines(alignment: HorizontalAlignment) -> some View {
        let left = TimeMath.daysLeft(in: .year, at: date, calendar: calendar)
        return VStack(alignment: alignment, spacing: 2 * tile.scale) {
            Text(TimeText.weekday(date, calendar: calendar)).tileStyle(.title)
            Text(String(localized: "Week \(TimeMath.isoWeek(of: date, timeZone: calendar.timeZone).week)")).tileStyle(.detail)
            Text(left == 0 ? String(localized: "Last day of the year")
                 : left == 1 ? String(localized: "1 day left") : String(localized: "\(left) days left"))
                .tileStyle(.detail)
        }
    }

    private func perforation(_ axis: Axis) -> some View {
        let dash = StrokeStyle(lineWidth: 1.5 * tile.scale, dash: [3 * tile.scale, 2.5 * tile.scale])
        return Canvas { context, size in
            var path = Path()
            path.move(to: .zero)
            path.addLine(to: axis == .vertical ? CGPoint(x: 0, y: size.height) : CGPoint(x: size.width, y: 0))
            context.stroke(path, with: .color(Palette.ink.opacity(0.55)), style: dash)
        }
        .frame(width: axis == .vertical ? dash.lineWidth : nil, height: axis == .horizontal ? dash.lineWidth : nil)
    }
}

// MARK: - Progress

/// Compact and portrait are a glass filling from the bottom; wider tiles count the period off in segments
/// (months of the year, days of the week…).
struct PeriodProgressView: View {
    @Environment(\.tile) private var tile
    var period: ProgressWidget.Period
    var date: Date
    var calendar = Calendar.current

    var body: some View {
        let fraction = TimeMath.progress(through: period.component, at: date, calendar: calendar)
        let percent = "\(Int(fraction * 100))"
        Group {
            if tile.isCompact || tile.isPortrait {
                VStack(alignment: .leading, spacing: 0) {
                    Text(period.label).tileStyle(.label, color: tile.surface.primary.opacity(0.85))
                    Spacer(minLength: 0)
                    HeroText(value: percent + "%")
                    if tile.isPortrait { Text(remaining).tileStyle(.detail, color: tile.surface.primary.opacity(0.75)) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background { GlassFill(fraction: fraction).tileBleed(.all) }
            } else {
                SlotStack(label: longLabel, badge: remaining, badgeColor: tile.surface.secondary) {
                    HeroText(value: percent, unit: "%")
                } bottom: {
                    SegmentBar(count: TimeMath.segments(of: period.component, at: date, calendar: calendar), fraction: fraction)
                        .padding(.bottom, 2 * tile.scale)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(period.label) progress"))
        .accessibilityValue("\(percent)%, \(remaining)")
    }

    /// "Year 2026", "Week 47", "November", "Today".
    private var longLabel: String {
        switch period {
        case .day: String(localized: "Today")
        case .week: String(localized: "Week \(TimeMath.isoWeek(of: date, timeZone: calendar.timeZone).week)")
        case .month: TimeText.string(date, .dateTime.month(.wide), calendar: calendar)
        case .year: String(localized: "Year \(String(calendar.component(.year, from: date)))")
        }
    }

    /// "42 d left"; hours and minutes in the last day.
    private var remaining: String {
        let days = TimeMath.daysLeft(in: period.component, at: date, calendar: calendar)
        if days > 0 { return String(localized: "\(days) d left") }
        let minutes = Int(TimeMath.remaining(through: period.component, at: date, calendar: calendar) / 60)
        return minutes >= 60 ? String(localized: "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m left")
                             : String(localized: "\(minutes)m left")
    }
}

private struct GlassFill: View {
    @Environment(\.tile) private var tile
    var fraction: Double

    var body: some View {
        let strength = tile.surface.isDark ? 1.0 : 0.6
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(colors: [Palette.progress.opacity(0.62 * strength), Palette.progress.opacity(0.4 * strength)],
                               startPoint: .top, endPoint: .bottom)
                    .overlay(alignment: .top) { Palette.progress.frame(height: 1.5 * tile.scale) }
                    .frame(height: geo.size.height * fraction.unitClamped)
            }
        }
        .tileAnimation(value: fraction)
        .accessibilityHidden(true)
    }
}

/// A progress bar cut into the period's natural units; the current unit fills partially.
private struct SegmentBar: View {
    @Environment(\.tile) private var tile
    var count: Int
    var fraction: Double

    var body: some View {
        HStack(spacing: (count > 12 ? 1.5 : 3) * tile.scale) {
            ForEach(0..<count, id: \.self) { index in
                let fill = (fraction * Double(count) - Double(index)).unitClamped
                GeometryReader { geo in
                    tile.surface.track.overlay(alignment: .leading) {
                        Palette.progress.frame(width: geo.size.width * fill)
                    }
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: 4.5 * tile.scale)
        .tileAnimation(value: fraction)
        .accessibilityHidden(true)
    }
}

// MARK: - Week number

struct WeekNumberView: View {
    @Environment(\.tile) private var tile
    var week: Int
    var weeksInYear: Int

    var body: some View {
        VStack(spacing: -1 * tile.scale) {
            Text("Week").tileStyle(.label)
            Text("\(week)").tileStyle(.display)
            if tile.showsDetail { Text(String(localized: "of \(weeksInYear)")).tileStyle(.detail) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Week \(week) of \(weeksInYear)"))
    }
}

// MARK: - Month

/// W: this week and next under a weekday header. L: last, this and next week beside the ISO week number.
/// Portrait turns the weeks into columns, one row per weekday.
struct MonthCalendarView: View {
    @Environment(\.tile) private var tile
    var date: Date
    var calendar = Calendar.current

    private var isLarge: Bool { tile.size == .large }
    private var coral: Color { tile.surface.isDark ? Palette.today : tile.surface.danger }

    var body: some View {
        Group {
            if tile.isPortrait { portrait } else { horizontal }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TimeText.string(date, .dateTime.weekday(.wide).day().month(.wide).year(), calendar: calendar))
        .accessibilityValue(String(localized: "Week \(TimeMath.isoWeek(of: date, timeZone: calendar.timeZone).week)"))
    }

    private var horizontal: some View {
        HStack(spacing: 12 * tile.scale) {
            VStack(alignment: .leading, spacing: 0) {
                Text(TimeText.string(date, .dateTime.month(isLarge ? .wide : .abbreviated), calendar: calendar))
                    .tileStyle(.label, color: coral)
                Text(isLarge ? "W\(TimeMath.isoWeek(of: date, timeZone: calendar.timeZone).week)" : "\(day(date))")
                    .tileStyle(.hero)
            }
            .fixedSize()
            .padding(.leading, 2 * tile.scale)
            if isLarge { Divider().overlay(tile.surface.divider) }
            Grid(horizontalSpacing: 0, verticalSpacing: (isLarge ? 4 : 2) * tile.scale) {
                if !isLarge {
                    GridRow {
                        ForEach(week(0), id: \.self) { Text(TimeText.weekday($0, .narrow, calendar: calendar)).tileStyle(.caption) }
                    }
                }
                ForEach(isLarge ? [-1, 0, 1] : [0, 1], id: \.self) { offset in
                    GridRow {
                        ForEach(week(offset), id: \.self) { cell($0).frame(maxWidth: .infinity) }
                    }
                }
            }
        }
    }

    private var portrait: some View {
        let columns = (isLarge ? [0, 1] : [0]).map(week)
        return VStack(spacing: 6 * tile.scale) {
            VStack(spacing: 0) {
                Text(TimeText.string(date, .dateTime.month(.abbreviated), calendar: calendar)).tileStyle(.label, color: coral)
                Text("\(day(date))").tileStyle(.hero)
            }
            Divider().overlay(tile.surface.divider)
            Grid(horizontalSpacing: 7 * tile.scale, verticalSpacing: 0) {
                ForEach(Array(week(0).enumerated()), id: \.offset) { index, first in
                    GridRow {
                        Text(TimeText.weekday(first, .narrow, calendar: calendar)).tileStyle(.caption)
                        ForEach(columns.indices, id: \.self) { column in
                            if columns[column].indices.contains(index) { cell(columns[column][index]) }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }

    private func cell(_ day: Date) -> some View {
        let isToday = calendar.isDate(day, inSameDayAs: date)
        let isPast = day < calendar.startOfDay(for: date)
        // L has no weekday header, so dimmed weekends carry the week's shape instead.
        let dim = isPast || (isLarge && !tile.isPortrait && calendar.isDateInWeekend(day))
        return Text("\(self.day(day))")
            .tileStyle(.title, color: isToday ? .white : dim ? tile.surface.secondary : tile.surface.primary)
            .fontWeight(isToday ? .bold : .medium)
            .monospacedDigit()
            .fixedSize()
            .background {
                // The pill overhangs the digits instead of padding them, so every column keeps the same width.
                if isToday {
                    Capsule().fill(Palette.today)
                        .padding(.horizontal, (tile.isPortrait ? -3 : -5) * tile.scale)
                        .padding(.vertical, -1 * tile.scale)
                }
            }
    }

    private func day(_ date: Date) -> Int { calendar.component(.day, from: date) }

    /// The seven days of the week containing `date`, shifted by `offset` weeks; honours the locale's first weekday.
    private func week(_ offset: Int) -> [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start,
              let shifted = calendar.date(byAdding: .weekOfYear, value: offset, to: start) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: shifted) }
    }
}
