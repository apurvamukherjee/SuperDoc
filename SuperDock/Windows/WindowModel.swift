import CoreGraphics
import Foundation

/// A user-facing window, from CGWindowList (all Spaces) enriched with AX (current Space).
struct WindowInfo: Identifiable, Equatable {
    var id: CGWindowID
    var pid: pid_t
    var appName: String
    var title: String
    var bounds: CGRect   // CG coordinates (top-left origin)
    var isOnScreen: Bool
}

/// Pure rules behind the window list, the switcher and frozen-app detection.
enum WindowRules {
    private static let minimumSize = CGSize(width: 100, height: 50)

    /// Turns `CGWindowListCopyWindowInfo` rows into real windows.
    ///
    /// CGWindowList also returns invisible helper windows, so a window must either be one AX reports for its app
    /// (`axTitles`, current Space and minimized windows) or have a title. Titles of windows on other Spaces
    /// are only visible with Screen Recording access, so without it those windows are left out.
    static func windows(
        from rows: [[String: Any]], appNames: [pid_t: String], axTitles: [CGWindowID: String], ownPID: pid_t
    ) -> [WindowInfo] {
        rows.compactMap { row in
            guard (row[kCGWindowLayer as String] as? Int) == 0,
                  let id = row[kCGWindowNumber as String] as? CGWindowID,
                  let pid = row[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  let appName = appNames[pid],
                  (row[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let boundsDict = row[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width >= minimumSize.width, bounds.height >= minimumSize.height else { return nil }
            let cgTitle = row[kCGWindowName as String] as? String ?? ""
            guard axTitles[id] != nil || !cgTitle.isEmpty else { return nil }
            let title = cgTitle.isEmpty ? (axTitles[id] ?? "") : cgTitle
            return WindowInfo(id: id, pid: pid, appName: appName, title: title.isEmpty ? appName : title,
                              bounds: bounds, isOnScreen: row[kCGWindowIsOnscreen as String] as? Bool ?? false)
        }
    }

    /// Switcher order: on-screen windows in their front-to-back order (CGWindowList's own order),
    /// then the rest grouped by how recently their app was used.
    static func ordered(_ windows: [WindowInfo], appMRU: [pid_t]) -> [WindowInfo] {
        let rank = Dictionary(appMRU.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let onScreen = windows.filter(\.isOnScreen)
        let others = windows.enumerated()
            .filter { !$0.element.isOnScreen }
            .sorted { (rank[$0.element.pid] ?? .max, $0.offset) < (rank[$1.element.pid] ?? .max, $1.offset) }
            .map(\.element)
        return onScreen + others
    }

    /// Index after moving `delta` steps through `count` items, wrapping both ways.
    static func step(_ index: Int, by delta: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return ((index + delta) % count + count) % count
    }
}

/// Counts consecutive AX timeouts per app. An app is frozen after `threshold` misses in a row.
struct FreezeCounter {
    static let threshold = 2

    private(set) var misses: [pid_t: Int] = [:]
    var frozen: Set<pid_t> { Set(misses.filter { $0.value >= Self.threshold }.keys) }

    /// `responded[pid]` is false when the app timed out. Returns apps that just became frozen.
    mutating func record(_ responded: [pid_t: Bool]) -> [pid_t] {
        var newlyFrozen: [pid_t] = []
        var next: [pid_t: Int] = [:]
        for (pid, didRespond) in responded where !didRespond {
            next[pid] = (misses[pid] ?? 0) + 1
            if next[pid] == Self.threshold { newlyFrozen.append(pid) }
        }
        misses = next   // responsive or quit apps drop out
        return newlyFrozen.sorted()
    }
}
