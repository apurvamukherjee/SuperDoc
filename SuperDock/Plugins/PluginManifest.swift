import Foundation

/// A declarative widget: where to get JSON, and how to show parts of it. No plugin code runs in SuperDock,
/// so a plugin can't crash the app, read files or reach anything but the URL it declares. Format: docs/plugins.md.
struct PluginManifest: Codable, Equatable {
    struct Source: Codable, Equatable {
        /// https only. `{key}` placeholders are filled from the widget's settings (URL-encoded).
        var url: String
        /// Seconds between refreshes; clamped to at least 60 so plugins can't hammer an API.
        var every: Int?
        var headers: [String: String]?
    }

    struct Field: Codable, Equatable {
        var key: String
        var label: String
        var `default`: String?
    }

    struct Tile: Codable, Equatable {
        enum Template: String, Codable {
            case value      // label over one big value (+ optional subtitle)
            case text       // a paragraph of text (quotes, facts)
            case list       // titles, each optionally a link
            case gauge      // value out of `max`, as a ring
        }

        enum Format: String, Codable {
            case text, number, percent, bytes, currency
        }

        var template: Template
        var label: String?
        /// JSONPath to the main value, e.g. `$.bitcoin.usd`.
        var value: String?
        var subtitle: String?
        /// JSONPath with `[*]`, e.g. `$.hits[*].title`.
        var items: String?
        var links: String?
        var max: Double?
        var format: Format?
        /// ISO currency code for `format: currency`.
        var currency: String?
        var prefix: String?
        var suffix: String?
        /// Opened when the tile is clicked.
        var open: String?
    }

    var id: String
    var name: String
    var description: String?
    var author: String?
    var symbol: String?
    var category: String?
    var sizes: [TileSize]?
    var source: Source
    var settings: [Field]?
    var tile: Tile

    static let minimumInterval = 60

    var interval: Int { max(source.every ?? 600, Self.minimumInterval) }

    enum Problem: Error, Equatable {
        case missingID, insecureURL, missingValuePath
    }

    /// Checks a manifest is usable before it's installed or shown.
    func validate() throws {
        guard !id.trimmingCharacters(in: .whitespaces).isEmpty, !name.isEmpty else { throw Problem.missingID }
        guard source.url.lowercased().hasPrefix("https://") else { throw Problem.insecureURL }
        switch tile.template {
        case .value, .text, .gauge: if tile.value == nil { throw Problem.missingValuePath }
        case .list: if tile.items == nil { throw Problem.missingValuePath }
        }
    }

    /// Each setting's value, falling back to its default.
    func values(from settings: [String: String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (self.settings ?? []).map { field in
            let value = settings[field.key].flatMap { $0.isEmpty ? nil : $0 } ?? field.default ?? ""
            return (field.key, value)
        })
    }
}

enum PluginTemplate {
    /// Replaces `{key}` with settings values; `encode` percent-encodes them for use inside a URL.
    static func fill(_ template: String, with values: [String: String], encode: Bool = false) -> String {
        values.reduce(template) { result, entry in
            let value = encode ? (entry.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? entry.value) : entry.value
            return result.replacingOccurrences(of: "{\(entry.key)}", with: value)
        }
    }

    /// Display string for a resolved JSON value.
    static func format(_ value: Any?, as format: PluginManifest.Tile.Format?, currency: String? = nil) -> String {
        guard let value else { return "–" }
        let number = (value as? NSNumber)?.doubleValue ?? (value as? String).flatMap(Double.init)
        switch format ?? .text {
        case .text:
            if let number, !(value is String) { return number.formatted() }
            return "\(value)"
        case .number: return number.map { $0.formatted() } ?? "\(value)"
        case .percent: return number.map { ($0 / 100).formatted(.percent.precision(.fractionLength(0...1))) } ?? "\(value)"
        case .bytes: return number.map { Int64($0).formatted(.byteCount(style: .file)) } ?? "\(value)"
        case .currency: return number.map { $0.formatted(.currency(code: currency ?? "USD")) } ?? "\(value)"
        }
    }
}

/// A small JSONPath subset: `$`, `.key`, `["key"]`, `[0]` and `[*]`. Enough for picking values out of API responses.
enum JSONPath {
    private enum Step: Equatable {
        case key(String), index(Int), all
    }

    /// Every value the path selects (`[*]` can select many). Unknown keys or bad indexes select nothing.
    static func values(_ path: String, in json: Any) -> [Any] {
        guard let steps = parse(path) else { return [] }
        return steps.reduce([json]) { current, step in
            current.flatMap { node -> [Any] in
                switch step {
                case .key(let key): return [(node as? [String: Any])?[key]].compactMap { $0 }.filter { !($0 is NSNull) }
                case .index(let index):
                    guard let array = node as? [Any], array.indices.contains(index) else { return [] }
                    return [array[index]]
                case .all: return node as? [Any] ?? []
                }
            }
        }
    }

    static func value(_ path: String, in json: Any) -> Any? {
        values(path, in: json).first
    }

    private static func parse(_ path: String) -> [Step]? {
        var rest = Substring(path.trimmingCharacters(in: .whitespaces))
        guard rest.hasPrefix("$") else { return nil }
        rest.removeFirst()
        var steps: [Step] = []
        while !rest.isEmpty {
            if rest.hasPrefix(".") {
                rest.removeFirst()
                let key = rest.prefix { $0 != "." && $0 != "[" }
                guard !key.isEmpty else { return nil }
                steps.append(.key(String(key)))
                rest.removeFirst(key.count)
            } else if rest.hasPrefix("[") {
                guard let close = rest.firstIndex(of: "]") else { return nil }
                let inner = rest[rest.index(after: rest.startIndex)..<close].trimmingCharacters(in: .whitespaces)
                if inner == "*" {
                    steps.append(.all)
                } else if let index = Int(inner) {
                    steps.append(.index(index))
                } else if inner.count >= 2, let quote = inner.first, ["\"", "'"].contains(quote), inner.last == quote {
                    steps.append(.key(String(inner.dropFirst().dropLast())))
                } else {
                    return nil
                }
                rest = rest[rest.index(after: close)...]
            } else {
                return nil
            }
        }
        return steps
    }
}
