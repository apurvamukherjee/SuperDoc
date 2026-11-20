import SwiftUI

/// The motion vocabulary. Tiles animate on change and then rest; nothing loops except `workingPulse`, and only while
/// the thing it marks is actually working (idle CPU budget is < 1 %).
enum Motion {
    /// A value changing in place: a percentage, a meter, a ring.
    static let change = Animation.smooth(duration: 0.35)
    /// Neighbours sliding apart on reorder, a tile settling after a resize.
    static let settle = Animation.spring(response: 0.38, dampingFraction: 0.82)
    /// A tile lifting under the cursor at drag start (scale 1.06, deeper shadow).
    static let lift = Animation.spring(response: 0.24, dampingFraction: 0.7)
    /// Springy entrances: Limo popping out of the bar, Copy Peek, alert pills.
    static let pop = Animation.spring(response: 0.42, dampingFraction: 0.6)
    static let press = Animation.spring(response: 0.18, dampingFraction: 0.75)
    /// What every animation becomes under Reduce Motion: a short crossfade, no travel.
    static let reduced = Animation.easeInOut(duration: 0.18)

    static let liftScale: CGFloat = 1.06
}

extension View {
    /// `.animation(_:value:)` that falls back to a crossfade under Reduce Motion.
    func tileAnimation(_ animation: Animation = Motion.change, value: some Equatable) -> some View {
        modifier(TileAnimationModifier(animation: animation, value: value))
    }

    /// The agent "working" breath: opacity eases between 1 and 0.45 while `isActive`. Static under Reduce Motion.
    func workingPulse(_ isActive: Bool) -> some View {
        modifier(PulseModifier(isActive: isActive))
    }
}

private struct TileAnimationModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? Motion.reduced : animation, value: value)
    }
}

private struct PulseModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive, !reduceMotion {
            content.phaseAnimator([1.0, 0.45]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 0.9)
            }
        } else {
            content
        }
    }
}
