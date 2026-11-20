import SwiftUI

struct SunWidget: SuperWidget {
    typealias Settings = WeatherWidget.Settings
    static let id = "weather.sun"
    static var name: String { String(localized: "Sunrise & Sunset") }
    static let category = WidgetCategory.weather
    static let symbol = "sunrise"
    static let supportedSizes: [TileSize] = [.compact, .medium]
    static let usesNetwork = true
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        WeatherReportView(settings: settings) { report, _, now in
            SunView(report: report, now: now)
        }
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(WeatherSettings(settings: settings))
    }
}

/// Sun C · M: the day as an arc over a horizon with the sun where it is now. C names only the next event; after
/// sunset its arc resets to dawn, while M keeps the finished day.
struct SunView: View {
    @Environment(\.tile) private var tile
    let report: WeatherService.Report
    let now: Date

    private enum Phase { case beforeSunrise, day, afterSunset }

    private var phase: Phase {
        guard let sunrise = report.sunrise, let sunset = report.sunset else { return .day }
        return now < sunrise ? .beforeSunrise : now < sunset ? .day : .afterSunset
    }

    private var progress: Double {
        guard let sunrise = report.sunrise, let sunset = report.sunset, sunset > sunrise else { return 0.5 }
        return (now.timeIntervalSince(sunrise) / sunset.timeIntervalSince(sunrise)).unitClamped
    }

    var body: some View {
        Group {
            if tile.isCompact {
                compact
            } else if tile.isPortrait {
                VStack(spacing: 6 * tile.scale) {
                    SunArc(progress: progress, isUp: phase == .day).frame(height: tile.contentSize.width * 0.6)
                    times
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 10 * tile.scale) {
                    SunArc(progress: progress, isUp: phase == .day, overhang: 4).frame(width: tile.contentSize.width * 0.42)
                    times
                    Spacer(minLength: 0)
                }
            }
        }
        .tileTint(phase == .day ? [Palette.claude, Palette.hot] : [Color(rgb: 0x6A4FB8), Color(rgb: 0x4B3690)],
                  opacity: phase == .day ? 0.18 : 0.32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sunrise \(time(report.sunrise, amPM: true)), sunset \(time(report.sunset, amPM: true))")
    }

    private var compact: some View {
        let rising = phase != .day
        let next = phase == .afterSunset
            ? report.days.dropFirst().first?.sunrise ?? report.sunrise.map { $0.addingTimeInterval(86_400) }
            : rising ? report.sunrise : report.sunset
        return VStack(spacing: 3 * tile.scale) {
            SunArc(progress: phase == .afterSunset ? 0 : progress, isUp: phase == .day, overhang: 7)
                .frame(height: tile.contentSize.height * 0.55)
            event(rising: rising, time: time(next, amPM: false), style: .value)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var times: some View {
        VStack(alignment: .leading, spacing: 2 * tile.scale) {
            event(rising: true, time: time(report.sunrise, amPM: true))
            event(rising: false, time: time(report.sunset, amPM: true))
            if tile.showsDetail, let sunrise = report.sunrise, let sunset = report.sunset {
                let light = Duration.seconds(sunset.timeIntervalSince(sunrise))
                    .formatted(.units(allowed: [.hours, .minutes], width: .narrow))
                Text("\(light) light").tileStyle(.detail).padding(.top, 1 * tile.scale)
            }
        }
        .minimumScaleFactor(0.8)
    }

    private func event(rising: Bool, time: String, style: TileTextStyle = .title) -> some View {
        HStack(spacing: 4 * tile.scale) {
            Image(systemName: rising ? "arrow.up" : "arrow.down")
                .font(.system(size: 10 * tile.scale, weight: .bold)).foregroundStyle(tile.surface.primary)
            Text(time).tileStyle(style).monospacedDigit()
        }
    }

    private func time(_ date: Date?, amPM: Bool) -> String {
        guard let date else { return "–" }
        return clock(date, template: amPM ? "jmm" : "Jmm", in: report.timeZone)
    }
}

/// A half-circle sun path over a horizon line. Travelled path solid amber, the rest dotted; below the horizon the
/// sun is clipped to a dimmed half disc.
private struct SunArc: View {
    @Environment(\.tile) private var tile
    var progress: Double
    var isUp: Bool
    /// How far the horizon runs past the arc's feet, in tile points.
    var overhang: CGFloat = 6

    var body: some View {
        let scale = tile.scale
        let ink = (path: tile.surface.tertiary, horizon: tile.surface.tertiary)
        Canvas { context, size in
            let line = 2.2 * scale
            let dot = 4 * scale
            let radius = max(min(size.width / 2 - overhang * scale, size.height - dot - line), 1)
            let center = CGPoint(x: size.width / 2, y: (size.height + radius) / 2 + dot / 2)
            let point = { (fraction: Double) in
                CGPoint(x: center.x - radius * cos(.pi * fraction), y: center.y - radius * sin(.pi * fraction))
            }
            let arc = { (start: Double, end: Double) -> Path in
                var path = Path()
                path.addLines(stride(from: start, through: end, by: 1.0 / 48).map(point) + [point(end)])
                return path
            }
            if progress < 1 {
                context.stroke(arc(progress, 1), with: .color(ink.path),
                               style: StrokeStyle(lineWidth: line * 0.8, lineCap: .round, dash: [0.1, 3.4 * scale]))
            }
            if progress > 0 {
                context.stroke(arc(0, progress), with: .color(Palette.amber), style: StrokeStyle(lineWidth: line, lineCap: .round))
            }
            var horizon = Path()
            horizon.move(to: CGPoint(x: center.x - radius - overhang * scale, y: center.y))
            horizon.addLine(to: CGPoint(x: center.x + radius + overhang * scale, y: center.y))
            context.stroke(horizon, with: .color(ink.horizon), lineWidth: 1 * scale)

            let sun = point(progress)
            var above = context
            above.clip(to: Path(CGRect(x: 0, y: 0, width: size.width, height: center.y - 0.5 * scale)))
            let disc = Path(ellipseIn: CGRect(x: sun.x - dot, y: sun.y - dot, width: 2 * dot, height: 2 * dot))
            if isUp {
                above.addFilter(.shadow(color: Palette.amber.opacity(0.8), radius: 4 * scale))
                above.fill(disc, with: .color(Palette.claude))
            } else {
                above.fill(disc, with: .color(Color(rgb: 0xB07A3E)))
            }
        }
        .accessibilityHidden(true)
    }
}
