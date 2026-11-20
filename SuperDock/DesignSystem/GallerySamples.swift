#if DEBUG
import SwiftUI

/// The kit's ten archetypes filled with the mockup's own sample data, so renders compare 1:1 with
/// design/mockups/05-kit-archetypes-states.png.
enum Archetype: Int, CaseIterable, Identifiable {
    case stat = 1, ring, bars, chart, list, media, control, glyph, calendar, input

    var id: Int { rawValue }

    var title: String {
        ["Stat", "Ring", "Bars", "Chart", "List", "Media", "Control", "Glyph", "Calendar / time", "Input"][rawValue - 1]
    }

    var subtitle: String {
        [
            "Memory, Disk, Uptime, plugin value", "AI Limits C, Pomodoro, Timer, Disk, plugin gauge",
            "AI Limits M–L, Day/Week/Year progress", "CPU, Network: area, sparkline, two-tone",
            "Agents, Ports, To-Do, plugin list · “+N more”", "Now Playing: art tints the tile",
            "Quick Actions, Volume, Brightness, Wi-Fi", "Moon, Thermal, Launchpad, Stack, Dice",
            "Clock, Date, World Clock, Month", "Quick Note, To-Do add field"
        ][rawValue - 1]
    }

    /// nil = this archetype doesn't come in that size (Glyph stops at M; the W slot carries the note).
    @MainActor func sample(_ size: TileSize) -> AnyView? {
        switch self {
        case .stat: AnyView(Samples.stat(size))
        case .ring: AnyView(Samples.ring(size))
        case .bars: AnyView(Samples.bars(size))
        case .chart: AnyView(Samples.chart(size))
        case .list: AnyView(Samples.list(size))
        case .media: AnyView(Samples.media)
        case .control: AnyView(Samples.control(size))
        case .glyph: Samples.glyph(size)
        case .calendar: AnyView(Samples.calendar(size))
        case .input: AnyView(Samples.input(size))
        }
    }
}

