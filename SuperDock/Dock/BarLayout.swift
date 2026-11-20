import AppKit
import SwiftUI

/// One tile as the bar lays it out. The live host builds these from `LayoutStore`; the gallery from fixtures.
struct BarItem: Identifiable {
    let id: UUID
    let size: TileSize
    let name: String
    let supportedSizes: [TileSize]
    let view: AnyView
}

/// What the bar's interactions change. Defaults do nothing, so the gallery can render the layout inert.
struct BarActions {
    /// Move the first tile into the slot held by the second (`LayoutStore.move`).
    var move: (UUID, UUID) -> Void = { _, _ in }
    var setSize: (TileSize, UUID) -> Void = { _, _ in }
    var remove: (UUID) -> Void = { _ in }
    var openWidgets: () -> Void = {}
}

/// A tile mid-drag: which one, and how far it has travelled along the bar.
struct BarDrag: Equatable {
    var id: UUID
    var translation: CGFloat = 0
}

extension SurfaceTokens {
    /// The bar's tokens from the style pref, the system's mode and Reduce Transparency. Host and gallery both use this.
    static func bar(_ style: BarStyle, isDark: Bool, reduceTransparency: Bool, tileBackgrounds: Bool) -> SurfaceTokens {
        SurfaceTokens(SurfaceStyle.resolve(style, isDark: isDark, reduceTransparency: reduceTransparency),
                      tileBackgrounds: tileBackgrounds)
    }
}

extension TileContext {
    /// The context every tile on the bar shares (size is set per tile).
    static func bar(surface: SurfaceTokens, accent: Color, cornerRadius: CGFloat, thickness: CGFloat,
                    isVertical: Bool) -> TileContext {
        TileContext(unit: BarPlacement.tileUnit(thickness: thickness), isPortrait: isVertical, surface: surface,
                    accent: accent, radius: max(cornerRadius - 6, 4))
    }
}

/// The bar's contents: optional app strip, then the tiles (or the empty-bar invitation), with drag-to-reorder and
/// the right-click menu. Knows nothing about prefs or the layout store, so the gallery renders this exact view.
struct BarLayout: View {
    let context: TileContext
    let items: [BarItem]
    var appStrip: [AppStrip.Item]?
    var actions = BarActions()
    /// A widget is being dragged over the bar (the host owns the drop, since only it can add to the layout).
    var isDropTargeted = false

    @State private var drag: BarDrag?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let space = "bar"
    private var spacing: CGFloat { TileContext.spacing }

    init(context: TileContext, items: [BarItem], appStrip: [AppStrip.Item]? = nil, actions: BarActions = BarActions(),
         isDropTargeted: Bool = false, drag: BarDrag? = nil) {
        self.context = context
        self.items = items
        self.appStrip = appStrip
        self.actions = actions
        self.isDropTargeted = isDropTargeted
        _drag = State(initialValue: drag)
    }

    var body: some View {
        let stack = context.isPortrait ? AnyLayout(VStackLayout(spacing: spacing))
                                       : AnyLayout(HStackLayout(spacing: spacing))
        stack {
            if let appStrip {
                AppStripView(items: appStrip, context: context)
                divider
            }
            if items.isEmpty {
                BarInvitation(isTargeted: isDropTargeted, action: actions.openWidgets).tileContext(invitationContext)
            }
            ForEach(items) { tile($0) }
        }
        .padding(spacing)
        .coordinateSpace(name: Self.space)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(context.accent)
    }

    private var divider: some View {
        let length = context.unit * 0.6
        return Rectangle().fill(context.surface.strongStroke)
            .frame(width: context.isPortrait ? length : 1, height: context.isPortrait ? 1 : length)
    }

    /// The invitation floats on the bar as a dashed slot, never a filled card.
    private var invitationContext: TileContext {
        var invitation = context
        invitation.size = .medium
        invitation.surface = SurfaceTokens(context.surface.style, tileBackgrounds: false)
        return invitation
    }

    // MARK: - Tiles

    private func tile(_ item: BarItem) -> some View {
        var tileContext = context
        tileContext.size = item.size
        let isDragged = drag?.id == item.id
        let shift = isDragged ? 0 : self.shift(of: item.id)
        let travel = isDragged ? drag?.translation ?? 0 : shift
        return item.view
            .tileChrome()
            .tileContext(tileContext)
            .background { if isDragged { liftedBacking } }
            .accessibilityElement(children: .combine)
            .scaleEffect(isDragged ? Motion.liftScale : 1)
            .shadow(color: .black.opacity(isDragged ? 0.35 : 0), radius: isDragged ? 16 : 0, y: isDragged ? 8 : 0)
            .offset(x: context.isPortrait ? 0 : travel, y: context.isPortrait ? travel : 0)
            // Keyed on the shift alone, so neighbours spring aside while the dragged tile tracks the cursor 1:1.
            .tileAnimation(Motion.settle, value: shift)
            .background { if isDragged { slotOutline.offset(slotOffset) } }
            .zIndex(isDragged ? 1 : 0)
            .gesture(dragGesture(item.id))
            .contextMenu { menu(item) }
            .accessibilityAction(named: "Move Earlier") { step(item.id, by: -1) }
            .accessibilityAction(named: "Move Later") { step(item.id, by: 1) }
    }

