import SwiftUI
import UserNotifications
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "productivity")

/// Countdown state kept in UserDefaults (not the view), so timers keep running while the bar hides with the Dock,
/// and a system notification scheduled at start fires even if the tile isn't on screen.
private enum Countdown {
    static func endKey(_ id: String) -> String { "\(id).end" }

    static func start(_ id: String, minutes: Double, title: String) {
        let end = Date().addingTimeInterval(minutes * 60)
        UserDefaults.standard.set(end.timeIntervalSince1970, forKey: endKey(id))
        // First timer start is when Notifications permission is asked for (SUPERDOCK.md §8).
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { log.error("Notification permission failed: \(error)") }
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: minutes * 60, repeats: false)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    static func stop(_ id: String) {
        UserDefaults.standard.removeObject(forKey: endKey(id))
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

/// Reads the persisted end time and ticks once a second only until it is reached; idle and done tiles don't tick.
private struct CountdownTile: View {
    let id: String
    let label: String
    let minutes: Double
    let doneTitle: String
    let tint: Color
    @AppStorage private var end: Double

    init(id: String, label: String, minutes: Double, doneTitle: String, tint: Color) {
        (self.id, self.label, self.minutes, self.doneTitle, self.tint) = (id, label, minutes, doneTitle, tint)
        _end = AppStorage(wrappedValue: 0, Countdown.endKey(id))
    }

    var body: some View {
        Button {
            // A finished countdown stays on its check until tapped, so a tap there only clears it.
            if end > 0 { Countdown.stop(id) } else { Countdown.start(id, minutes: minutes, title: doneTitle) }
        } label: {
            if end > Date().timeIntervalSince1970 {
                TimelineView(.explicit(Self.ticks(until: end))) { face(at: $0.date) }
            } else {
                face(at: .now)
            }
        }
        .buttonStyle(.plain)
    }

    private func face(at date: Date) -> CountdownFace {
        let remaining = end - date.timeIntervalSince1970
        let phase: CountdownPhase = end == 0 ? .idle : remaining > 0 ? .running(remaining: remaining) : .done
        return CountdownFace(label: label, total: minutes * 60, phase: phase, tint: tint)
    }

    /// Whole-second marks counting down to `end`, landing exactly on it so the done state appears on time.
    private static func ticks(until end: Double) -> [Date] {
        let start = end - (end - Date().timeIntervalSince1970).rounded(.up)
        return stride(from: start, through: end, by: 1).map { Date(timeIntervalSince1970: $0) }
    }
}

struct PomodoroWidget: SuperWidget {
    struct Settings: Codable, Equatable { var minutes = 25.0 }
    static let id = "productivity.pomodoro"
    static var name: String { String(localized: "Pomodoro") }
    static let category = WidgetCategory.productivity
    static let symbol = "timer"
    static let supportedSizes: [TileSize] = [.compact]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        CountdownTile(id: id, label: String(localized: "Focus"), minutes: settings.minutes,
                      doneTitle: String(localized: "Focus session done. Take a break."), tint: Palette.coral)
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(Stepper("Focus length: \(Int(settings.wrappedValue.minutes)) min", value: settings.minutes, in: 5...90, step: 5))
    }
}

struct TimerWidget: SuperWidget {
    struct Settings: Codable, Equatable { var minutes = 10.0 }
    static let id = "productivity.timer"
    static var name: String { String(localized: "Timer") }
    static let category = WidgetCategory.productivity
    static let symbol = "hourglass.bottomhalf.filled"
    static let supportedSizes: [TileSize] = [.compact]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        CountdownTile(id: id, label: String(localized: "Timer"), minutes: settings.minutes,
                      doneTitle: String(localized: "Timer finished"), tint: Palette.progress)
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(Stepper("Length: \(Int(settings.wrappedValue.minutes)) min", value: settings.minutes, in: 1...180))
    }
}

