import SwiftUI

/// What Limo has to say. Urgent alerts (needs you, frozen app) wear a coral rim and stay until handled.
struct LimoAlert {
    var title: String
    var detail: String?
    var pose: LimoPose
    /// A faint wash from Limo's end of the pill.
    var tint: Color = Palette.coral
    var action: (title: String, run: () -> Void)?

    var isUrgent: Bool { pose == .handUp || pose == .pokesIce }
}

/// Shared between the controller and the pill: flipping `isOut` inside an animation pops Limo out of the bar.
@MainActor @Observable
final class LimoStage {
    var alert: LimoAlert?
    var isOut = false
    var gaze = CGVector(dx: 0.5, dy: 0.2)
    var presence = LimoPresence.lively
    var reduceMotion = false
    /// Spring and squash only for a lively Limo with motion allowed; otherwise a crossfade.
    var travels: Bool { presence == .lively && !reduceMotion }
}

/// The alert pill: a 48 pt glass capsule with Limo spilling over its top edge.
struct LimoPill: View {
    static let pillHeight: CGFloat = 48
    /// Headroom above the pill for Limo's arms, props and the spring's overshoot; the whole thing stays ≤ 1.5× the bar.
    static let spill: CGFloat = 18
    /// Room for the pill's shadow; the panel clips at its bounds.
    static let margin: CGFloat = 12
    private static let figureSide: CGFloat = 54

    let stage: LimoStage
    let dismiss: () -> Void

    var body: some View {
        if let alert = stage.alert {
            content(alert)
                .padding(.top, Self.spill)
                .padding(.horizontal, Self.margin)
                .padding(.bottom, Self.margin)
                .contentShape(Rectangle())
                .onTapGesture(perform: dismiss)
                .accessibilityElement(children: .combine)
                .accessibilityLabel([alert.title, alert.detail].compactMap(\.self).joined(separator: ", "))
                .accessibilityAddTraits(.isButton)
        }
    }

    private var showsLimo: Bool { stage.presence != .hidden }

    private func content(_ alert: LimoAlert) -> some View {
        ZStack(alignment: .topLeading) {
            capsule(alert)
                .scaleEffect(x: stage.isOut || !stage.travels ? 1 : 0.3, y: 1, anchor: .leading)
                .opacity(stage.isOut ? 1 : 0)
                .animation(stage.travels ? Motion.pop.delay(0.07) : Motion.reduced, value: stage.isOut)
            if showsLimo {
                LimoLive(pose: alert.pose, gaze: stage.travels ? stage.gaze : .zero, breathes: stage.travels)
                    .frame(width: Self.figureSide, height: Self.figureSide)
                    .scaleEffect(x: stage.isOut || !stage.travels ? 1 : 1.25, y: stage.isOut || !stage.travels ? 1 : 0.55,
                                 anchor: .bottom)
                    .offset(x: 10, y: stage.isOut || !stage.travels ? -6 : 60 + Self.margin)
                    .opacity(stage.isOut || stage.travels ? 1 : 0)
                    .animation(stage.travels ? Motion.pop : Motion.reduced, value: stage.isOut)
            }
        }
    }

    private func capsule(_ alert: LimoAlert) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(alert.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                if let detail = alert.detail {
                    Text(detail).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .fixedSize()   // the panel sizes to fit; never truncate
            if let action = alert.action {
                actionButton(action, pose: alert.pose)
            }
        }
        .padding(.leading, showsLimo ? Self.figureSide + 14 : 20)
        .padding(.trailing, alert.action == nil ? 22 : 8)
        .frame(height: Self.pillHeight)
        .background {
            Capsule().fill(Color(rgb: 0x14152A, opacity: 0.42))
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().fill(LinearGradient(colors: [alert.tint.opacity(0.18), .clear],
                                                       startPoint: .leading, endPoint: .trailing)))
                .overlay(Capsule().strokeBorder(alert.isUrgent ? Palette.coral : .white.opacity(0.2),
                                                lineWidth: alert.isUrgent ? 1.5 : 1))
                .shadow(color: alert.isUrgent ? Palette.coral.opacity(0.45) : .black.opacity(0.25), radius: 10, y: 3)
        }
        .environment(\.colorScheme, .dark)
    }

    private func actionButton(_ action: (title: String, run: () -> Void), pose: LimoPose) -> some View {
        let (fill, ink): (Color, Color) = switch pose {
        case .handUp: (Palette.coral, .white)
        case .takesSip: (Palette.water, Palette.inkDeep)
        default: (.white, Palette.inkDeep)
        }
        return Button {
            action.run()
            dismiss()
        } label: {
            Text(action.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(ink)
                .padding(.horizontal, 16).frame(height: 32)
                .background(fill, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
