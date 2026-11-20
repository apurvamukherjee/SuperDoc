import SwiftUI

/// Settings → Widgets gallery: category chips, then a card per widget with a live preview, size pills and Add.
/// A search query looks across every category.
struct WidgetPicker: View {
    let search: String
    let onAdd: (WidgetDescriptor, TileSize) -> Void
    @State private var category = WidgetCategory.ai
    @AppStorage(SettingsTab.storageKey) private var settingsTab = SettingsTab.widgets

    var body: some View {
        let all = WidgetRegistry.all
        let query = search.trimmingCharacters(in: .whitespaces)
        let shown = query.isEmpty
            ? all.filter { $0.category == category }
            : all.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.category.title.localizedCaseInsensitiveContains(query) }
        VStack(alignment: .leading, spacing: 18) {
            if query.isEmpty {
                ChipFlow(spacing: 8) {
                    // Community stays even when empty: it is where people find out plugins exist.
                    let categories = WidgetCategory.allCases.filter { cat in cat == .community || all.contains { $0.category == cat } }
                    ForEach(categories, id: \.self) { cat in
                        CategoryChip(category: cat, isSelected: cat == category) { category = cat }
                    }
                }
                .focusEffectDisabled()
            }
            if shown.isEmpty, query.isEmpty {
                ContentUnavailableView {
                    Label("No community plugins yet", systemImage: WidgetCategory.community.pickerSymbol)
                } description: {
                    Text("Plugins are small JSON widgets anyone can write.")
                } actions: {
                    Button("Browse Plugins") { settingsTab = .plugins }
                }
                .frame(maxWidth: .infinity)
            } else if shown.isEmpty {
                ContentUnavailableView.search(text: query).frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 296), spacing: 14, alignment: .top)], spacing: 14) {
                    ForEach(shown) { widget in
                        WidgetCard(widget: widget) { onAdd(widget, $0) }
                    }
                }
            }
        }
    }
}

extension WidgetCategory {
    /// Category colour for chips, size pills and the "Your bar" strip (mockup 07).
    var pickerTint: Color {
        switch self {
        case .ai: Color(rgb: 0xFF8A3D)
        case .time: Color(rgb: 0x5E6AE8)
        case .system: Color(rgb: 0x2F8CEB)
        case .weather: Color(rgb: 0x1FB3D9)
        case .media: Color(rgb: 0xF0436A)
        case .controls: Color(rgb: 0x8E6CF0)
        case .files: Color(rgb: 0x2E9E9A)
        case .productivity: Color(rgb: 0x2E9E5B)
        case .dev: Color(rgb: 0x4C5566)
        case .finance: Color(rgb: 0x1F9D57)
        case .news: Color(rgb: 0xE0663A)
        case .fun: Color(rgb: 0xE8A400)
        case .community: Color(rgb: 0x7D7D85)
        }
    }

    var pickerSymbol: String {
        switch self {
        case .ai: "gauge.with.dots.needle.33percent"
        case .time: "clock"
        case .system: "cpu"
        case .weather: "cloud"
        case .media: "music.note"
        case .controls: "slider.horizontal.3"
        case .files: "folder"
        case .productivity: "checkmark"
        case .dev: "chevron.left.forwardslash.chevron.right"
        case .finance: "chart.line.uptrend.xyaxis"
        case .news: "newspaper"
        case .fun: "dice"
        case .community: "puzzlepiece.extension"
        }
    }

    /// Chips are short: "Community", not "Community Plugins".
    var chipTitle: String { self == .community ? String(localized: "Community") : title }
}

extension TileSize {
    /// The pill letter: C, M, W, L.
    var letter: String { String(title.prefix(1)) }
}

private struct CategoryChip: View {
    let category: WidgetCategory
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Label(category.chipTitle, systemImage: category.pickerSymbol)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .frame(height: 30)
                .foregroundStyle(isSelected ? .white : .primary)
                .background {
                    Capsule().fill(isSelected ? AnyShapeStyle(category.pickerTint) : AnyShapeStyle(Color(nsColor: .controlBackgroundColor)))
                }
                .overlay { Capsule().strokeBorder(isSelected ? .clear : Color(nsColor: .separatorColor)) }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct WidgetCard: View {
    let widget: WidgetDescriptor
    let add: (TileSize) -> Void
    @State private var chosen: TileSize?

    private var size: TileSize { chosen ?? widget.supportedSizes.first ?? .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PreviewBar(tiles: [PreviewTile(widget: widget, size: size)])
                .frame(maxWidth: .infinity)
                .frame(height: 96)
                .background(PreviewWallpaper())
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Text(widget.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        if widget.usesNetwork {
                            Image(systemName: "network")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .help("Uses the internet")
                                .accessibilityLabel("Uses the internet")
                        }
                    }
                    HStack(spacing: 4) {
                        ForEach(widget.supportedSizes) { option in
                            SizePill(size: option, tint: widget.category.pickerTint, isSelected: option == size) {
                                chosen = option
                            }
                        }
                    }
                }
                Spacer(minLength: 8)
                Button { add(size) } label: {
                    Label("Add", systemImage: "plus").font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(AddButtonStyle())
                .accessibilityLabel("Add \(widget.name), \(size.title)")
            }
        }
        .padding(9)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(nsColor: .separatorColor).opacity(0.6))
        }
    }
}

private struct SizePill: View {
    let size: TileSize
    let tint: Color
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Text(size.letter)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(isSelected ? .white : tint)
                .frame(width: 20, height: 18)
                .background(tint.opacity(isSelected ? 1 : 0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(size.title)
        .accessibilityLabel(size.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// White rounded "+ Add" from the mockup; native bordered buttons are smaller and greyer.
private struct AddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(nsColor: .separatorColor)) }
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

/// Left-to-right rows that wrap, for the category chips.
private struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: rows.map(\.width).max() ?? 0, height: rows.last.map { $0.top + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var originX = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: originX, y: bounds.minY + row.top), proposal: ProposedViewSize(size))
                originX += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
        var top: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let current = rows[rows.count - 1]
            if !current.indices.isEmpty, current.width + spacing + size.width > width {
                rows.append(Row(top: current.top + current.height + spacing))
            }
            let gap = rows[rows.count - 1].indices.isEmpty ? 0 : spacing
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += gap + size.width
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}
