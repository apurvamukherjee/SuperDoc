import CoreGraphics
import Observation
import ScreenCaptureKit
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "thumbnails")

/// Window thumbnails via ScreenCaptureKit. Only captures when a preview or the switcher is open,
/// and only with Screen Recording access; without it, cards show the app icon instead.
@MainActor @Observable
final class ThumbnailService {
    static let shared = ThumbnailService()

    private static let maxSide: CGFloat = 400
    private static let freshFor: TimeInterval = 2

    private(set) var images: [CGWindowID: CGImage] = [:]
    @ObservationIgnored private var capturedAt: [CGWindowID: Date] = [:]

    /// Captures the given windows in order, so the first cards fill in first.
    func load(_ ids: [CGWindowID]) async {
        guard CGPreflightScreenCaptureAccess() else { return }
        let stale = ids.filter { Date().timeIntervalSince(capturedAt[$0] ?? .distantPast) > Self.freshFor }
        guard !stale.isEmpty else { return }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            for id in stale {
                guard let window = content.windows.first(where: { $0.windowID == id }) else { continue }
                let config = SCStreamConfiguration()
                let scale = min(1, Self.maxSide / max(window.frame.width, window.frame.height, 1))
                config.width = max(Int(window.frame.width * scale * 2), 1)    // ×2 for Retina sharpness
                config.height = max(Int(window.frame.height * scale * 2), 1)
                config.showsCursor = false
                do {
                    let image = try await SCScreenshotManager.captureImage(
                        contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config
                    )
                    images[id] = image
                    capturedAt[id] = Date()
                } catch {
                    // Minimized windows can't be captured; the card keeps its icon.
                    log.debug("Capture of \(id) failed: \(error)")
                }
            }
        } catch {
            log.error("Couldn't list shareable windows: \(error)")
        }
    }
}
