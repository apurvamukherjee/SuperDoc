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

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "link"
        case .color: "paintpalette"
        case .image: "photo"
        case .file: "doc"
        }
    }
}

/// The visual for one item: image thumbnail, color swatch, file icon, or a symbol.
struct ClipThumbnail: View {
    let item: ClipItem
    let size: CGFloat

    var body: some View {
        Group {
            switch item.kind {
            case .image:
                if let url = ClipboardStore.shared.imageURL(for: item), let image = NSImage(contentsOf: url) {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            case .color:
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: item.text ?? "") ?? .clear)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.quaternary))
            case .file:
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.fileURLs.first?.path ?? "/")).resizable().scaledToFit()
            case .text, .link:
                Image(systemName: item.kind.symbol).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .accessibilityHidden(true)
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
