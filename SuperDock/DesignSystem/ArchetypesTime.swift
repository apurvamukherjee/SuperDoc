import SwiftUI

// Archetypes 9–10: Calendar / time, Input.

/// 9 · Time. Clock and World Clock: big numerals, period on the baseline, date line under.
struct ClockTile: View {
    @Environment(\.tile) private var tile
    var time: String
    /// "PM"; nil in 24-hour locales.
    var period: String?
    /// "THU 19" compact, "Thursday, 19 November" wider.
    var detail: String?

    var body: some View {
        VStack(alignment: tile.isCompact ? .center : .leading, spacing: 1) {
            HeroText(value: time, unit: tile.isCompact ? nil : period, style: tile.isCompact ? .heroCompact : .display)
            if let detail, tile.showsDetail { Text(detail).tileStyle(tile.isCompact ? .caption : .detail) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: tile.isCompact ? .center : .leading)
        .padding(.leading, tile.isCompact ? 0 : 2 * tile.scale)
    }
}

/// 9 · Calendar. Compact: a tear-off leaf. M: leaf + spelled-out date. W: this week's strip. L: two weeks + week number.
struct CalendarTile: View {
    @Environment(\.tile) private var tile
    var date: Date
    var calendar = Calendar.current

    var body: some View {
        switch tile.size {
        case .compact: leaf
        case .medium:
            HStack(spacing: 10 * tile.scale) {
                leaf.frame(width: tile.contentSize.height)
                VStack(alignment: .leading, spacing: 1) {
                    Text(date.formatted(.dateTime.weekday(.wide))).tileStyle(.title)
                    Text(date.formatted(.dateTime.day().month(.wide))).tileStyle(.detail)
                }
                Spacer(minLength: 0)
            }
        case .wide: weekStrip
        case .large: twoWeeks
        }
    }

    private var leaf: some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .tileStyle(.label, color: .white)
                .frame(maxWidth: .infinity)
                .padding(.top, tile.isCompact ? tile.padding : 0)
                .padding(.vertical, 3 * tile.scale)
                .background(Palette.today)
            Text("\(calendar.component(.day, from: date))").tileStyle(.display)
                .frame(maxHeight: .infinity)
        }
        .padding(tile.isCompact ? -tile.padding : 0)
        .clipShape(RoundedRectangle(cornerRadius: tile.isCompact ? 0 : tile.innerRadius, style: .continuous))
        .background(tile.isCompact ? .clear : tile.surface.chipFill,
                    in: RoundedRectangle(cornerRadius: tile.innerRadius, style: .continuous))
    }

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(week(offset: 0), id: \.self) { day in
                let isToday = calendar.isDate(day, inSameDayAs: date)
                VStack(spacing: 2 * tile.scale) {
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .tileStyle(.caption, color: isToday ? .white : nil)
                    Text("\(calendar.component(.day, from: day))")
                        .tileStyle(.heroCompact, color: isToday ? .white : day < date ? tile.surface.secondary : nil)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { if isToday { RoundedRectangle(cornerRadius: tile.innerRadius, style: .continuous).fill(Palette.today) } }
            }
        }
    }

    private var twoWeeks: some View {
        HStack(spacing: 10 * tile.scale) {
            VStack(alignment: .leading, spacing: 0) {
                Text(date.formatted(.dateTime.month(.abbreviated))).tileStyle(.label, color: Palette.today)
                Text("W\(calendar.component(.weekOfYear, from: date))").tileStyle(.hero)
            }
            .padding(.leading, 2 * tile.scale)
            Divider().overlay(tile.surface.divider)
            Grid(horizontalSpacing: 0, verticalSpacing: 4 * tile.scale) {
                ForEach(0..<2, id: \.self) { offset in
                    GridRow {
                        ForEach(week(offset: offset), id: \.self) { day in
                            let isToday = calendar.isDate(day, inSameDayAs: date)
                            Text("\(calendar.component(.day, from: day))")
                                .tileStyle(.value, color: isToday ? .white : nil)
                                .padding(.horizontal, 6 * tile.scale)
                                .background { if isToday { Capsule().fill(Palette.today) } }
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    /// The seven days of the week containing `date`, shifted by `offset` weeks; honours the locale's first weekday.
    private func week(offset: Int) -> [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start,
              let shifted = calendar.date(byAdding: .weekOfYear, value: offset, to: start) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: shifted) }
    }
}

/// Inline text that reads as plain text until tapped, then edits in place. Return or losing focus commits.
struct TileTextField: View {
    @Environment(\.tile) private var tile
    @Binding var text: String
    var placeholder: String
    var style = TileTextStyle.body
    var onCommit: () -> Void = {}
    @State private var isEditing = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onAppear { isFocused = true }
                    .onSubmit { isEditing = false; onCommit() }
                    .onChange(of: isFocused) { _, focused in if !focused { isEditing = false; onCommit() } }
            } else {
                Text(text.isEmpty ? placeholder : text)
                    .foregroundStyle(text.isEmpty ? tile.surface.tertiary : tile.surface.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { isEditing = true }
            }
        }
        .tileStyle(style)
    }
}

/// 10 · Input: Quick Note. Note-paper wash, amber label. Starts at M.
struct NoteTile: View {
    @Environment(\.tile) private var tile
    @Binding var text: String
    /// "Edited 4m ago", shown at L.
    var edited: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3 * tile.scale) {
            Text("Note").tileStyle(.label, color: tile.surface.isDark ? Palette.note : tile.surface.warning)
            TileTextField(text: $text, placeholder: "Note…")
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottomTrailing) {
            if let edited, tile.size == .large { Text(edited).tileStyle(.detail) }
        }
        .tileTint(Palette.note, opacity: 0.1)
    }
}

struct TodoItem: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var isDone = false
}

/// 10 · Input: To-Do. Check-off rows plus an add field.
struct TodoTile: View {
    @Environment(\.tile) private var tile
    var items: [TodoItem]
    var onToggle: (TodoItem.ID) -> Void = { _ in }
    var onAdd: (String) -> Void = { _ in }
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2 * tile.scale) {
            ForEach(items.prefix(tile.isPortrait ? 4 : 2)) { item in
                Button { onToggle(item.id) } label: {
                    HStack(spacing: 6 * tile.scale) {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13 * tile.scale))
                            .foregroundStyle(item.isDone ? Palette.done : tile.surface.secondary)
                        Text(item.title).tileStyle(.body, color: item.isDone ? tile.surface.tertiary : nil)
                            .strikethrough(item.isDone).lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .tileAnimation(value: item.isDone)
                .accessibilityAddTraits(item.isDone ? .isSelected : [])
            }
            Spacer(minLength: 0)
            TileChip {
                HStack(spacing: 6 * tile.scale) {
                    Image(systemName: "plus").font(.system(size: 10 * tile.scale, weight: .semibold))
                        .foregroundStyle(tile.surface.tertiary)
                    TileTextField(text: $draft, placeholder: "Add a to-do") {
                        guard !draft.isEmpty else { return }
                        onAdd(draft)
                        draft = ""
                    }
                }
            }
            .frame(height: 19 * tile.scale)
        }
    }
}
