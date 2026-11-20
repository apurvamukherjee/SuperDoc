import SwiftUI

struct WeatherWidget: SuperWidget {
    struct Settings: Codable, Equatable {
        var place: WeatherService.Place?
        var unit: WeatherService.Unit = Locale.current.measurementSystem == .us ? .fahrenheit : .celsius
    }

    static let id = "weather.current"
    static var name: String { String(localized: "Weather") }
    static let category = WidgetCategory.weather
    static let symbol = "cloud.sun"
    static let supportedSizes: [TileSize] = [.compact, .medium, .wide]
    static let usesNetwork = true
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        WeatherReportView(settings: settings) { report, place, now in
            CurrentWeatherView(report: report, city: place.city, now: now)
        }
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(WeatherSettings(settings: settings))
    }
}

/// Weather C · M · W. Archetype: Stat (label, hero, detail) washed in a sky that follows condition and time of day.
struct CurrentWeatherView: View {
    @Environment(\.tile) private var tile
    let report: WeatherService.Report
    let city: String
    let now: Date

    private var isDay: Bool { report.isDay(at: now) }
    private var symbol: String { weatherSymbol(report.weatherCode, isDay: isDay) }

    var body: some View {
        Group {
            if tile.isCompact {
                VStack(spacing: 5 * tile.scale) {
                    WeatherSymbol(name: symbol, size: 24)
                    Text(degrees(report.temperature)).tileStyle(.heroCompact)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tile.isPortrait {
                portrait
            } else if tile.tier == .tight {
                HStack(spacing: 8 * tile.scale) {
                    inline
                    if tile.size == .wide { HourlyStrip(report: report, showsHour: false) }
                }
            } else {
                landscape
            }
        }
        .onSky(Sky.colors(for: report, at: now))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(city): \(degrees(report.temperature)), \(report.condition). "
                            + "High \(degrees(report.high)), low \(degrees(report.low))")
    }

    private var inline: some View {
        HStack(spacing: 6 * tile.scale) {
            WeatherSymbol(name: symbol, size: 20)
            Text(degrees(report.temperature)).tileStyle(.hero)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var landscape: some View {
        HStack(spacing: 10 * tile.scale) {
            VStack(alignment: .leading, spacing: 0) {
                Text(city).tileStyle(.label)
                Spacer(minLength: 0)
                Text(degrees(report.temperature)).tileStyle(.display)
                Spacer(minLength: 0)
                HStack(spacing: 4 * tile.scale) {
                    if tile.size == .wide {
                        Text("\(report.condition) · H \(degrees(report.high))").tileStyle(.detail)
                    } else {
                        Text("H \(degrees(report.high)) · L \(degrees(report.low))").tileStyle(.detail)
                        Spacer(minLength: 4)
                        Text(report.condition).tileStyle(.detail).minimumScaleFactor(0.75)
                    }
                }
            }
            .fixedSize(horizontal: tile.size == .wide, vertical: false)
            if tile.size == .wide { HourlyStrip(report: report, showsHour: true) }
        }
        .overlay(alignment: .topTrailing) {
            if tile.size == .medium { WeatherSymbol(name: symbol, size: 21).padding(.top, 2 * tile.scale) }
        }
    }

    private var portrait: some View {
        VStack(spacing: 3 * tile.scale) {
            if tile.showsLabel { Text(city).tileStyle(.label).minimumScaleFactor(0.7) }
            Spacer(minLength: 0)
            WeatherSymbol(name: symbol, size: 24)
            Text(degrees(report.temperature)).tileStyle(.hero)
            if tile.showsDetail {
                Text("\(degrees(report.high)) · \(degrees(report.low))").tileStyle(.detail)
            }
            Spacer(minLength: 0)
            if tile.size != .medium {
                VStack(spacing: tile.rowSpacing) {
                    ForEach(Array(report.hours.prefix(4).enumerated()), id: \.offset) { index, hour in
                        HStack(spacing: 3 * tile.scale) {
                            Text(hourLabel(hour.date, index: index, in: report.timeZone)).tileStyle(.detail)
                            Spacer(minLength: 0)
                            WeatherSymbol(name: weatherSymbol(hour.weatherCode ?? report.weatherCode,
                                                              isDay: report.isDay(at: hour.date)), size: 11)
                            Text(hour.temperature.map(degrees) ?? "–").tileStyle(.detail, color: tile.surface.primary)
                                .fontWeight(.semibold)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// "Now 12 1 2" columns: hour, symbol, temperature.
private struct HourlyStrip: View {
    @Environment(\.tile) private var tile
    let report: WeatherService.Report
    let showsHour: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(report.hours.prefix(4).enumerated()), id: \.offset) { index, hour in
                VStack(spacing: 3 * tile.scale) {
                    if showsHour {
                        Text(hourLabel(hour.date, index: index, in: report.timeZone))
                            .tileStyle(.detail, color: tile.surface.primary).fontWeight(.semibold)
                    }
                    WeatherSymbol(name: weatherSymbol(hour.weatherCode ?? report.weatherCode,
                                                      isDay: report.isDay(at: hour.date)), size: 14)
                        .frame(height: 16 * tile.scale)
                    Text(hour.temperature.map(degrees) ?? "–").tileStyle(.title)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2 * tile.scale)
    }
}

func hourLabel(_ date: Date, index: Int, in timeZone: TimeZone) -> String {
    index == 0 ? String(localized: "Now") : clock(date, template: "J", in: timeZone)
}

/// Locale-aware clock text in the place's zone. Templates: "J" hour, "Jmm" hour:minute without AM/PM, "jmm" with it.
/// (FormatStyle's amPM-omitted hour pads to "07", which the mockups don't.)
func clock(_ date: Date, template: String, in timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.setLocalizedDateFormatFromTemplate(template)
    return formatter.string(from: date)
}

func degrees(_ value: Double) -> String {
    "\(Int(value.rounded()))°"
}

/// The `.fill` symbol for a WMO code, with the moon standing in for the sun after dark.
func weatherSymbol(_ code: Int, isDay: Bool = true) -> String {
    if !isDay, code == 0 { return "moon.fill" }
    if !isDay, code == 1 || code == 2 { return "cloud.moon.fill" }
    let base = WeatherService.symbol(for: code)
    return base == "questionmark" ? base : base + ".fill"
}

/// A multicolour condition symbol sized in tile points.
struct WeatherSymbol: View {
    @Environment(\.tile) private var tile
    let name: String
    var size: CGFloat

    var body: some View {
        let image = Image(systemName: name).font(.system(size: size * tile.scale))
        // SF's multicolour moon is plain ink; give it the moonlight it has in the mockups.
        if name.hasPrefix("moon") {
            image.foregroundStyle(Color(rgb: 0xFFE08A))
        } else if tile.surface.isDark {
            image.symbolRenderingMode(.multicolor)
        } else {
            // Multicolour clouds are white and vanish on light tiles, so light styles get grey clouds instead.
            image.symbolRenderingMode(.palette).foregroundStyle(name.hasPrefix("sun") ? Palette.amber : Color(rgb: 0x9AA3B2), accent)
        }
    }

    private var accent: Color {
        if name.contains("rain") || name.contains("drizzle") { return Palette.working }
        if name.contains("snow") { return Palette.water }
        return name.contains("sun") || name.contains("bolt") ? Palette.amber : Color(rgb: 0x9AA3B2)
    }
}

extension WeatherService.Place {
    /// "Lisbon, Portugal" → "Lisbon".
    var city: String { name.components(separatedBy: ",").first ?? name }
}

extension WeatherService.Report {
    func isTwilight(at date: Date) -> Bool {
        [sunrise, sunset].contains { event in event.map { abs($0.timeIntervalSince(date)) < 40 * 60 } ?? false }
    }

    var condition: String {
        switch weatherCode {
        case 0: String(localized: "Clear")
        case 1: String(localized: "Mostly clear")
        case 2: String(localized: "Partly cloudy")
        case 3: String(localized: "Cloudy")
        case 45, 48: String(localized: "Fog")
        case 51...57: String(localized: "Drizzle")
        case 61...67: String(localized: "Rain")
        case 80...82: String(localized: "Showers")
        case 71...77, 85, 86: String(localized: "Snow")
        case 95...99: String(localized: "Storms")
        default: "–"
        }
    }
}

/// Sky gradients measured off the mockup (clear day, clear night, rain), the rest extrapolated in the same spirit.
enum Sky {
    static func colors(for report: WeatherService.Report, at date: Date) -> [Color] {
        let day = report.isDay(at: date)
        let pair: (UInt32, UInt32)
        if report.weatherCode <= 2, report.isTwilight(at: date) {
            pair = (0x4361B5, 0xE98A6A)
        } else {
            pair = switch report.weatherCode {
            case 0: day ? (0x4291F1, 0x77B8FE) : (0x162153, 0x453A89)
            case 1, 2: day ? (0x4C8EE6, 0x86B4EC) : (0x1E2550, 0x4A4580)
            case 3, 45, 48: day ? (0x6B7A93, 0x96A3B8) : (0x2A3140, 0x48505F)
            case 71...77, 85, 86: day ? (0x6F86A6, 0x9DB0C8) : (0x2B3550, 0x4D5A78)
            case 95...99: day ? (0x3E4560, 0x5E5878) : (0x1C1F33, 0x3A3456)
            default: day ? (0x5E6E89, 0x8494AC) : (0x222A3C, 0x3B4458)
            }
        }
        return [Color(rgb: pair.0), Color(rgb: pair.1)]
    }
}

extension View {
    /// Washes the tile in `sky`. A sky looks the same on every bar style, so its text always uses the dark inks.
    func onSky(_ sky: [Color]) -> some View {
        modifier(OnSky(sky: sky))
    }
}

private struct OnSky: ViewModifier {
    @Environment(\.tile) private var tile
    let sky: [Color]

    func body(content: Content) -> some View {
        var dark = tile
        dark.surface = SurfaceTokens(.glassDark)
        return content.tileContext(dark).tileTint(sky)
    }
}

/// Shared by every weather widget: fetches for the configured city and maps no-city, loading and error onto the
/// shared tile states. A failed refresh keeps the last report on screen, dimmed, with its age.
struct WeatherReportView<Content: View>: View {
    let settings: WeatherWidget.Settings
    @ViewBuilder let content: (WeatherService.Report, WeatherService.Place, Date) -> Content
    private let service = WeatherService.shared

    var body: some View {
        if let place = settings.place {
            let key = WeatherService.key(place, settings.unit)
            Group {
                if let report = service.reports[key] {
                    // Day/night and the sun's position move between fetches; a minute tick is plenty.
                    TimelineView(.everyMinute) { timeline in
                        content(report, place, timeline.date)
                    }
                    .tileStale(service.failed.contains(key) ? report.fetchedAt.formatted(date: .omitted, time: .shortened) : nil)
                } else if service.failed.contains(key) {
                    TileStateView(state: .offline(detail: String(localized: "Can't reach Open-Meteo")))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Weather unavailable")
                } else {
                    TileStateView(state: .loading)
                }
            }
            .task(id: key) { await service.keepFresh(place, unit: settings.unit) }
        } else {
            WeatherNoCityView()
        }
    }
}

struct WeatherNoCityView: View {
    var body: some View {
        TileStateView(state: .needsSetup(verb: String(localized: "Set city"), title: String(localized: "Choose a city"),
                                         detail: String(localized: "Widget Settings…")))
            .help("Right-click → Widget Settings… to choose a city")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Weather: no city set")
    }
}

struct WeatherSettings: View {
    @Binding var settings: WeatherWidget.Settings
    @State private var query = ""
    @State private var status: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("City", text: $query, prompt: Text(settings.place?.name ?? "e.g. Berlin"))
                    .onSubmit(lookUp)
                Button("Set", action: lookUp).disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Picker("Units", selection: $settings.unit) {
                Text("°C").tag(WeatherService.Unit.celsius)
                Text("°F").tag(WeatherService.Unit.fahrenheit)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            if let status { Text(status).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func lookUp() {
        let city = query.trimmingCharacters(in: .whitespaces)
        guard !city.isEmpty else { return }
        status = "Searching…"
        Task {
            do {
                if let place = try await WeatherService.shared.search(city) {
                    settings.place = place
                    query = ""
                    status = nil
                } else {
                    status = "No city found for “\(city)”."
                }
            } catch {
                status = "Couldn't reach Open-Meteo. Check your connection."
            }
        }
    }
}
