import SwiftUI

struct CPUWidget: SuperWidget {
    typealias Settings = NoSettings

    static let id = "system.cpu"
    static var name: String { String(localized: "CPU") }
    static let category = WidgetCategory.system
    static let symbol = "cpu"
    static let supportedSizes: [TileSize] = [.compact, .medium, .wide]

    static func view(size: TileSize, settings: Settings) -> some View {
        CPUTile()
    }
}

private struct CPUTile: View {
    private let stats = SystemStatsService.shared

    var body: some View {
        CPUTileView(usage: stats.cpuUsage, history: stats.cpuHistory, clusters: stats.cpuClusters)
            .subscribes(to: .cpu)
    }
}

/// 4 · Chart: CPU load as an area whose colour follows the load at each moment.
struct CPUTileView: View {
    @Environment(\.tile) private var tile
    var usage: Double?
    var history: [Double]
    var clusters: SystemStatsService.CPUClusters?

    var body: some View {
        if let usage {
            let value = SystemFormat.percent(usage)
            SystemChartLayout {
                if tile.isCompact || tile.isPortrait {
                    if tile.showsLabel { Text("CPU").tileStyle(.label) }
                    Text(value).tileStyle(tile.isPortrait ? .hero : .heroCompact, color: LoadColor.text(usage, tile.surface))
                        .padding(.top, tile.isPortrait ? 16 * tile.scale : 0)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8 * tile.scale) {
                        Text("CPU").tileStyle(.label).fixedSize()
                        if let clusters, tile.size == .wide {
                            let split = "P \(SystemFormat.percent(clusters.performance)) · E \(SystemFormat.percent(clusters.efficiency))"
                            Text(split).tileStyle(.detail)
                        }
                        Spacer(minLength: 0)
                        Text(value).tileStyle(.heroCompact, color: LoadColor.text(usage, tile.surface))
                    }
                }
            } chart: {
                LoadAreaChart(values: history)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("CPU")
            .accessibilityValue(value)
        } else {
            TileStateView(state: .loading)
        }
    }
}

/// Header on top, chart bleeding off the bottom edge: the Chart archetype's layout with a free-form header, because
/// CPU (core split at W) and Network (legend at M) need headers `ChartTile` doesn't offer at those sizes.
struct SystemChartLayout<Header: View, Chart: View>: View {
    @Environment(\.tile) private var tile
    @ViewBuilder var header: Header
    @ViewBuilder var chart: Chart

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.top, tile.isCompact || tile.isPortrait ? 0 : 2 * tile.scale)
            Spacer(minLength: 2 * tile.scale)
            chart
                .frame(height: tile.contentSize.height * (tile.isPortrait ? 0.32 : tile.isCompact ? 0.42 : 0.55))
                .tileBleed()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Calm blue under half load, warming to amber and then coral as the machine works harder.
enum LoadColor {
    private static let stops: [(load: Double, rgb: SIMD3<Double>)] = [
        (0.5, [0x5A, 0xA2, 0xFF]), (0.75, [0xFF, 0xAA, 0x40]), (0.95, [0xFF, 0x5A, 0x4E])
    ]

    static func chart(_ load: Double) -> Color {
        let upper = stops.firstIndex { load <= $0.load } ?? stops.count - 1
        guard upper > 0 else { return rgb(stops[0].rgb) }
        let (low, high) = (stops[upper - 1], stops[upper])
        let mix = ((load - low.load) / (high.load - low.load)).unitClamped
        return rgb(low.rgb + (high.rgb - low.rgb) * mix)
    }

    /// The hero stays primary at rest and takes a text-safe warm colour under load.
    static func text(_ load: Double, _ surface: SurfaceTokens) -> Color {
        load >= 0.85 ? surface.danger : load >= 0.5 ? surface.warning : surface.primary
    }

    private static func rgb(_ value: SIMD3<Double>) -> Color {
        Color(.sRGB, red: value.x / 255, green: value.y / 255, blue: value.z / 255)
    }
}

/// `AreaChart` with a horizontal gradient: each sample is coloured by its own load.
struct LoadAreaChart: View {
    var values: [Double]

    var body: some View {
        // A floor on the scale keeps idle noise (2–5 %) from filling the chart.
        let top = max((values.max() ?? 0) * 1.15, 0.25)
        Canvas { context, size in
            guard values.count > 1 else { return }
            let step = size.width / CGFloat(values.count - 1)
            let points = values.enumerated().map { index, value in
                CGPoint(x: CGFloat(index) * step, y: size.height * (1 - CGFloat(value / top)))
            }
            let gradient = Gradient(stops: values.enumerated().map { index, value in
                .init(color: LoadColor.chart(value), location: CGFloat(index) / CGFloat(values.count - 1))
            })
            let shading = GraphicsContext.Shading.linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0))
            var stroke = Path()
            stroke.addLines(points)
            var area = stroke
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.addLine(to: CGPoint(x: 0, y: size.height))
            area.closeSubpath()
            context.drawLayer { layer in
                layer.opacity = 0.42
                layer.fill(area, with: shading)
            }
            context.stroke(stroke, with: shading, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
