#if DEBUG
import SwiftUI

extension GallerySheets {
    /// The four onboarding steps, then the other states worth checking.
    /// Compare with design/mockups/09-onboarding.png.
    static var onboarding: AnyView? { AnyView(OnboardingSheet()) }
}

private struct OnboardingSheet: View {
    private struct Frame {
        let step: OnboardingStep
        var position = BarPosition.trailing
        var starter = StarterSet.developer
        var trusted = false
        let caption: String
    }

    private static let steps = [
        Frame(step: .welcome, caption: "Welcome. Limo springs up from the bottom edge and waves once. Text fades in 120 ms later."),
        Frame(step: .placement, caption: "Placement. Tapping an option moves the preview bar on a spring. Limo points at it."),
        Frame(step: .accessibility, caption: "Accessibility. Polls every second; on grant: a check, then the next step."),
        Frame(step: .starter, caption: "Finish. Confetti, then the window shrinks into the real bar.")
    ]

    private static let states = [
        Frame(step: .placement, position: .leading, caption: "Placement · Left"),
        Frame(step: .placement, position: .outside, caption: "Placement · Above"),
        Frame(step: .accessibility, trusted: true, caption: "Accessibility · granted (Limo pocketed the key)"),
        Frame(step: .starter, starter: .justMe, caption: "Starter · Just me")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "FIRST RUN · 4 STEPS · ABOUT 40 SECONDS")
                .font(.system(size: 13, weight: .semibold)).tracking(1.6).foregroundStyle(.white.opacity(0.75))
            Text(verbatim: "Onboarding, hosted by Limo")
                .font(.system(size: 46, weight: .bold)).tracking(-1).foregroundStyle(.white)
                .padding(.top, 6)
            row(Self.steps).padding(.top, 22)
            row(Self.states).padding(.top, 40)
        }
        .padding(.horizontal, 64).padding(.top, 54).padding(.bottom, 64)
        .frame(width: 1728, alignment: .leading)
        .background(galleryWallpaper(.glassDark))
    }

    private func row(_ frames: [Frame]) -> some View {
        HStack(alignment: .top, spacing: 24) {
            ForEach(frames.indices, id: \.self) { index in
                let frame = frames[index]
                VStack(alignment: .leading, spacing: 18) {
                    OnboardingView(step: frame.step, position: frame.position, starter: frame.starter,
                                   trusted: frame.trusted, still: true) { _ in }
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        // Flatten first, or every card inside the window gets its own shadow.
                        .compositingGroup()
                        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                    Text(verbatim: frame.caption)
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
                        .frame(width: OnboardingTheme.windowSize.width, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
#endif
