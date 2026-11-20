import AppKit
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome, placement, accessibility, starter
}

/// Paper theme: the app icon's cream and ink. Measured off the mockup (a 380 × 600 pt window).
enum OnboardingTheme {
    static let windowSize = CGSize(width: 380, height: 600)
    static let paper = SurfaceTokens(.paper)
    static let ink = Palette.inkDeep
    static let label = paper.secondary
    static let body = Palette.ink.opacity(0.74)
    static let pill = Color(rgb: 0xD9D5CB)
    static let margin: CGFloat = 26
    /// Height of the art band above the text (the dark "live preview" panel on steps 2 and 4).
    static let heroHeight: CGFloat = 250
}

/// One starter bar. Sizes are the preferred ones; `tiles()` falls back to a size the widget supports.
enum StarterSet: String, CaseIterable, Identifiable {
    case developer, everyday, justMe

    struct Item {
        let widgetId: String
        let size: TileSize
        /// The tile's colour in the step-4 preview bar.
        let tint: Color
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .developer: String(localized: "Developer")
        case .everyday: String(localized: "Everyday")
        case .justMe: String(localized: "Just me")
        }
    }

    var subtitle: String {
        switch self {
        case .developer: String(localized: "AI Limits, Coding Agents, Git, CPU")
        case .everyday: String(localized: "Clock, Weather, Now Playing, Calendar")
        case .justMe: String(localized: "Start empty. Limo will keep you company.")
        }
    }

    var items: [Item] {
        switch self {
        case .developer: [
            Item(widgetId: "ai.limits", size: .medium, tint: Color(rgb: 0x947751)),
            Item(widgetId: "ai.agents", size: .medium, tint: Color(rgb: 0x3263BA)),
            Item(widgetId: "dev.gitStatus", size: .medium, tint: Color(rgb: 0x2E8583)),
            Item(widgetId: "system.cpu", size: .compact, tint: Color(rgb: 0x595BBB))
        ]
        case .everyday: [
            Item(widgetId: "time.clock", size: .compact, tint: Color(rgb: 0x565B70)),
            Item(widgetId: "weather.current", size: .compact, tint: Color(rgb: 0x3263BA)),
            Item(widgetId: "media.nowPlaying", size: .medium, tint: Color(rgb: 0x8A4C82)),
            Item(widgetId: "time.date", size: .compact, tint: Color(rgb: 0xA8574A))
        ]
        case .justMe: []
        }
    }

    @MainActor func tiles() -> [Tile] {
        items.compactMap { item in
            guard let sizes = WidgetRegistry.widget(item.widgetId)?.supportedSizes,
                  let size = sizes.contains(item.size) ? item.size : sizes.first else { return nil }
            return Tile(widgetId: item.widgetId, size: size)
        }
    }
}

struct OnboardingView: View {
    var still = false
    let onFinish: (StarterSet) -> Void
    /// Set when only the Accessibility step is shown (the grant was lost after onboarding, e.g. by an update that
    /// changed the app's signature); called once access is back instead of moving on to the starter set.
    var onAccessGranted: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: OnboardingStep
    @State private var position: BarPosition
    @State private var starter: StarterSet
    @State private var trusted: Bool
    /// OnboardingSpinner turns, bumped by the Accessibility poll so the spinner adds no timer of its own.
    @State private var spins = 0
    @State private var entered: Bool
    @State private var celebrating = false

