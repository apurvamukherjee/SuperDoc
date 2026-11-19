import AppKit
import SwiftUI

@MainActor
enum Permissions {
    static var hasScreenRecording: Bool { CGPreflightScreenCaptureAccess() }

    /// Explains first (hard rule 7), then asks. Returns whether access is granted now.
    /// macOS only shows its own prompt once; after that, the user has to flip the switch in System Settings.
    static func requestScreenRecording() -> Bool {
        guard !hasScreenRecording else { return true }
        let alert = NSAlert()
        alert.messageText = String(localized: "Window previews need Screen Recording access")
        alert.informativeText = String(localized: """
            SuperDock captures small thumbnails of your windows only while a preview or the window switcher is open. \
            Nothing is saved or sent anywhere. Without access, previews show app icons and window titles from \
            the current Space only.
            """)
        alert.addButton(withTitle: String(localized: "Continue"))
        alert.addButton(withTitle: String(localized: "Not Now"))
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        if CGRequestScreenCaptureAccess() { return true }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        return false
    }

    /// Explains why first (hard rule 7); the system prompt only appears after the user clicks Continue.
    static func showAccessibilityOnboardingIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let window = NSWindow(contentViewController: NSHostingController(rootView: AccessibilityOnboarding()))
        window.title = String(localized: "Welcome to SuperDock")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)

        // The tracker picks up the grant on its own; this only closes the window once it's no longer needed.
        Task { @MainActor in
            while !AXIsProcessTrusted() {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return   // Task.sleep only throws on cancellation
                }
            }
            window.close()
        }
    }
}

private struct AccessibilityOnboarding: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SuperDock needs Accessibility access").font(.title2.bold())
            Text("SuperDock reads the Dock's position and size so the bar can sit right next to it.")
            Text("""
                Click Continue, then turn on SuperDock in System Settings → Privacy & Security → Accessibility. \
                This window closes by itself once access is granted.
                """)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Continue") {
                    // String key because the kAXTrustedCheckOptionPrompt global isn't concurrency-safe under Swift 6.
                    AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
