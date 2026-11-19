import AppKit
import SwiftUI

/// First-run flow (SUPERDOCK.md §7.14): welcome → choose placement → grant Accessibility → pick starter widgets.
@MainActor
enum Onboarding {
    static let doneKey = "onboarding.done"

    private static var window: NSWindow?

    static var isNeeded: Bool { !UserDefaults.standard.bool(forKey: doneKey) }

    static func show() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView { finish() }))
        window.title = String(localized: "Welcome to SuperDock")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private static func finish() {
        UserDefaults.standard.set(true, forKey: doneKey)
        window?.close()
        window = nil
    }
}

private struct OnboardingView: View {
    enum Step: Int, CaseIterable { case welcome, placement, accessibility, widgets }

    let onFinish: () -> Void
    @State private var step = Step.welcome
    @State private var trusted = AXIsProcessTrusted()
    @State private var chosen: Set<String> = ["time.clock", "time.date", "system.cpu", "system.battery", "ai.limits"]
    @AppStorage(BarPrefs.positionKey) private var position = BarPrefs.defaultPosition

    private static let starters = ["time.clock", "time.date", "weather.current", "system.cpu", "system.memory",
                                   "system.battery", "ai.limits", "ai.agents", "media.nowPlaying", "productivity.pomodoro"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                switch step {
                case .welcome: welcome
                case .placement: placement
                case .accessibility: accessibility
                case .widgets: widgets
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            HStack {
                Text("Step \(step.rawValue + 1) of \(Step.allCases.count)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if step != .welcome { Button("Back") { step = Step(rawValue: step.rawValue - 1) ?? .welcome } }
                Button(step == .widgets ? "Done" : "Continue", action: next)
                    .keyboardShortcut(.defaultAction)
                    .disabled(step == .accessibility && !trusted)
            }
        }
        .padding(24)
        .frame(width: 480)
        .task(id: step) {
            // While on the Accessibility step, notice the grant without the user having to come back and click.
            while step == .accessibility, !trusted {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                trusted = AXIsProcessTrusted()
            }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "dock.rectangle").font(.system(size: 40)).accessibilityHidden(true)
            Text("SuperDock").font(.largeTitle.bold())
            Text("A bar of live widgets right next to your Dock: AI usage limits, coding agents, system stats, weather, "
                 + "a window switcher, clipboard history and more. Everything is free, and nothing leaves your Mac "
                 + "except the widgets you add that need the internet.")
        }
    }

    private var placement: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Where should the bar go?").font(.title2.bold())
            Picker("Position", selection: $position) {
                Text("Right of the Dock").tag(BarPosition.trailing)
                Text("Left of the Dock").tag(BarPosition.leading)
                Text("Above the Dock").tag(BarPosition.outside)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            Text("You can change this, or replace the Dock entirely, in Settings → Placement.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var accessibility: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Allow Accessibility access").font(.title2.bold())
            Text("SuperDock reads the Dock's position and size so the bar can sit next to it. The window switcher and "
                 + "Dock previews use the same access to list and focus windows.")
            if trusted {
                Label("Access granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("Open Accessibility Settings") {
                    // String key: the kAXTrustedCheckOptionPrompt global isn't concurrency-safe under Swift 6.
                    AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
                }
                Text("Turn on SuperDock in Privacy & Security → Accessibility. This page continues by itself once it's on.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var widgets: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pick some starter widgets").font(.title2.bold())
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)]) {
                ForEach(Self.starters, id: \.self) { id in
                    if let widget = WidgetRegistry.widget(id) {
                        Toggle(isOn: Binding(get: { chosen.contains(id) }, set: { isOn in
                            if isOn { chosen.insert(id) } else { chosen.remove(id) }
                        })) { Label(widget.name, systemImage: widget.symbol) }
                    }
                }
            }
            Text("Add, remove and resize widgets any time: right-click a tile, or Settings → Widgets.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func next() {
        guard let following = Step(rawValue: step.rawValue + 1) else {
            // Keep the picker's order, compact tiles so the starter bar fits beside the Dock.
            LayoutStore.shared.tiles = Self.starters.filter(chosen.contains).map { Tile(widgetId: $0, size: .compact) }
            onFinish()
            return
        }
        step = following
    }
}
