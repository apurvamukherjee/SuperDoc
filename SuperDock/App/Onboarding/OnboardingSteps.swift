import SwiftUI

/// Label, heading and copy under each step's art; `extra` is the step's controls.
private struct StepText<Extra: View>: View {
    let label: String
    let heading: String
    var copy: String?
    @ViewBuilder var extra: Extra

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(OnboardingTheme.label)
            Text(heading)
                .font(.system(size: 25, weight: .bold))
                .tracking(-0.7)
                .foregroundStyle(OnboardingTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8.5)
            if let copy {
                Text(copy)
                    .font(.system(size: 13))
                    .lineSpacing(3.5)
                    .foregroundStyle(OnboardingTheme.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            extra
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, OnboardingTheme.margin)
        .padding(.top, 22)
    }
}

extension StepText where Extra == EmptyView {
    init(label: String, heading: String, copy: String) {
        self.init(label: label, heading: heading, copy: copy) { EmptyView() }
    }
}

private func stepLabel(_ step: OnboardingStep) -> String {
    String(localized: "Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)").uppercased()
}

// MARK: 1 · Welcome

struct OnboardingWelcomeStep: View {
    let entered: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RadialGradient(colors: [Palette.coral.opacity(0.16), Palette.coral.opacity(0)],
                               center: UnitPoint(x: 0.5, y: 0.56), startRadius: 0, endRadius: 120)
                OnboardingLimo(look: LimoPose.saysHi.look, gaze: CGVector(dx: 0.6, dy: 0.25))
                    .frame(width: 190, height: 190)
                    .keyframeAnimator(initialValue: 0.0, trigger: entered && !reduceMotion) { limo, angle in
                        limo.rotationEffect(.degrees(angle), anchor: .bottom)
                    } keyframes: { _ in
                        // One wave, after the spring has landed.
                        KeyframeTrack {
                            LinearKeyframe(0, duration: 0.4)
                            CubicKeyframe(7, duration: 0.16)
                            CubicKeyframe(-5, duration: 0.18)
                            CubicKeyframe(3, duration: 0.14)
                            CubicKeyframe(0, duration: 0.14)
                        }
                    }
                    // Off-centre like the mockup: the waving arm balances the body.
                    .offset(x: 30, y: 38)
                    .offset(y: entered || reduceMotion ? 0 : 420)
                    .opacity(entered || !reduceMotion ? 1 : 0)
            }
            .frame(height: OnboardingTheme.heroHeight)
            StepText(label: String(localized: "Welcome").uppercased(),
                     heading: String(localized: "hi, i'm limo.\nlet's set up your dock."),
                     copy: String(localized: """
                        SuperDock adds a bar of live widgets next to your Dock: AI limits, coding agents, weather, \
                        music and more. Free, private, no account.
                        """))
                .opacity(entered ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.12), value: entered)
            Spacer(minLength: 0)
        }
    }
}

// MARK: 2 · Placement

struct OnboardingPlacementStep: View {
    let position: BarPosition
    let select: (BarPosition) -> Void

