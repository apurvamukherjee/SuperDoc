import Foundation

/// Pure helpers behind the developer widgets, kept free of SwiftUI so the tests can compile them.
enum DevParsing {
    struct ListeningPort: Equatable, Hashable {
        var port: Int
        var process: String
    }

    /// Parses `lsof -nP -iTCP -sTCP:LISTEN` output: one entry per port, lowest first.
    static func listeningPorts(fromLsof output: String) -> [ListeningPort] {
        let ports = output.split(separator: "\n").dropFirst().compactMap { line -> ListeningPort? in
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            // NAME is "*:3000" or "127.0.0.1:5173" or "[::1]:8080", followed by "(LISTEN)".
            guard let name = columns.dropLast().last, let colon = name.lastIndex(of: ":"),
                  let port = Int(name[name.index(after: colon)...]), let process = columns.first else { return nil }
            return ListeningPort(port: port, process: String(process).replacingOccurrences(of: "\\x20", with: " "))
        }
        return Array(Set(ports)).sorted { $0.port < $1.port }
    }

    struct GitStatus: Equatable {
        var branch: String
        var changed: Int
        var ahead: Int
        var behind: Int
    }

    /// Parses `git status --porcelain=v1 -b`.
    static func gitStatus(fromPorcelain output: String) -> GitStatus? {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        guard let header = lines.first, header.hasPrefix("## ") else { return nil }
        var text = header.dropFirst(3)
        if text.hasPrefix("No commits yet on ") { text = text.dropFirst("No commits yet on ".count) }
        let branch = text.split(separator: "...").first.map { String($0.split(separator: " ").first ?? $0) } ?? String(text)
        func count(_ word: String) -> Int {
            guard let range = header.range(of: "\(word) ") else { return 0 }
            return Int(header[range.upperBound...].prefix { $0.isNumber }) ?? 0
        }
        return GitStatus(branch: branch, changed: lines.count - 1, ahead: count("ahead"), behind: count("behind"))
    }

    static let passwordAlphabet = Array("abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%^&*-_=+")

    /// Random password from the system CSPRNG (`SystemRandomNumberGenerator` reads the kernel's secure source).
    static func password(length: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        return String((0..<max(length, 4)).map { _ in passwordAlphabet.randomElement(using: &generator) ?? "x" })
    }
}

/// Runs a command off the main thread and returns stdout, or nil if it can't run or fails.
func runCommand(_ path: String, _ arguments: [String]) async -> String? {
    await Task.detached {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil   // tool missing (e.g. git without Command Line Tools); the widget shows that state
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? String(bytes: data, encoding: .utf8) : nil
    }.value
}
