import SwiftUI

/// Limo's face alone, for empty states and other small glyphs. Asleep by default ("All quiet").
struct LimoFace: View {
    var snoring = true
    var pose: LimoPose = .naps
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LimoFigure(pose: pose, outlined: colorScheme == .dark, faceOnly: true)
            .overlay(alignment: .topTrailing) {
                if snoring { snore }
            }
            .accessibilityHidden(true)
    }

    private var snore: some View {
        Text("z").font(.system(size: 7, weight: .heavy, design: .rounded)).foregroundStyle(.secondary).offset(x: 9, y: -8)
    }
}

/// Limo on screen: blinks every 6–10 s and turns a 1.5 % breath on the same wake-up. One sparse timer while
/// visible and no render loop, so an idle Limo costs nothing between blinks.
struct LimoLive: View {
    var pose: LimoPose
    var gaze: CGVector = .zero
    var outlined = true
    /// Calm presence keeps the blink but drops the bob.
    var breathes = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blinking = false
    @State private var inhaled = false

    var body: some View {
        LimoFigure(pose: pose, gaze: reduceMotion ? .zero : gaze, blinking: blinking, outlined: outlined)
            .scaleEffect(x: 1, y: inhaled ? 1.015 : 1, anchor: .bottom)
            .id(pose)
            .transition(.opacity)
            .animation(Motion.reduced, value: pose)
            .task { await live() }
    }

    private func live() async {
        while true {
            do {
                try await Task.sleep(for: .seconds(Double.random(in: 6...10)))
                blinking = true
                try await Task.sleep(for: .milliseconds(140))
                blinking = false
            } catch {
                return   // the view left the screen; nothing to clean up but the blink
            }
            if breathes, !reduceMotion {
                withAnimation(.easeInOut(duration: 1.6)) { inhaled.toggle() }
            }
        }
    }
}
