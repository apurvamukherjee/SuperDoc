import AppKit
import SwiftUI

extension ClipItem.Kind {
    var title: String {
        switch self {
        case .text: String(localized: "Text")
        case .link: String(localized: "Links")
        case .color: String(localized: "Colors")
        case .image: String(localized: "Images")
        case .file: String(localized: "Files")
        }
    }

    /// Singular caption on notch cards: "TEXT · 2m".
    var caption: String {
        switch self {
        case .text: String(localized: "Text")
        case .link: String(localized: "Link")
        case .color: String(localized: "Color")
        case .image: String(localized: "Image")
        case .file: String(localized: "File")
        }
    }

    var symbol: String {
        switch self {
        case .text: "text.cursor"
        case .link: "link"
        case .color: "paintpalette"
        case .image: "photo"
        case .file: "doc"
        }
    }
}

/// Copied images, loaded once per file.
@MainActor
enum ClipImages {
    private static let cache = NSCache<NSString, NSImage>()

    #if DEBUG
    /// Gallery fixtures by `imageFile` name, so the gallery never touches the real history folder.
    static var fixtures: [String: NSImage] = [:]
    #endif

    static func image(for item: ClipItem) -> NSImage? {
        guard let file = item.imageFile else { return nil }
        #if DEBUG
        if let fixture = fixtures[file] { return fixture }
        #endif
        if let cached = cache.object(forKey: file as NSString) { return cached }
        guard let url = ClipboardStore.shared.imageURL(for: item), let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: file as NSString)
        return image
    }
}

/// The visual for one item: image thumbnail, colour swatch, or the type's symbol on a soft square.
struct ClipThumbnail: View {
    @Environment(\.tile) private var tile
    let item: ClipItem
    let size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
        switch item.kind {
        case .image:
            if let image = ClipImages.image(for: item) {
                Image(nsImage: image).resizable().scaledToFill().frame(width: size, height: size).clipShape(shape)
                    .accessibilityHidden(true)
            } else {
                SurfaceGlyph(symbol: "photo", size: size)
            }
        case .color:
            shape.fill(Color(hex: item.text ?? "") ?? .clear)
                .overlay(shape.strokeBorder(tile.surface.tileStroke, lineWidth: 1))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        case .link:
            SurfaceGlyph(symbol: "link", tint: Palette.progress, size: size)
        case .text, .file:
            SurfaceGlyph(symbol: item.kind.symbol, size: size)
        }
    }
}

extension ClipItem {
    /// One-line description for lists and VoiceOver.
    var summary: String {
        switch kind {
        case .image: String(localized: "Image")
        case .file:
            fileURLs.count == 1 ? fileURLs[0].lastPathComponent : String(localized: "\(fileURLs.count) files")
        case .text, .link, .color:
            (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        }
    }

    /// The app it was copied from, by name.
    @MainActor var sourceName: String? {
        guard let sourceApp, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: sourceApp) else { return nil }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    /// Second line in the history: "Terminal · now", "1440 × 900 · 9m".
    @MainActor func detail(now: Date) -> String {
        let age = Self.age(of: date, now: now)
        if kind == .image, let rep = ClipImages.image(for: self)?.representations.first {
            return "\(rep.pixelsWide) × \(rep.pixelsHigh) · \(age)"
        }
        return "\(sourceName ?? kind.caption) · \(age)"
    }

    /// Compact age: "now", "5m", "2h", "3d".
    static func age(of date: Date, now: Date) -> String {
        let seconds = max(now.timeIntervalSince(date), 0)
        return switch seconds {
        case ..<60: String(localized: "now")
        case ..<3600: String(localized: "\(Int(seconds / 60))m")
        case ..<86_400: String(localized: "\(Int(seconds / 3600))h")
        default: String(localized: "\(Int(seconds / 86_400))d")
        }
    }

    /// What a drag out of the notch shelf carries, so dropping it anywhere pastes the real thing.
    @MainActor var dragProvider: NSItemProvider {
        switch kind {
        case .file: fileURLs.first.flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
        case .image: ClipboardStore.shared.imageURL(for: self).flatMap { NSItemProvider(contentsOf: $0) } ?? NSItemProvider()
        case .text, .link, .color: NSItemProvider(object: (text ?? "") as NSString)
        }
    }
}

extension Color {
    /// "#RGB", "#RRGGBB" or "#RRGGBBAA".
    init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
        guard digits.count == 6 || digits.count == 8, let value = UInt64(digits, radix: 16) else { return nil }
        let hasAlpha = digits.count == 8
        let red = Double((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let green = Double((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let blue = Double((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let alpha = hasAlpha ? Double(value & 0xFF) / 255 : 1
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
