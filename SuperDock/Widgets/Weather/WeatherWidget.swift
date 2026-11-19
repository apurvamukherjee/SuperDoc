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
        WeatherTile(size: size, settings: settings)
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(WeatherSettings(settings: settings))
    }
}

private struct WeatherTile: View {
    let size: TileSize
    let settings: WeatherWidget.Settings

    var body: some View {
        WeatherReportView(settings: settings) { report, place in
            HStack(spacing: 8) {
                Image(systemName: WeatherService.symbol(for: report.weatherCode))
                    .symbolRenderingMode(.multicolor)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(degrees(report.temperature)).font(.title3.weight(.semibold))
                    if size != .compact {
                        Text(place.name.components(separatedBy: ",").first ?? place.name)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if size == .wide {
                        Text("H \(degrees(report.high))  L \(degrees(report.low))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .tileText()
        }
    }
}

func degrees(_ value: Double) -> String {
    "\(Int(value.rounded()))°"
}

/// Shared by every weather widget: fetches for the configured city and handles the no-city, loading and error states.
struct WeatherReportView<Content: View>: View {
    let settings: WeatherWidget.Settings
    @ViewBuilder let content: (WeatherService.Report, WeatherService.Place) -> Content
    private let service = WeatherService.shared

    var body: some View {
        if let place = settings.place {
            let key = WeatherService.key(place, settings.unit)
            Group {
                if let report = service.reports[key] {
                    content(report, place)
                } else if service.failed.contains(key) {
                    Image(systemName: "exclamationmark.icloud").font(.title3).accessibilityLabel("Weather unavailable")
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .task(id: key) { await service.keepFresh(place, unit: settings.unit) }
        } else {
            Label("Set a city", systemImage: "location.slash")
                .labelStyle(.iconOnly)
                .font(.title3)
                .foregroundStyle(.secondary)
                .help("Right-click → Widget Settings… to choose a city")
                .accessibilityLabel("Weather: no city set")
        }
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
