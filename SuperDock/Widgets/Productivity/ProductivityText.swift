import Foundation

// Pure text helpers behind the productivity tiles, kept free of SwiftUI so the tests can compile them.

enum ShortAge {
    /// "just now", "4m ago", "3h ago", "2d ago": short enough for a tile corner.
    static func text(since date: Date, now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date)) / 60
        return switch minutes {
        case ..<1: String(localized: "just now")
        case ..<60: String(localized: "\(minutes)m ago")
        case ..<1440: String(localized: "\(minutes / 60)h ago")
        default: String(localized: "\(minutes / 1440)d ago")
        }
    }
}

enum StopwatchText {
    /// "1:24" + ".6"; past an hour the tenths drop off: "1:02:03".
    static func format(_ seconds: TimeInterval) -> (main: String, fraction: String) {
        let tenths = Int((max(seconds, 0) * 10).rounded(.down))
        let whole = tenths / 10
        if whole >= 3600 {
            return (String(format: "%d:%02d:%02d", whole / 3600, whole / 60 % 60, whole % 60), "")
        }
        return (String(format: "%d:%02d", whole / 60, whole % 60), ".\(tenths % 10)")
    }
}
