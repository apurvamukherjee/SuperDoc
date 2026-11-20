import SwiftUI

// Pure productivity tile views: plain values in, no storage, so the gallery can draw every state.

enum CountdownPhase: Equatable {
    case idle
    case running(remaining: TimeInterval)
    case done
}

/// 2 · Ring, compact: Pomodoro and Timer. A warm countdown ring that turns into a green check with confetti at zero.
struct CountdownFace: View {
    @Environment(\.tile) private var tile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var label: String
    var total: TimeInterval
    var phase: CountdownPhase
    var tint: Color

    var body: some View {
        ZStack {
            switch phase {
            case .idle:
                ring(1, color: tint.opacity(0.45))
                VStack(spacing: 0) {
                    Text(Self.clock(total)).tileStyle(.value)
                    Text(label).tileStyle(.caption)
                }
            case let .running(remaining):
                ring(remaining / max(total, 1), color: tint)
                Text(Self.clock(remaining)).tileStyle(.value)
            case .done:
                ring(1, color: Palette.done)
                Image(systemName: "checkmark")
                    .font(.system(size: 19 * tile.scale, weight: .bold))
                    .foregroundStyle(Palette.done)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.3).combined(with: .opacity))
                ForEach(Self.confetti.indices, id: \.self) { confettiPiece(Self.confetti[$0]) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tileTint(phase == .done ? Palette.done : nil, opacity: 0.16)
        .tileAnimation(Motion.pop, value: phase == .done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        switch phase {
        case .idle: "\(Self.clock(total)), tap to start"
        case let .running(remaining): "\(Self.clock(remaining)) left, tap to stop"
        case .done: "Done, tap to clear"
        }
    }

    /// The kit ring with a track tinted by the ring's own hue, as the mockup draws it.
    private func ring(_ fraction: Double, color: Color) -> some View {
        RingGauge(rings: [.init(fraction: fraction, color: color)])
            .background(Circle().stroke(color.opacity(0.24), lineWidth: 5 * tile.scale).padding(2.5 * tile.scale))
    }

    private struct Confetti {
        let position: CGPoint, angle: Double, color: Color, isDash: Bool
    }

    /// Positions as fractions of the ring's radius, copied from the mockup's done tile.
    private static let confetti = [
        Confetti(position: CGPoint(x: -0.86, y: -0.86), angle: 0, color: Palette.note, isDash: false),
        Confetti(position: CGPoint(x: 0.86, y: -0.74), angle: 0, color: Palette.coral, isDash: false),
        Confetti(position: CGPoint(x: -0.84, y: 0.66), angle: -35, color: Palette.codex, isDash: true),
        Confetti(position: CGPoint(x: 0.84, y: 0.62), angle: 35, color: Palette.working, isDash: true)
    ]

    private func confettiPiece(_ piece: Confetti) -> some View {
        let radius = tile.contentSize.height / 2
        let side = 5 * tile.scale
        return Capsule()
            .fill(piece.color)
            .frame(width: piece.isDash ? side * 1.8 : side, height: side * (piece.isDash ? 0.7 : 1))
            .rotationEffect(.degrees(piece.angle))
            .offset(x: piece.position.x * radius, y: piece.position.y * radius)
            .transition(reduceMotion ? .opacity
                        : .offset(x: -piece.position.x * radius, y: -piece.position.y * radius).combined(with: .scale(scale: 0.2)))
            .accessibilityHidden(true)
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded(.up)), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// A round button with a tinted disc: coral stop, green start, grey lap/reset.
struct TintedDiscButton<Label: View>: View {
    @Environment(\.tile) private var tile
    var tint: Color?
    var diameter: CGFloat
    var accessibilityLabel: String
    var action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        let side = diameter * tile.scale
        Button(action: action) {
            label
                .foregroundStyle(tint ?? tile.surface.primary)
                .frame(width: side, height: side)
                .background(Circle().fill(tint.map { $0.opacity(0.26) } ?? tile.surface.controlFill))
                .contentShape(Circle())
        }
        .buttonStyle(TilePressStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Stopwatch C and M. C: time over a start/stop disc. M: label and big time beside Lap/Reset and start/stop.
struct StopwatchFace: View {
    @Environment(\.tile) private var tile
    var elapsed: TimeInterval
    var isRunning: Bool
    /// "Lap 2 · 0:41.3" once a lap is taken.
    var lastLap: String?
    var onToggle: () -> Void = {}
    var onLap: () -> Void = {}
    var onReset: () -> Void = {}

    var body: some View {
        Group {
            if tile.isCompact || tile.isPortrait {
                VStack(spacing: 0) {
                    time(.heroCompact).minimumScaleFactor(0.7).padding(.top, 4 * tile.scale)
                    Spacer(minLength: 0)
                    toggleButton(diameter: 26)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            } else {
                // The label runs above the buttons, so only the time shares the row with them.
                HStack(spacing: 5 * tile.scale) {
                    time(.hero).minimumScaleFactor(0.7)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 4 * tile.scale)
                    Spacer(minLength: 0)
                    if isRunning {
                        TintedDiscButton(tint: nil, diameter: 28, accessibilityLabel: "Lap", action: onLap) {
                            Text("Lap").tileStyle(.detail, color: tile.surface.primary).fontWeight(.semibold)
                        }
                    } else {
                        TintedDiscButton(tint: nil, diameter: 28, accessibilityLabel: "Reset", action: onReset) {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: 11 * tile.scale, weight: .bold))
                        }
                        .disabled(elapsed == 0)
                        .opacity(elapsed == 0 ? 0.5 : 1)
                    }
                    toggleButton(diameter: 28)
                }
                .overlay(alignment: .topLeading) { Text(lastLap ?? "Stopwatch").tileStyle(.label) }
                .padding(.leading, 2 * tile.scale)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stopwatch, \(StopwatchText.format(elapsed).main)\(StopwatchText.format(elapsed).fraction)")
    }

    private func time(_ style: TileTextStyle) -> some View {
        let parts = StopwatchText.format(elapsed)
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.main).tileStyle(style)
            Text(parts.fraction).tileStyle(style, color: tile.surface.tertiary)
        }
    }

    private func toggleButton(diameter: CGFloat) -> some View {
        TintedDiscButton(tint: isRunning ? Palette.coral : Palette.done, diameter: diameter,
                         accessibilityLabel: isRunning ? "Stop" : "Start", action: onToggle) {
            Image(systemName: isRunning ? "stop.fill" : "play.fill").font(.system(size: diameter * 0.36 * tile.scale, weight: .bold))
        }
    }
}

/// Water, compact: a glass that fills with a sloshing surface each time a glass is added.
struct WaterFace: View {
    @Environment(\.tile) private var tile
    var glasses: Int
    var goal: Int

    var body: some View {
        let fraction = Double(glasses) / Double(max(goal, 1))
        let glass = GlassShape()
        VStack(spacing: 3 * tile.scale) {
            ZStack {
                WaterSurface(level: fraction.unitClamped, phase: Double(glasses) * .pi)
                    .fill(LinearGradient(colors: [Palette.water, Palette.water.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                    .padding(2 * tile.scale)
                    .clipShape(glass)
                glass.stroke(tile.surface.secondary, style: StrokeStyle(lineWidth: 1.8 * tile.scale, lineJoin: .round))
            }
            .frame(width: 25 * tile.scale, height: 34 * tile.scale)
            .tileAnimation(Motion.settle, value: glasses)
            HStack(spacing: 0) {
                Text("\(glasses)").tileStyle(.value, color: glasses >= goal ? Palette.water : nil)
                Text("/\(goal)").tileStyle(.value, color: tile.surface.secondary)
            }
            .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water: \(glasses) of \(goal) glasses. Tap to add one.")
    }
}

/// A tumbler: wider at the rim than the base.
private struct GlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        let taper = rect.width * 0.13
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + taper, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - taper, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// Liquid up to `level` with a gentle wave on top. `phase` animates with each new glass, which is the slosh;
/// nothing moves between taps.
private struct WaterSurface: Shape {
    var level: Double
    var phase: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(level, phase) }
        set { (level, phase) = (newValue.first, newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        guard level > 0 else { return Path() }
        let surface = rect.maxY - rect.height * level
        // The wave flattens out as the glass fills so a full glass reads as full.
        let amplitude = rect.height * 0.05 * (level < 1 ? 1 : 0)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for step in 0...24 {
            let progress = Double(step) / 24
            let height = surface + amplitude * sin(progress * 2 * .pi + phase)
            path.addLine(to: CGPoint(x: rect.minX + rect.width * progress, y: height))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// 10 · Input: To-Do. M: two rows and "+N more" (the add field joins when there's room). W: two rows and the add
/// field. L: two columns of two and the add field across. Checking pops the tick; the wrapper then fades the row out.
struct TodoListTile: View {
    @Environment(\.tile) private var tile
    var items: [TodoItem]
    var onToggle: (TodoItem.ID) -> Void = { _ in }
    var onAdd: (String) -> Void = { _ in }
    @State private var draft = ""

    private var columns: Int { tile.size == .large && !tile.isPortrait ? 2 : 1 }

    private var rowsPerColumn: Int {
        tile.isPortrait ? max(Int(tile.contentSize.height / (21 * tile.scale)) - 1, 2) : 2
    }

    /// M has room for three lines: rows plus the add field, or two rows and the overflow line.
    private var showsAddField: Bool { tile.size != .medium || tile.isPortrait || items.count <= 2 }

    var body: some View {
        let capacity = columns * rowsPerColumn
        let visible = Array(items.prefix(capacity))
        let hidden = items.count - visible.count
        VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                Text("All clear").tileStyle(.body, color: tile.surface.tertiary).padding(.leading, 2 * tile.scale)
            }
            HStack(alignment: .top, spacing: 10 * tile.scale) {
                ForEach(0..<columns, id: \.self) { column in
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(visible.dropFirst(column * rowsPerColumn).prefix(rowsPerColumn)) { item in
                            row(item)
                                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
            if showsAddField {
                addField(hidden: hidden)
            } else if hidden > 0 {
                Text("+\(hidden) more").tileStyle(.detail).padding(.leading, 21 * tile.scale)
                    .frame(height: rowHeight, alignment: .center)
            }
        }
    }

    private var rowHeight: CGFloat { (tile.size == .medium ? 19 : 21) * tile.scale }

    private func row(_ item: TodoItem) -> some View {
        Button { onToggle(item.id) } label: {
            HStack(spacing: 7 * tile.scale) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13 * tile.scale, weight: item.isDone ? .regular : .medium))
                    .foregroundStyle(item.isDone ? Palette.done : tile.surface.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: item.isDone)
                Text(item.title).tileStyle(.body, color: item.isDone ? tile.surface.tertiary : nil)
                    .strikethrough(item.isDone, color: tile.surface.tertiary).lineLimit(1)
            }
            .frame(height: rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.isDone ? "Tap to undo" : "Tap to complete")
        .tileAnimation(Motion.pop, value: item.isDone)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(item.isDone ? .isSelected : [])
    }

    private func addField(hidden: Int) -> some View {
        TileChip {
            HStack(spacing: 6 * tile.scale) {
                Image(systemName: "plus").font(.system(size: 10 * tile.scale, weight: .semibold))
                    .foregroundStyle(tile.surface.tertiary)
                TileTextField(text: $draft, placeholder: "Add a to-do") {
                    let title = draft.trimmingCharacters(in: .whitespaces)
                    guard !title.isEmpty else { return }
                    onAdd(title)
                    draft = ""
                }
                if hidden > 0 { Text("+\(hidden)").tileStyle(.detail).fixedSize() }
            }
            .padding(.horizontal, 2 * tile.scale)
        }
        .frame(height: 18 * tile.scale)
    }
}
