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
}
