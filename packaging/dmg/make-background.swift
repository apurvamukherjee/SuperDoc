// Draws the DMG window background: an aurora gradient (matching the app's live wallpaper), the title, and an arrow
// from the app icon to Applications. Renders 1x and 2x PNGs; release.sh combines them into one HiDPI TIFF.
//
//   swift packaging/dmg/make-background.swift <output-folder>
import AppKit

let size = CGSize(width: 660, height: 420)
// Icon centres, top-left origin, matching packaging/dmg/settings.py.
let appIcon = CGPoint(x: 170, y: 215)
let applicationsIcon = CGPoint(x: 490, y: 215)

func render(scale: CGFloat) -> Data {
    let pixels = CGSize(width: size.width * scale, height: size.height * scale)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8,
                            bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: scale, y: scale)
    // Flip to top-left origin so coordinates match Finder's icon positions.
    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1, y: -1)

    func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    // Base: deep night gradient.
    let base = CGGradient(colorsSpace: space, colors: [color(0x0B0B1E), color(0x1A1240), color(0x0E2A3F)] as CFArray,
                          locations: [0, 0.55, 1])!
    context.drawLinearGradient(base, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

    // Aurora glows.
    func glow(_ center: CGPoint, radius: CGFloat, _ hex: UInt32, _ alpha: CGFloat) {
        let gradient = CGGradient(colorsSpace: space, colors: [color(hex, alpha), color(hex, 0)] as CFArray, locations: [0, 1])!
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }
    glow(CGPoint(x: 120, y: 60), radius: 320, 0x7B5CFF, 0.55)
    glow(CGPoint(x: 560, y: 90), radius: 280, 0x2EC5FF, 0.40)
    glow(CGPoint(x: 360, y: 430), radius: 360, 0xFF5CC8, 0.30)
    glow(CGPoint(x: 640, y: 400), radius: 260, 0x37E6A8, 0.25)

    // Faint stars.
    var generator = SplitMix(seed: 7)
    for _ in 0..<70 {
        let point = CGPoint(x: generator.next() * size.width, y: generator.next() * size.height * 0.75)
        let radius = 0.4 + generator.next() * 0.9
        context.setFillColor(color(0xFFFFFF, 0.15 + generator.next() * 0.45))
        context.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }

    // Frosted "dock" card behind the icons. Finder always draws icon labels in black, so the card is light
    // enough for them to stay readable.
    let shelf = CGRect(x: 60, y: 138, width: 540, height: 176)
    context.addPath(CGPath(roundedRect: shelf, cornerWidth: 30, cornerHeight: 30, transform: nil))
    context.setFillColor(color(0xF4F2FF, 0.82))
    context.fillPath()
    context.addPath(CGPath(roundedRect: shelf, cornerWidth: 30, cornerHeight: 30, transform: nil))
    context.setStrokeColor(color(0xFFFFFF, 0.9))
    context.setLineWidth(1)
    context.strokePath()

    // Arrow from the app to Applications.
    let start = CGPoint(x: appIcon.x + 78, y: appIcon.y)
    let end = CGPoint(x: applicationsIcon.x - 78, y: applicationsIcon.y)
    context.setStrokeColor(color(0x3B2F8F, 0.75))
    context.setLineWidth(3)
    context.setLineCap(.round)
    context.setLineDash(phase: 0, lengths: [2, 9])
    context.move(to: start)
    context.addLine(to: CGPoint(x: end.x - 6, y: end.y))
    context.strokePath()
    context.setLineDash(phase: 0, lengths: [])
    context.move(to: CGPoint(x: end.x - 16, y: end.y - 11))
    context.addLine(to: end)
    context.addLine(to: CGPoint(x: end.x - 16, y: end.y + 11))
    context.strokePath()

    // Text (drawn in a flipped context, so through NSGraphicsContext with flipped: true).
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    func text(_ string: String, size fontSize: CGFloat, weight: NSFont.Weight, alpha: CGFloat, y: CGFloat, tracking: CGFloat = 0) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: NSColor(white: 1, alpha: alpha),
            .paragraphStyle: style,
            .kern: tracking
        ]
        NSAttributedString(string: string, attributes: attributes)
            .draw(in: CGRect(x: 0, y: y, width: size.width, height: fontSize * 1.4))
    }
    text("SuperDock", size: 34, weight: .bold, alpha: 0.97, y: 46, tracking: -0.5)
    text("Drag SuperDock into Applications to install", size: 14, weight: .medium, alpha: 0.75, y: 96)
    text("FREE  ·  OPEN SOURCE  ·  macOS 14+", size: 10.5, weight: .semibold, alpha: 0.5, y: 372, tracking: 1.6)
    NSGraphicsContext.restoreGraphicsState()

    let image = context.makeImage()!
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

/// Small deterministic RNG so the stars are the same on every build.
struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> CGFloat {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return CGFloat((value ^ (value >> 31)) >> 11) / CGFloat(1 << 53)
    }
}

let folder = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
try render(scale: 1).write(to: folder.appending(path: "background.png"))
try render(scale: 2).write(to: folder.appending(path: "background@2x.png"))
print("wrote background.png and background@2x.png to \(folder.path)")
