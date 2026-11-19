import Sparkle
import SwiftUI

/// Sparkle updates, active only in builds that carry a signing key (release builds from scripts/release.sh).
/// Without a key Sparkle would refuse every update anyway, so the updater isn't started and never contacts the feed.
@MainActor
final class Updates {
    static let shared = Updates()

    static var isConfigured: Bool {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        return !key.isEmpty && !key.hasPrefix("$(")
    }

    let controller = SPUStandardUpdaterController(startingUpdater: Updates.isConfigured, updaterDelegate: nil, userDriverDelegate: nil)

    func checkForUpdates() {
        NSApp.activate()
        controller.checkForUpdates(nil)
    }
}

struct CheckForUpdatesButton: View {
    var body: some View {
        Button("Check for Updates…") { Updates.shared.checkForUpdates() }
            .disabled(!Updates.isConfigured)
    }
}
