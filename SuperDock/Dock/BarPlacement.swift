import CoreGraphics

enum DockOrientation: Equatable {
    case bottom, left, right
}

/// Where the bar sits relative to the Dock. Each case reads naturally for a bottom Dock and maps onto a side Dock.
enum BarPosition: String, CaseIterable, Identifiable {
    case leading   // left of a bottom Dock; above a side Dock
    case trailing  // right of a bottom Dock; below a side Dock
    case outside   // above a bottom Dock; beside a side Dock, toward the middle of the screen

    var id: Self { self }
}

/// Pure geometry, kept free of AppKit so it can be unit tested. All rects are AppKit coordinates
/// (origin at the bottom-left of the primary screen, y up) unless the name says AX.
enum BarPlacement {
    /// AX reports rects with a top-left origin and y pointing down, measured from the primary screen's top edge.
    static func appKitRect(fromAX rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Auto-hide parks the Dock just outside the screen edge (touching, zero overlap), which this treats as hidden.
    static func isShowing(_ dock: CGRect, on screen: CGRect) -> Bool {
        let overlap = screen.intersection(dock)
        return !overlap.isNull && overlap.width > 1 && overlap.height > 1
    }

    static func orientation(of dock: CGRect, in bounds: CGRect) -> DockOrientation {
        guard dock.height > dock.width else { return .bottom }
        return dock.midX < bounds.midX ? .left : .right
    }

    /// Gap around and between tiles.
    static let tileSpacing: CGFloat = 6

    /// Side of a one-column tile: tiles are square per column and fill the bar's thickness.
    static func tileUnit(thickness: CGFloat) -> CGFloat {
        thickness - 2 * tileSpacing
    }

    /// Bar length for a row of tiles totalling `columns` (at least 1, so an empty bar still has room for its + button).
    static func barLength(columns: Int, thickness: CGFloat) -> CGFloat {
        let columns = max(columns, 1)
        return 2 * tileSpacing + CGFloat(columns) * tileUnit(thickness: thickness) + CGFloat(columns - 1) * tileSpacing
    }

    /// `length` runs along the Dock. `thickness` defaults to the Dock's own; a thicker bar grows away from the screen
    /// edge, so it stays flush with the Dock's edge and still rides the auto-hide slide.
    /// `bounds` is the usable screen area (visibleFrame) the bar must fit inside along the Dock.
    static func barFrame(
        dock: CGRect, bounds: CGRect, position: BarPosition, gap: CGFloat, length: CGFloat, thickness: CGFloat? = nil
    ) -> CGRect {
        let orientation = orientation(of: dock, in: bounds)
        let thickness = thickness ?? (orientation == .bottom ? dock.height : dock.width)
        let preferred = frame(at: position)
        // Only the axis along the Dock is checked; the other stays locked to the Dock so the bar rides its auto-hide slide.
        let fits = orientation == .bottom
            ? preferred.minX >= bounds.minX && preferred.maxX <= bounds.maxX
            : preferred.minY >= bounds.minY && preferred.maxY <= bounds.maxY
        // No room on the requested side (common with side Docks, which fill most of the screen height):
        // move above/beside the Dock instead of going off-screen or on top of it. `.outside` always has room.
        if fits || position == .outside { return preferred }
        return frame(at: .outside)

        func frame(at position: BarPosition) -> CGRect {
            // Cross-axis origin for a bar flush with the Dock's screen edge.
            let edgeX = orientation == .right ? dock.maxX - thickness : dock.minX
            switch (orientation, position) {
            case (.bottom, .leading):
                return CGRect(x: dock.minX - gap - length, y: dock.minY, width: length, height: thickness)
            case (.bottom, .trailing):
                return CGRect(x: dock.maxX + gap, y: dock.minY, width: length, height: thickness)
            case (.bottom, .outside):
                return CGRect(x: dock.midX - length / 2, y: dock.maxY + gap, width: length, height: thickness)
            case (_, .leading):
                return CGRect(x: edgeX, y: dock.maxY + gap, width: thickness, height: length)
            case (_, .trailing):
                return CGRect(x: edgeX, y: dock.minY - gap - length, width: thickness, height: length)
            case (.left, .outside):
                return CGRect(x: dock.maxX + gap, y: dock.midY - length / 2, width: thickness, height: length)
            case (.right, .outside):
                return CGRect(x: dock.minX - gap - thickness, y: dock.midY - length / 2, width: thickness, height: length)
            }
        }
    }
}
