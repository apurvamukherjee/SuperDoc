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

    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded(.up)), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Ring + time, shared by Pomodoro and Timer.
private struct CountdownTile: View {
    let id: String
    let label: LocalizedStringKey
    let minutes: Double
    let doneTitle: String
    @AppStorage private var end: Double

    init(id: String, label: LocalizedStringKey, minutes: Double, doneTitle: String) {
        self.id = id
        self.label = label
        self.minutes = minutes
        self.doneTitle = doneTitle
        _end = AppStorage(wrappedValue: 0, Countdown.endKey(id))
    }

    var body: some View {
        Button {
            if end > Date().timeIntervalSince1970 { Countdown.stop(id) } else { Countdown.start(id, minutes: minutes, title: doneTitle) }
        } label: {
            // Ticks once a second only while running; idle tiles don't animate at all.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = end - context.date.timeIntervalSince1970
                let running = remaining > 0
                ZStack {
                    Circle().stroke(.quaternary, lineWidth: 4)
                    Circle().trim(from: 0, to: running ? remaining / (minutes * 60) : 0)
                        .stroke(.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(running ? Countdown.clock(remaining) : Countdown.clock(minutes * 60))
                            .font(.callout.weight(.semibold)).monospacedDigit()
                        Text(running ? "Tap to stop" : label).font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                    .tileText()
                }
                .padding(4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
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
        CountdownTile(id: id, label: "Focus", minutes: settings.minutes, doneTitle: String(localized: "Focus session done. Take a break."))
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
        CountdownTile(id: id, label: "Timer", minutes: settings.minutes, doneTitle: String(localized: "Timer finished"))
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
        StopwatchTile(size: size)
    }
}

private struct StopwatchTile: View {
    let size: TileSize
    @AppStorage("productivity.stopwatch.start") private var start = 0.0         // 0 = not running
    @AppStorage("productivity.stopwatch.banked") private var banked = 0.0       // seconds from earlier runs

    var body: some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let elapsed = banked + (start > 0 ? context.date.timeIntervalSince1970 - start : 0)
                Text(Duration.seconds(elapsed).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 1))))
                    .font(.callout.weight(.semibold)).monospacedDigit().tileText()
            }
            .onTapGesture(perform: toggle)
            if size == .medium {
                Button("Reset") {
                    start = 0
                    banked = 0
                }
                .controlSize(.small)
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to start or pause")
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
            VStack(spacing: 2) {
                Image(systemName: glasses >= goal ? "drop.fill" : "drop").font(.title3).foregroundStyle(.cyan)
                Text("\(glasses)/\(goal)").font(.caption.weight(.semibold)).monospacedDigit()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Water: \(glasses) of \(goal) glasses. Tap to add one.")
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
        LegacyNoteTile()
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
        LegacyTodoTile(size: size)
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
