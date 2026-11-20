import SwiftUI

// Pure time tiles: plain values in, kit archetypes out. The widgets in this folder only add the TimelineView, so the
// gallery can draw any moment in any zone without a clock running.

/// Formats in the calendar's own zone, so a fixed fixture renders the same on any Mac.
enum TimeText {
    static func string(_ date: Date, _ style: Date.FormatStyle, calendar: Calendar) -> String {
        var style = style
        style.timeZone = calendar.timeZone
        style.calendar = calendar
        style.locale = calendar.locale ?? .current
        return date.formatted(style)
    }

    /// "Thu 19"
    static func weekdayDay(_ date: Date, calendar: Calendar) -> String {
        string(date, .dateTime.weekday(.abbreviated).day(), calendar: calendar)
    }

    static func weekday(_ date: Date, _ width: Date.FormatStyle.Symbol.Weekday = .wide, calendar: Calendar) -> String {
        string(date, .dateTime.weekday(width), calendar: calendar)
    }
}

/// "10:55" with the seconds and AM/PM split out, so each can sit in its own slot.
struct ClockText {
    var time: String
    var seconds: String
    /// nil when the system clock is 24-hour.
    var period: String?

    init(date: Date, calendar: Calendar) {
        seconds = String(format: ":%02d", calendar.component(.second, from: date))
        let twelveHour = [.oneToTwelve, .zeroToEleven].contains((calendar.locale ?? .current).hourCycle)
        let period = twelveHour ? (calendar.component(.hour, from: date) < 12 ? calendar.amSymbol : calendar.pmSymbol) : nil
        self.period = period
        // `amPM: .omitted` zero-pads the hour ("09:25"), so format the locale's own short time and lift the period out.
        let full = TimeText.string(date, .dateTime.hour().minute(), calendar: calendar)
        time = period.map { full.replacingOccurrences(of: $0, with: "").trimmingCharacters(in: .whitespaces) } ?? full
    }
}

// MARK: - Clock

struct ClockWidgetView: View {
    @Environment(\.tile) private var tile
    var date: Date
    var showsSeconds = false
    var calendar = Calendar.current

