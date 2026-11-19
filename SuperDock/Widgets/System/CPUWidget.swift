import SwiftUI

struct CPUWidget: SuperWidget {
    typealias Settings = NoSettings

    static let id = "system.cpu"
    static var name: String { String(localized: "CPU") }
    static let category = WidgetCategory.system
    static let symbol = "cpu"
    static let supportedSizes: [TileSize] = [.compact, .medium, .wide]

    static func view(size: TileSize, settings: Settings) -> some View {
        CPUTile(size: size)
    }
}

private struct CPUTile: View {
    let size: TileSize
    private let stats = SystemStatsService.shared

    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 2) {
                Text("CPU").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(stats.cpuUsage.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "–")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            .tileText()
            if size != .compact {
                Sparkline(values: stats.cpuHistory)
                    .stroke(.tint, lineWidth: 1.5)
                    .accessibilityHidden(true)
            }
        }
        .subscribes(to: .cpu)
    }
}

/// Line through values in 0...1, oldest on the left.
private struct Sparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        Path { path in
            guard values.count > 1 else { return }
            let step = rect.width / CGFloat(values.count - 1)
            for (index, value) in values.enumerated() {
                let point = CGPoint(x: rect.minX + CGFloat(index) * step, y: rect.maxY - CGFloat(value) * rect.height)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
        }
    }
}