@MainActor
enum Samples {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    static let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 22, minute: 55)) ?? .now
    static let cpu: [Double] = [8, 14, 10, 22, 18, 26, 21, 30, 24, 19, 27, 22, 25, 23]
    static let art = [Color(rgb: 0xFF7A59), Color(rgb: 0xC04FE0), Color(rgb: 0x8A3CFF)]

    @ViewBuilder static func stat(_ size: TileSize) -> some View {
        switch size {
        case .compact:
            StatTile(stats: [Stat(label: "Mem", value: "11.2", detail: "of 16 GB")])
        case .medium, .wide:
            StatTile(stats: [Stat(label: "Memory", value: "11.2", unit: "GB", meter: 0.7, meterColor: Palette.good,
                                  badge: size == .medium ? "Normal" : nil)],
                     breakdown: [Breakdown(label: "App", value: "7.9"), Breakdown(label: "Wired", value: "2.1"),
                                 Breakdown(label: "Swap", value: "0.4")])
        case .large:
            StatTile(stats: [
                Stat(label: "CPU", value: "23%", meter: 0.23, meterColor: Palette.progress),
                Stat(label: "Mem", value: "70%", meter: 0.7, meterColor: Palette.good),
                Stat(label: "Disk", value: "212", unit: "G", meter: 0.55, meterColor: .primary.opacity(0.85)),
                Stat(label: "Up", value: "3d 4h", detail: "since Sun")
            ])
        }
    }

    static func ring(_ size: TileSize) -> some View {
        RingTile(rings: [.init(fraction: 0.72, color: Palette.coral)],
                 label: size == .large ? "Focus · Round 2 of 4" : "Focus", value: "18:24",
                 detail: size == .large ? "Break at 11:14 PM" : "Round 2 of 4", segments: (2, 4),
                 actions: [.init(symbol: "pause.fill", label: "Pause"), .init(symbol: "stop.fill", label: "Stop")])
    }

    static func bars(_ size: TileSize) -> some View {
        let rows = size == .compact
            ? [BarRow(label: "Year", value: "88", unit: "%", fraction: 0.88, detail: "42 d left")]
            : [BarRow(label: "Day", value: "96%", fraction: 0.96), BarRow(label: "Week", value: "56%", fraction: 0.56),
               BarRow(label: "Month", value: "61%", fraction: 0.61), BarRow(label: "Year", value: "88%", fraction: 0.88)]
        return BarsTile(rows: rows, aside: Stat(label: "Next", value: "1h 05m", detail: "until Fri"))
    }

    static func chart(_ size: TileSize) -> some View {
        let network = [AreaChart.Series(values: [6, 9, 7, 14, 11, 18, 15, 20, 16, 12, 17], color: Palette.good),
                       .init(values: [3, 4, 3, 5, 4, 6, 5, 4, 5, 4, 4], color: Palette.amber, filled: false)]
        return ChartTile(label: size == .wide ? "Network" : size == .large ? "CPU · 60 s" : "CPU", value: "23%",
                         series: size == .wide ? network : [.init(values: cpu, color: Palette.progress)],
                         legend: [Legend(text: "↓ 4.2 MB/s", color: Palette.good), Legend(text: "↑ 380 KB/s", color: Palette.amber)],
                         detail: "P 31% · E 12%")
    }

    static func list(_ size: TileSize) -> some View {
        let regular = [(":3000", "node"), (":5432", "postgres"), (":8080", "python3"), (":5173", "vite"), (":6379", "redis"),
                       (":4000", "ruby"), (":9229", "node")]
        let large = [(":3000", "node"), (":6379", "redis"), (":4000", "ruby"), (":5173", "vite"), (":8080", "py"),
                     (":1313", "hugo"), (":5432", "pg"), (":9229", "node"), (":8081", "go"), (":5000", "flask")]
        let ports = size == .large ? large : Array(regular.prefix(size == .medium ? 3 : 7))
        return ListTile(rows: ports.map { ListRow(title: $0.0, titleColor: Palette.good, trailing: $0.1) },
                        counts: agentCounts, mono: true)
    }

    static let agentCounts = [ListCount(id: 0, glyph: .activity(Palette.working), count: 3),
                              ListCount(id: 1, glyph: .symbol("hand.raised.fill", Palette.coral), count: 1),
                              ListCount(id: 2, glyph: .symbol("checkmark", Palette.good), count: 2),
                              ListCount(id: 3, glyph: .symbol("moon.fill", Palette.idle), count: 1)]

    static let agents = [ListRow(glyph: .symbol("hand.raised.fill", Palette.coral), title: "superdock", alert: true),
                         ListRow(glyph: .symbol("checkmark", Palette.good), title: "api"),
                         ListRow(glyph: .activity(Palette.working), title: "web-api"),
                         ListRow(glyph: .activity(Palette.working), title: "infra"),
                         ListRow(title: "docs"), ListRow(title: "site")]

    static var media: some View {
        MediaTile(title: "Night Drive", artist: "Sora Vale", album: "Low Tide", art: art, progress: 0.38,
                  time: "1:24 / 3:41", waveform: [0.5, 0.8, 0.6, 1, 0.7, 0.9, 0.55, 0.85, 0.4, 0.7, 0.5, 0.6, 0.35])
    }

    @ViewBuilder static func control(_ size: TileSize) -> some View {
        switch size {
        case .compact: ToggleTile(symbol: "wifi", label: "Wi-Fi", isOn: true)
        case .medium: SliderTile(value: .constant(0.55), symbol: "speaker.wave.2.fill", label: "Volume")
        case .wide:
            ButtonsTile(buttons: [ControlButton(symbol: "lock", label: "Lock"), ControlButton(symbol: "camera", label: "Capture"),
                                  ControlButton(symbol: "circle.lefthalf.filled", label: "Dark", isOn: true)])
        case .large: SliderTile(value: .constant(0.64), symbol: "speaker.wave.2.fill", label: "Volume")
        }
    }

    static func glyph(_ size: TileSize) -> AnyView? {
        switch size {
        case .compact, .medium:
            AnyView(GlyphTile(caption: "Waning", title: "Waning gibbous", details: ["72% lit", "New in 9 d"]) { MoonGlyph() })
        case .wide:
            AnyView(Text("Glyph stops at M · W/L use Stat").tileStyle(.body, color: .secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity).tileOutline(.dashed))
        case .large:
            nil
        }
    }

    @ViewBuilder static func calendar(_ size: TileSize) -> some View {
        if size == .medium {
            ClockTile(time: "10:55", period: "PM", detail: "Thursday, 19 November")
        } else {
            CalendarTile(date: now, calendar: calendar)
        }
    }

    @ViewBuilder static func input(_ size: TileSize) -> some View {
        switch size {
        case .compact:
            Text("Input\nstarts at M").lineLimit(2).tileStyle(.detail).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity).tileOutline(.dashed)
        case .wide:
            TodoTile(items: [TodoItem(title: "Reply to design review", isDone: true), TodoItem(title: "Rotate API keys")])
        case .medium, .large:
            NoteTile(text: .constant(size == .medium ? "Ship the onboarding copy before Fri"
                                     : "Ship the onboarding copy before Fri. Ask about the notch shelf hover delay."),
                     edited: "Edited 4m ago")
        }
    }

    /// The vertical bar's M tiles: AI limits, agents, media, CPU.
    static var portraits: [AnyView] {
        [
            AnyView(BarsTile(rows: [BarRow(label: "5H", value: "62%", fraction: 0.62, color: Palette.claude, detail: "2h 14m"),
                                    BarRow(label: "WK", value: "41%", fraction: 0.41, color: Palette.claudeSoft, detail: "Mon")])),
            AnyView(ListTile(rows: agents)),
            AnyView(media),
            AnyView(ChartTile(label: "CPU", value: "23%", series: [.init(values: cpu, color: Palette.progress)]))
        ]
    }

    struct StateSample: Identifiable {
        var id: String { title }
        let state: TileState
        let title: String
        let note: String
    }

    static let states = [
        StateSample(state: .loading, title: "Loading", note: "Skeleton in the archetype's own slots. No spinner."),
        StateSample(state: .empty(title: "All quiet", detail: "No agents running"), title: "Empty",
                    note: "Sleeping Limo. Calm, never an error."),
        StateSample(state: .offline(detail: "Showing 9:40 PM data"), title: "Error / offline",
                    note: "Keep the last value, dimmed, with its age."),
        StateSample(state: .needsPermission(detail: "Open Settings →"), title: "Needs permission",
                    note: "Amber key, one tap to the right System Settings pane."),
        StateSample(state: .needsSetup(verb: "Connect", title: "Connect Claude", detail: "Takes 5 seconds"),
                    title: "Needs setup", note: "Outlined tile, verb first: “Connect”, “Choose repo”.")
    ]
}

/// Stand-in for the Time owner's rendered moon: a lit disc with a shadowed limb.
private struct MoonGlyph: View {
    var body: some View {
        Circle().fill(Color(rgb: 0xE9E4D6))
            .overlay(Circle().fill(Color(rgb: 0x3A4256)).offset(x: -9).blur(radius: 1.5))
            .clipShape(Circle())
    }
}
#endif