struct StopwatchWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "productivity.stopwatch"
    static var name: String { String(localized: "Stopwatch") }
    static let category = WidgetCategory.productivity
    static let symbol = "stopwatch"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        StopwatchTile()
    }
}

private struct StopwatchTile: View {
    @AppStorage("productivity.stopwatch.start") private var start = 0.0         // 0 = not running
    @AppStorage("productivity.stopwatch.banked") private var banked = 0.0       // seconds from earlier runs
    @AppStorage("productivity.stopwatch.lapMark") private var lapMark = 0.0     // elapsed when the current lap began
    @AppStorage("productivity.stopwatch.lastLap") private var lastLap = 0.0
    @AppStorage("productivity.stopwatch.laps") private var laps = 0

    var body: some View {
        if start > 0 {
            // Tenths tick only while running; a paused stopwatch is static.
            TimelineView(.periodic(from: .now, by: 0.1)) { face(at: $0.date) }
        } else {
            face(at: .now)
        }
    }

    private func elapsed(at date: Date) -> TimeInterval {
        banked + (start > 0 ? date.timeIntervalSince1970 - start : 0)
    }

    private func face(at date: Date) -> StopwatchFace {
        let lap = StopwatchFace.format(lastLap)
        return StopwatchFace(elapsed: elapsed(at: date), isRunning: start > 0,
                             lastLap: laps > 0 ? String(localized: "Lap \(laps) · \(lap.main)\(lap.fraction)") : nil,
                             onToggle: toggle, onLap: takeLap, onReset: reset)
    }

    private func toggle() {
        let now = Date().timeIntervalSince1970
        if start > 0 {
            banked += now - start
            start = 0
        } else {
            start = now
        }
    }

    private func takeLap() {
        let now = elapsed(at: .now)
        lastLap = now - lapMark
        lapMark = now
        laps += 1
    }

    private func reset() {
        (start, banked, lapMark, lastLap, laps) = (0, 0, 0, 0, 0)
    }
}

struct WaterWidget: SuperWidget {
    struct Settings: Codable, Equatable { var goal = 8 }
    static let id = "productivity.water"
    static var name: String { String(localized: "Water Tracker") }
    static let category = WidgetCategory.productivity
    static let symbol = "drop"
    static let supportedSizes: [TileSize] = [.compact]
    static var defaultSettings: Settings { Settings() }

    static func view(size: TileSize, settings: Settings) -> some View {
        WaterTile(goal: settings.goal)
    }

    static func settingsView(_ settings: Binding<Settings>) -> AnyView? {
        AnyView(Stepper("Daily goal: \(settings.wrappedValue.goal) glasses", value: settings.goal, in: 1...20))
    }
}

private struct WaterTile: View {
    let goal: Int
    @AppStorage("productivity.water.day") private var day = ""
    @AppStorage("productivity.water.count") private var count = 0

    var body: some View {
        let today = Date().formatted(.iso8601.year().month().day())
        let glasses = day == today ? count : 0   // a new day starts at zero
        Button {
            count = glasses + 1
            day = today
        } label: {
            WaterFace(glasses: glasses, goal: goal)
        }
        .buttonStyle(.plain)
    }
}

struct NoteWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "productivity.note"
    static var name: String { String(localized: "Quick Note") }
    static let category = WidgetCategory.productivity
    static let symbol = "note.text"
    static let supportedSizes: [TileSize] = [.medium, .wide, .large]

    static func view(size: TileSize, settings: Settings) -> some View {
        QuickNoteTile()
    }
}

private struct QuickNoteTile: View {
    @Environment(\.tile) private var tile
    @AppStorage("productivity.note.text") private var text = ""
    @AppStorage("productivity.note.edited") private var edited = 0.0

    var body: some View {
        Group {
            // Only L shows the edit age, so only L wakes once a minute to refresh it.
            if tile.size == .large, edited > 0 {
                TimelineView(.everyMinute) { note(age: ShortAge.text(since: Date(timeIntervalSince1970: edited), now: $0.date)) }
            } else {
                note(age: nil)
            }
        }
        .accessibilityLabel("Quick note")
    }