    /// `still` renders a settled frame (gallery): no entrance, no poll, drawn window chrome.
    init(step: OnboardingStep = .welcome, position: BarPosition = BarPrefs.position, starter: StarterSet = .developer,
         trusted: Bool = AXIsProcessTrusted(), still: Bool = false, onAccessGranted: (() -> Void)? = nil,
         onFinish: @escaping (StarterSet) -> Void) {
        _step = State(initialValue: step)
        _position = State(initialValue: position)
        _starter = State(initialValue: starter)
        _trusted = State(initialValue: trusted)
        _entered = State(initialValue: still)
        self.still = still
        self.onAccessGranted = onAccessGranted
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack(alignment: .top) {
            background
            stepView
                .id(step)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(x: 18)))
            footer.frame(maxHeight: .infinity, alignment: .bottom)
            if still { TrafficLights() }
        }
        .frame(width: OnboardingTheme.windowSize.width, height: OnboardingTheme.windowSize.height)
        .clipped()
        .ignoresSafeArea()
        .environment(\.colorScheme, .light)
        .onAppear(perform: enter)
        .task(id: step) { await watchAccessibility() }
    }

    private var background: some View {
        LinearGradient(stops: [.init(color: Color(rgb: 0xF2EDE2), location: 0),
                               .init(color: Palette.cream, location: 0.42)],
                       startPoint: .top, endPoint: .bottom)
    }

    @ViewBuilder private var stepView: some View {
        switch step {
        case .welcome: OnboardingWelcomeStep(entered: entered)
        case .placement: OnboardingPlacementStep(position: position, select: select)
        case .accessibility:
            OnboardingAccessibilityStep(trusted: trusted, spins: spins, standalone: onAccessGranted != nil)
        case .starter: OnboardingStarterStep(starter: $starter, celebrating: celebrating)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if onAccessGranted == nil { PageDots(current: step.rawValue, count: OnboardingStep.allCases.count) }
            Spacer()
            if step == .placement {
                Button(String(localized: "Back")) { go(to: .welcome) }
                    .buttonStyle(.plain)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(OnboardingTheme.body)
                    .padding(.horizontal, 10)
                    .frame(height: 40)
                    .contentShape(Rectangle())
            }
            primaryButton
        }
        .padding(.horizontal, OnboardingTheme.margin)
        .padding(.bottom, 21.5)
    }

    private var primaryButton: some View {
        let (title, action): (String, () -> Void) = switch step {
        case .welcome: (String(localized: "Get started"), { go(to: .placement) })
        case .placement: (String(localized: "Continue"), { go(to: .accessibility) })
        case .accessibility where trusted: (String(localized: "Continue"), afterAccess)
        case .accessibility: (String(localized: "Open System Settings"), openAccessibilitySettings)
        case .starter: (String(localized: "Finish"), finish)
        }
        return Button(title, action: action)
            .buttonStyle(PaperButtonStyle(fill: step == .starter ? Palette.coral : OnboardingTheme.ink))
            .keyboardShortcut(.defaultAction)
            .disabled(celebrating)
    }

    private func animation(_ spring: Animation) -> Animation { reduceMotion ? Motion.reduced : spring }

    private func go(to next: OnboardingStep) {
        withAnimation(animation(Motion.settle)) { step = next }
    }

    private func enter() {
        guard !entered else { return }
        withAnimation(animation(Motion.pop)) { entered = true }
    }

    private func select(_ choice: BarPosition) {
        withAnimation(animation(Motion.settle)) { position = choice }
        // BarController listens for defaults changes, so the real bar moves too once it's on screen.
        UserDefaults.standard.set(choice.rawValue, forKey: BarPrefs.positionKey)
    }

    private func openAccessibilitySettings() {
        // The prompt option is what adds SuperDock to the Accessibility list; without it the pane can open with
        // nothing to switch on. The key is spelled out because the kAX constant isn't concurrency-safe in Swift 6.
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    private func afterAccess() {
        if let onAccessGranted { onAccessGranted() } else { go(to: .starter) }
    }

    private func finish() {
        withAnimation(animation(Motion.pop)) { celebrating = true }
        onFinish(starter)
    }

    /// The only loop in onboarding: once a second, and only while the Accessibility step is showing.
    private func watchAccessibility() async {
        guard step == .accessibility, !still else { return }
        do {
            while !trusted {
                spins += 1
                try await Task.sleep(for: .seconds(1))
                if AXIsProcessTrusted() { withAnimation(animation(Motion.pop)) { trusted = true } }
            }
            // Long enough to see the check and Limo pocket the key.
            try await Task.sleep(for: .seconds(1.2))
            afterAccess()
        } catch {
            return   // Task.sleep only throws on cancellation: the step changed or the window closed.
        }
    }
}

private struct PageDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? OnboardingTheme.ink : Palette.ink.opacity(0.2))
                    .frame(width: index == current ? 18 : 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Step \(current + 1) of \(count)"))
    }
}

private struct PaperButtonStyle: ButtonStyle {
    var fill = OnboardingTheme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(height: 40)
            .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// Drawn window buttons for the offscreen gallery; the real window has AppKit's.
private struct TrafficLights: View {
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { _ in Circle().fill(Palette.ink.opacity(0.2)).frame(width: 11, height: 11) }
        }
        .padding(.leading, 18)
        .padding(.top, 16.5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