    private static let options: [(BarPosition, String)] = [
        (.leading, String(localized: "Left")), (.trailing, String(localized: "Right")), (.outside, String(localized: "Above"))
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                OnboardingHeroPanel()
                OnboardingPlacementPreview(position: position)
                OnboardingLivePreviewChip()
            }
            .frame(height: OnboardingTheme.heroHeight)
            StepText(label: stepLabel(.placement), heading: String(localized: "Where should I sit?"),
                     copy: String(localized: "Next to your Dock. You can change this any time in Settings.")) {
                HStack(spacing: 8) {
                    ForEach(Self.options, id: \.0) { option, title in
                        Button { select(option) } label: {
                            PlacementCard(option: option, title: title, selected: option == position)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(option == position ? .isSelected : [])
                    }
                }
                .padding(.top, 14)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct PlacementCard: View {
    let option: BarPosition
    let title: String
    let selected: Bool

    var body: some View {
        VStack(spacing: 0) {
            glyph.frame(height: 20).padding(.top, 19)
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(OnboardingTheme.ink)
                .frame(height: 16)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 66.5, alignment: .top)
        .onboardingCard(radius: 14, selected: selected)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var glyph: some View {
        let coral = RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Palette.coral)
        let grey = RoundedRectangle(cornerRadius: 3, style: .continuous).fill(OnboardingTheme.pill)
        switch option {
        case .leading:
            HStack(spacing: 2.5) { coral.frame(width: 22.5, height: 11); grey.frame(width: 33.5, height: 11) }
        case .trailing:
            HStack(spacing: 2.5) { grey.frame(width: 33.5, height: 11); coral.frame(width: 22.5, height: 11) }
        case .outside:
            VStack(spacing: 3) { coral.frame(width: 26, height: 8); grey.frame(width: 34, height: 7) }
        }
    }
}

// MARK: 3 · Accessibility

struct OnboardingAccessibilityStep: View {
    let trusted: Bool
    let spins: Int
    /// Shown on its own after an update lost the grant, where "Step 3 of 4" would make no sense.
    var standalone = false

    private static let holdingKey = LimoLook(eyes: .dots, brows: .curious, mouth: .smile)
    private static let pocketed = LimoLook(eyes: .happy, mouth: .smile)

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                OnboardingSettingsCard().padding(.leading, 30).padding(.top, 46.5)
                OnboardingLimo(look: trusted ? Self.pocketed : Self.holdingKey, outlined: false, holdsKey: !trusted)
                    .frame(width: 112, height: 112)
                    .position(x: 203.5, y: 206)
            }
            .frame(width: OnboardingTheme.windowSize.width, height: OnboardingTheme.heroHeight, alignment: .topLeading)
            StepText(label: standalone ? String(localized: "Welcome back") : stepLabel(.accessibility),
                     heading: String(localized: "One permission, so I can find your Dock"),
                     copy: String(localized: """
                        Accessibility lets SuperDock read where your Dock is and how big it is, so the bar can sit beside it. \
                        It never reads your screen, prompts or keystrokes.
                        """)) {
                status.padding(.top, 12)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var status: some View {
        HStack(spacing: 8) {
            if trusted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.done)
                    .transition(.scale.combined(with: .opacity))
                Text(String(localized: "Access granted. Thanks!"))
                    .foregroundStyle(OnboardingTheme.paper.good)
            } else {
                OnboardingSpinner(spins: spins)
                Text(String(localized: "Waiting for you to switch it on…"))
                    .foregroundStyle(OnboardingTheme.label)
            }
        }
        .font(.system(size: 12.5, weight: .medium))
        .padding(.leading, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: 4 · Starter set

struct OnboardingStarterStep: View {
    @Binding var starter: StarterSet
    let celebrating: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                OnboardingHeroPanel()
                OnboardingStarterPreview(starter: starter).position(x: 190, y: 191.5)
                OnboardingLimo(look: LimoPose.celebrates.look)
                    .frame(width: 139, height: 139)
                    .position(x: 216, y: 111)
                OnboardingConfetti(fired: celebrating).position(x: 216, y: 104)
            }
            .frame(width: OnboardingTheme.windowSize.width, height: OnboardingTheme.heroHeight)
            StepText(label: stepLabel(.starter), heading: String(localized: "Pick a starter set"), copy: nil) {
                VStack(spacing: 7.5) {
                    ForEach(StarterSet.allCases) { set in
                        Button {
                            withAnimation(reduceMotion ? Motion.reduced : Motion.settle) { starter = set }
                        } label: {
                            StarterRow(set: set, selected: set == starter)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(set == starter ? .isSelected : [])
                    }
                }
                .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct StarterRow: View {
    let set: StarterSet
    let selected: Bool

    var body: some View {
        HStack(spacing: 11.5) {
            ZStack {
                if selected {
                    Circle().fill(Palette.coral)
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                } else {
                    Circle().strokeBorder(OnboardingTheme.pill, lineWidth: 1.5)
                }
            }
            .frame(width: 21, height: 21)
            VStack(alignment: .leading, spacing: 0) {
                Text(set.title).font(.system(size: 14, weight: .semibold))
                Text(set.subtitle).font(.system(size: 11.5))
            }
            .foregroundStyle(Palette.ink.opacity(0.68))
            Spacer(minLength: 0)
        }
        .padding(.leading, 12)
        .frame(height: 52.5)
        .onboardingCard(radius: 14, selected: selected)
        .contentShape(Rectangle())
    }
}

extension View {
    /// White card on paper; the selected one gets a coral ring just outside its edge.
    func onboardingCard(radius: CGFloat, selected: Bool) -> some View {
        background(.white, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(OnboardingTheme.paper.tileStroke))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: radius + 2, style: .continuous)
                        .strokeBorder(Palette.coral, lineWidth: 2)
                        .padding(-2)
                }
            }
    }
}