    private func note(age: String?) -> NoteTile {
        NoteTile(text: Binding(get: { text }, set: { text = $0; edited = Date().timeIntervalSince1970 }), edited: age)
    }
}

private struct LegacyNoteTile: View {
    @AppStorage("productivity.note.text") private var text = ""

    var body: some View {
        TextEditor(text: $text)
            .font(.caption)
            .scrollContentBackground(.hidden)
            .overlay(alignment: .topLeading) {
                if text.isEmpty { Text("Note…").font(.caption).foregroundStyle(.tertiary).padding(.leading, 5).allowsHitTesting(false) }
            }
            .accessibilityLabel("Quick note")
    }
}

struct TodoWidget: SuperWidget {
    typealias Settings = NoSettings
    static let id = "productivity.todo"
    static var name: String { String(localized: "To-Do") }
    static let category = WidgetCategory.productivity
    static let symbol = "checklist"
    static let supportedSizes: [TileSize] = [.medium, .wide, .large]

    static func view(size: TileSize, settings: Settings) -> some View {
        TodoWidgetTile()
    }
}

/// Same storage shape as before the redesign (`[{id, title}]` under `productivity.todo.items`), so saved lists load.
private struct StoredTodo: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
}

private struct TodoWidgetTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("productivity.todo.items") private var stored = Data()
    /// Ticked items stay a moment, showing the tick, before they leave the list. Tapping again in that moment undoes.
    @State private var checked: Set<UUID> = []

    private var items: [StoredTodo] {
        guard !stored.isEmpty else { return [] }   // first use
        do {
            return try JSONDecoder().decode([StoredTodo].self, from: stored)
        } catch {
            log.error("To-do list unreadable: \(error)")
            return []
        }
    }

    var body: some View {
        TodoListTile(items: items.map { TodoItem(id: $0.id, title: $0.title, isDone: checked.contains($0.id)) },
                     onToggle: toggle, onAdd: { save(items + [StoredTodo(title: $0)]) })
    }

    private func toggle(_ id: UUID) {
        guard checked.insert(id).inserted else {
            checked.remove(id)
            return
        }
        Task {
            do {
                try await Task.sleep(for: .seconds(1.1))
            } catch {
                return   // the tile went away mid-tick; the item stays on the list
            }
            guard checked.contains(id) else { return }
            withAnimation(reduceMotion ? Motion.reduced : Motion.settle) {
                save(items.filter { $0.id != id })
                checked.remove(id)
            }
        }
    }

    private func save(_ items: [StoredTodo]) {
        do {
            stored = try JSONEncoder().encode(items)
        } catch {
            log.error("Couldn't save to-dos: \(error)")
        }
    }
}

private struct LegacyTodoTile: View {
    struct Item: Codable, Identifiable, Equatable {
        var id = UUID()
        var title: String
    }

    let size: TileSize
    @AppStorage("productivity.todo.items") private var stored = Data()
    @State private var draft = ""

    private var items: [Item] {
        guard !stored.isEmpty else { return [] }   // first use
        do {
            return try JSONDecoder().decode([Item].self, from: stored)
        } catch {
            log.error("To-do list unreadable: \(error)")
            return []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items.prefix(size == .medium ? 2 : 3)) { item in
                Button { save(items.filter { $0.id != item.id }) } label: {
                    Label(item.title, systemImage: "circle").font(.caption2).lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("Tap to complete")
            }
            TextField("Add a task", text: $draft)
                .textFieldStyle(.plain).font(.caption2)
                .onSubmit {
                    let title = draft.trimmingCharacters(in: .whitespaces)
                    guard !title.isEmpty else { return }
                    save(items + [Item(title: title)])
                    draft = ""
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save(_ items: [Item]) {
        do {
            stored = try JSONEncoder().encode(items)
        } catch {
            log.error("Couldn't save to-dos: \(error)")
        }
    }
}
