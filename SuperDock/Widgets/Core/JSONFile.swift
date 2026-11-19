import Foundation
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "persistence")

/// Loads and saves one Codable value as a JSON file in Application Support.
enum JSONFile {
    /// nil if the file doesn't exist yet. An unreadable file is moved aside (never overwritten) and also gives nil.
    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: Data(contentsOf: url))
        } catch {
            let backup = url.deletingPathExtension().appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            log.error("Unreadable \(url.lastPathComponent), moved to \(backup.lastPathComponent): \(error)")
            do {
                try FileManager.default.moveItem(at: url, to: backup)
            } catch {
                log.error("Couldn't move unreadable file aside: \(error)")
            }
            return nil
        }
    }

    static func save(_ value: some Encodable, to url: URL) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            log.error("Couldn't save \(url.lastPathComponent): \(error)")
        }
    }
}