    /// Glass tiles are see-through; lifted over a neighbour they need a solid card or both read as one smear.
    private var liftedBacking: some View {
        RoundedRectangle(cornerRadius: context.radius, style: .continuous)
            .fill(SurfaceTokens(context.surface.isDark ? .solidDark : .solidLight).tileFill)
    }

    private var slotOutline: some View {
        RoundedRectangle(cornerRadius: context.radius, style: .continuous)
            .strokeBorder(context.surface.strongStroke, lineWidth: 1)
            .tileAnimation(Motion.settle, value: slotOffset)
    }

    // MARK: - Menu

    @ViewBuilder
    private func menu(_ item: BarItem) -> some View {
        Menu("Size") {
            ForEach(TileSize.allCases) { size in
                Toggle(size.title, isOn: Binding(get: { item.size == size },
                                                 set: { if $0 { actions.setSize(size, item.id) } }))
                    .disabled(!item.supportedSizes.contains(size))
            }
        }
        Button("Widget Settings…", action: actions.openWidgets)
        Button("Add Widget…", action: actions.openWidgets)
        Divider()
        Button("Remove “\(item.name)”", role: .destructive) { actions.remove(item.id) }
    }

    // MARK: - Drag to reorder

    private func dragGesture(_ id: UUID) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let raw = context.isPortrait ? value.translation.height : value.translation.width
                let translation = clamped(raw, for: id)
                if drag?.id == id {
                    drag?.translation = translation
                } else {
                    withAnimation(animation(Motion.lift)) { drag = BarDrag(id: id, translation: translation) }
                }
            }
            .onEnded { _ in drop() }
    }

    private func drop() {
        guard let drag else { return }
        guard let slots else { return self.drag = nil }
        withAnimation(animation(Motion.settle)) {
            if slots.target != slots.from { actions.move(drag.id, items[slots.target].id) }
            self.drag = nil
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func step(_ id: UUID, by delta: Int) {
        guard let from = index(of: id), items.indices.contains(from + delta) else { return }
        actions.move(id, items[from + delta].id)
    }

    private func animation(_ animation: Animation) -> Animation { reduceMotion ? Motion.reduced : animation }

    private func index(of id: UUID) -> Int? { items.firstIndex { $0.id == id } }

    private var reorder: BarReorder {
        BarReorder(lengths: items.map { TileContext.length(columns: $0.size.columns, unit: context.unit) }, spacing: spacing)
    }

    /// The dragged tile's index and the slot it would drop into.
    private var slots: (from: Int, target: Int)? {
        guard let drag, let from = index(of: drag.id) else { return nil }
        return (from, reorder.target(from: from, translation: drag.translation))
    }

    private func clamped(_ translation: CGFloat, for id: UUID) -> CGFloat {
        index(of: id).map { reorder.clamp(translation, from: $0) } ?? 0
    }

    private func shift(of id: UUID) -> CGFloat {
        guard let slots, let index = index(of: id) else { return 0 }
        return reorder.shift(of: index, from: slots.from, target: slots.target)
    }

    private var slotOffset: CGSize {
        let distance = slots.map { reorder.slotOffset(from: $0.from, target: $0.target) } ?? 0
        return context.isPortrait ? CGSize(width: 0, height: distance) : CGSize(width: distance, height: 0)
    }
}

/// The empty bar: one dashed slot inviting the first widget, with Limo beside it.
private struct BarInvitation: View {
    let isTargeted: Bool
    let action: () -> Void
    @Environment(\.tile) private var tile

    var body: some View {
        Button(action: action) {
            let stack = tile.isPortrait ? AnyLayout(VStackLayout(spacing: 6 * tile.scale))
                                        : AnyLayout(HStackLayout(spacing: 10 * tile.scale))
            stack {
                LimoFace(snoring: false).frame(width: 0.4 * tile.unit, height: 0.4 * tile.unit)
                VStack(alignment: tile.isPortrait ? .center : .leading, spacing: 1) {
                    Text("Add widgets").lineLimit(2).tileStyle(.title)
                    if tile.showsDetail { Text("or drop one here").lineLimit(2).tileStyle(.detail) }
                }
                .multilineTextAlignment(tile.isPortrait ? .center : .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tileOutline(isTargeted ? .setup : .dashed)
        .tileChrome()
        .accessibilityLabel("Add widgets")
    }
}