    var body: some View {
        let text = ClockText(date: date, calendar: calendar)
        Group {
            if tile.isPortrait {
                portrait(text)
            } else if tile.isCompact {
                // Seconds outrank the date here: the user turned them on to see them.
                let detail = showsSeconds ? [text.seconds, text.period] : [TimeText.weekdayDay(date, calendar: calendar), text.period]
                ClockTile(time: text.time, detail: detail.compactMap(\.self).joined(separator: " · "))
                    .minimumScaleFactor(0.75)
            } else {
                let detail = showsSeconds
                    ? [TimeText.weekday(date, calendar: calendar), text.period].compactMap(\.self).joined(separator: " · ")
                    : TimeText.string(date, .dateTime.weekday(.wide).day().month(.wide), calendar: calendar)
                ClockTile(time: text.time, period: showsSeconds ? text.seconds : text.period, detail: detail)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TimeText.string(date, showsSeconds ? .dateTime.hour().minute().second() : .dateTime.hour().minute(),
                                            calendar: calendar))
    }

    private func portrait(_ text: ClockText) -> some View {
        VStack(spacing: 2 * tile.scale) {
            Spacer(minLength: 0)
            Text(text.time).tileStyle(.heroCompact).minimumScaleFactor(0.7)
            if let sub = showsSeconds ? text.seconds : text.period { Text(sub).tileStyle(.heroUnit) }
            Spacer(minLength: 0)
            Text(TimeText.weekday(date, .abbreviated, calendar: calendar)).tileStyle(.label)
            Text("\(calendar.component(.day, from: date))").tileStyle(.hero)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - World Clock

/// A city's time on its own sky: daylight blue with ink text, or night indigo with a crescent.
struct WorldClockView: View {
    @Environment(\.tile) private var tile
    var date: Date
    var zone: TimeZone
    var city: String
    /// The Mac's own zone, for the "+3½h" offset.
    var home = TimeZone.current
    /// Locale and week rules; its zone is replaced by `zone`.
    var calendar = Calendar.current

    var body: some View {
        var calendar = calendar
        calendar.timeZone = zone
        let text = ClockText(date: date, calendar: calendar)
        let isDay = TimeMath.isDaytime(hour: calendar.component(.hour, from: date))
        let shift = TimeMath.offsetLabel(minutes: (zone.secondsFromGMT(for: date) - home.secondsFromGMT(for: date)) / 60)
        let offset = shift ?? String(localized: "Same time")
        // "PM · Same time" overflows a compact tile; the period adds nothing when it is your own time anyway.
        let compactDetail = shift.map { [text.period, $0].compactMap(\.self).joined(separator: " · ") } ?? offset
        let weekday = TimeText.weekday(date, .abbreviated, calendar: calendar)
        var sky = tile
        // The sky replaces the tile fill, so text takes its colours from a matching solid surface.
        sky.surface = SurfaceTokens(isDay ? .solidLight : .solidDark)

        return content(text: text, isDay: isDay, weekday: weekday, offset: offset, compactDetail: compactDetail)
            .environment(\.tile, sky)
            .environment(\.colorScheme, isDay ? .light : .dark)
            .tileTint(isDay ? [Color(rgb: 0x4DA2FF), Color(rgb: 0x93D2FF)] : [Color(rgb: 0x13164A), Color(rgb: 0x2C3090)])
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(city), \(TimeText.string(date, .dateTime.hour().minute(), calendar: calendar))")
            .accessibilityValue("\(weekday), \(offset)")
    }

    @ViewBuilder
    private func content(text: ClockText, isDay: Bool, weekday: String, offset: String, compactDetail: String) -> some View {
        let glyph = Image(systemName: isDay ? "sun.max.fill" : "moon.fill")
            .font(.system(size: 14 * tile.scale, weight: .semibold))
            .foregroundStyle(isDay ? Palette.amber : Color(rgb: 0xFFE39A))
        if tile.isPortrait {
            VStack(alignment: .leading, spacing: 2 * tile.scale) {
                Text(city).tileStyle(.label).minimumScaleFactor(0.6)
                glyph
                Spacer(minLength: 0)
                Text(text.time).tileStyle(.heroCompact).minimumScaleFactor(0.7)
                if let period = text.period { Text(period).tileStyle(.caption) }
                Spacer(minLength: 0)
                Text(weekday).tileStyle(.detail)
                Text(offset).tileStyle(.detail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if tile.isCompact {
            SlotStack(label: city) {
                HeroText(value: text.time).minimumScaleFactor(0.6)
            } bottom: {
                Text(compactDetail).tileStyle(.detail).minimumScaleFactor(0.8)
            }
            .minimumScaleFactor(0.7)
        } else {
            SlotStack(label: city) {
                HeroText(value: text.time, unit: text.period, style: .display)
            } bottom: {
                Text("\(weekday) · \(offset)").tileStyle(.detail)
            }
            .overlay(alignment: .topTrailing) { glyph.padding(.trailing, 8 * tile.scale).padding(.top, 6 * tile.scale) }
            .padding(.leading, 2 * tile.scale)
        }
    }
}

// MARK: - Analog

struct AnalogClockView: View {
    @Environment(\.tile) private var tile
    var date: Date
    var calendar = Calendar.current

    var body: some View {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let seconds = Double(parts.second ?? 0)
        let minutes = Double(parts.minute ?? 0) + seconds / 60
        let hours = Double((parts.hour ?? 0) % 12) + minutes / 60
        let surface = tile.surface
        let scale = tile.scale
        Canvas { canvas, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let face = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            canvas.fill(face, with: .color(surface.chipFill))
            canvas.stroke(face, with: .color(surface.divider), lineWidth: 1)

            func point(_ turns: Double, _ length: CGFloat) -> CGPoint {
                let angle = turns * 2 * .pi - .pi / 2
                return CGPoint(x: center.x + cos(angle) * radius * length, y: center.y + sin(angle) * radius * length)
            }
            func line(_ turns: Double, from start: CGFloat, to end: CGFloat, width: CGFloat, color: Color) {
                var path = Path()
                path.move(to: point(turns, start))
                path.addLine(to: point(turns, end))
                canvas.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }

            for hour in 0..<12 {
                line(Double(hour) / 12, from: 0.74, to: 0.86, width: 1.4 * scale, color: surface.tertiary)
            }
            line(hours / 12, from: 0, to: 0.5, width: 3 * scale, color: surface.primary)
            line(minutes / 60, from: 0, to: 0.76, width: 2.2 * scale, color: surface.primary)
            line(seconds / 60, from: -0.16, to: 0.82, width: 1.1 * scale, color: Palette.coral)
            let dot = 2.4 * scale
            canvas.fill(Path(ellipseIn: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2)),
                        with: .color(Palette.coral))
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(TimeText.string(date, .dateTime.hour().minute(), calendar: calendar))
    }
}

// MARK: - Unix time

/// A terminal prompt: `$ date +%s`, the epoch with a block cursor, UTC under it.
struct UnixTimeView: View {
    @Environment(\.tile) private var tile
    var date: Date
    var onCopy: (String) -> Void = { _ in }
    @State private var copied = false

    var body: some View {
        let epoch = String(Int(date.timeIntervalSince1970))
        let utc = date.formatted(.iso8601.time(includingFractionalSeconds: false).timeSeparator(.colon))
        let green = tile.surface.isDark ? Palette.good : tile.surface.good
        Group {
            if tile.isPortrait {
                VStack(alignment: .leading, spacing: 2 * tile.scale) {
                    prompt(green)
                    copyButton
                    Spacer(minLength: 0)
                    Group {
                        Text(epoch.prefix(5))
                        Text(epoch.dropFirst(5)) + Text(verbatim: "▌").foregroundStyle(green)
                    }
                    .tileStyle(.monoHero)
                    .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                    Text(utc).tileStyle(.mono, color: tile.surface.secondary)
                    Text("UTC").tileStyle(.mono, color: tile.surface.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        prompt(green)
                        Spacer(minLength: 0)
                        copyButton
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 1.5 * tile.scale) { Text(epoch).tileStyle(.monoHero); cursor(green) }
                    Spacer(minLength: 0)
                    Text("\(utc) UTC").tileStyle(.mono, color: tile.surface.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 2 * tile.scale)
        .tileTint(tile.surface.isDark ? Palette.inkDeep : nil, opacity: 0.55)
        .textSelection(.enabled)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Unix time \(epoch)"))
        .task(id: copied) {
            guard copied else { return }
            do {
                try await Task.sleep(for: .seconds(1.2))
            } catch {
                return // cancelled: the tile went away, nothing to reset
            }
            copied = false
        }
    }

    private func prompt(_ green: Color) -> some View {
        Text(verbatim: "$ DATE +%S").tileStyle(.mono, color: green).fontWeight(.bold).minimumScaleFactor(0.6)
    }

    private var copyButton: some View {
        TileIconButton(symbol: copied ? "checkmark" : "doc.on.doc", label: String(localized: "Copy"), style: .glyph,
                       diameter: 18) {
            onCopy(String(Int(date.timeIntervalSince1970)))
            copied = true
        }
        .opacity(0.7)
        .tileAnimation(value: copied)
    }

    /// Static on purpose: a blinking cursor would wake the tile twice a second for nothing.
    private func cursor(_ green: Color) -> some View {
        green.frame(width: 8 * tile.scale, height: 16 * tile.scale)
    }
}
