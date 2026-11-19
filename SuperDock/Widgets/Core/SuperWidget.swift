import SwiftUI
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "widgets")

enum WidgetCategory: String, CaseIterable {
    case ai, time, system, weather, media, controls

    var title: String {
        switch self {
        case .ai: String(localized: "AI & Agents")
        case .time: String(localized: "Time")
        case .system: String(localized: "System")
        case .weather: String(localized: "Weather")
        case .media: String(localized: "Media")
        case .controls: String(localized: "Controls")
        }
    }
}

struct NoSettings: Codable, Equatable {}

/// A widget type. Widgets are stateless descriptions: data lives in shared services,
/// per-instance settings live in the layout, so everything here is static.
protocol SuperWidget {
    associatedtype Settings: Codable & Equatable
    associatedtype Body: View

    static var id: String { get }              // "system.cpu"
    static var name: String { get }
    static var category: WidgetCategory { get }
    static var symbol: String { get }          // SF Symbol for the picker
    static var supportedSizes: [TileSize] { get }
    static var usesNetwork: Bool { get }
    static var defaultSettings: Settings { get }

    @MainActor @ViewBuilder static func view(size: TileSize, settings: Settings) -> Body
    @MainActor static func settingsView(_ settings: Binding<Settings>) -> AnyView?
}

extension SuperWidget {
    static var usesNetwork: Bool { false }
    @MainActor static func settingsView(_ settings: Binding<Settings>) -> AnyView? { nil }
}

extension SuperWidget where Settings == NoSettings {
    static var defaultSettings: NoSettings { NoSettings() }
}

// MARK: - Type erasure
// The host only knows a widget's id, so these turn the typed API into Data in, AnyView out.

extension SuperWidget {
    @MainActor static func tileView(size: TileSize, settings data: Data?) -> AnyView {
        AnyView(view(size: size, settings: decodeSettings(data)))
    }

    @MainActor static func settingsEditor(_ data: Binding<Data?>) -> AnyView? {
        settingsView(Binding(
            get: { decodeSettings(data.wrappedValue) },
            set: { data.wrappedValue = encodeSettings($0) }
        ))
    }

    private static func decodeSettings(_ data: Data?) -> Settings {
        guard let data else { return defaultSettings }
        do {
            return try JSONDecoder().decode(Settings.self, from: data)
        } catch {
            // Usually a widget update changed its Settings shape; defaults beat a broken tile.
            log.error("\(id) settings unreadable, using defaults: \(error)")
            return defaultSettings
        }
    }

    private static func encodeSettings(_ settings: Settings) -> Data? {
        do {
            return try JSONEncoder().encode(settings)
        } catch {
            log.fault("\(id) settings failed to encode: \(error)")
            return nil
        }
    }
}

extension View {
    /// Tile size follows the Dock's size, so text shrinks to fit instead of truncating.
    func tileText() -> some View {
        lineLimit(1).minimumScaleFactor(0.5)
    }
}
