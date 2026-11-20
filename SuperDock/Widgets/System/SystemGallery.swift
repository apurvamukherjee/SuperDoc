#if DEBUG
import SwiftUI

extension GallerySheets {
    /// System widgets.
    /// Compare with design/mockups/03-catalog-time-system-weather.png.
    static var system: AnyView? { AnyView(SystemSheet()) }
}

@MainActor
private enum Fixture {
    typealias Battery = SystemStatsService.Battery
    static let gib: UInt64 = 1_073_741_824
    static let calm = Samples.cpu.map { $0 / 100 }
    static let busy = [0.12, 0.15, 0.14, 0.16, 0.24, 0.27, 0.33, 0.42, 0.47, 0.55, 0.6, 0.64, 0.66, 0.7, 0.68, 0.75, 0.74, 0.77, 0.78]
    static let down = [6, 9, 7, 14, 11, 18, 15, 20, 16, 12, 17].map { $0 * 2.1e5 }
    static let upload = [3, 4, 3, 5, 4, 6, 5, 4, 5, 4, 4].map { $0 * 0.9e5 }
    static let clusters = SystemStatsService.CPUClusters(performance: 0.91, efficiency: 0.54)
    static func memory(_ pressure: SystemStatsService.MemoryPressure, used: Double = 11.2) -> SystemStatsService.Memory {
        .init(used: UInt64(used * Double(gib)), total: 16 * gib, pressure: pressure)
    }
    static let disk = SystemStatsService.Disk(available: 212_000_000_000, total: 494_000_000_000, purgeable: 24_000_000_000,
                                              name: "Macintosh HD")
    static let fullDisk = SystemStatsService.Disk(available: 18_400_000_000, total: 494_000_000_000, name: "Macintosh HD")
    static let charging = Battery(level: 0.76, isCharging: true, isOnPower: true, minutesToFull: 70)
    static let low = Battery(level: 0.12, isCharging: false, isOnPower: false, minutesRemaining: 24)
    static let draining = Battery(level: 0.64, isCharging: false, isOnPower: false, minutesRemaining: 252)
    static let charged = Battery(level: 1, isCharging: false, isOnPower: true)
    static let boot = Samples.now.addingTimeInterval(-(3 * 86_400 + 4 * 3600 + 13 * 60))
}

private struct SystemSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            heading("System · 7 widgets · one shared sampler", size: 34)
            ForEach([SurfaceStyle.glassDark, .solidLight, .paper], id: \.self) { SystemPanel(style: $0) }
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    heading("56 pt tight · 120 pt roomy", size: 17)
                    ForEach([44, 108] as [CGFloat], id: \.self) { unit in
                        GalleryBar(surface: SurfaceTokens(.glassDark)) { SystemRows.main(SystemRows.context(.glassDark, unit: unit)) }
                    }
                    GalleryBar(surface: SurfaceTokens(.glassDark)) { SystemRows.second(SystemRows.context(.glassDark, unit: 44)) }
                }
                VStack(alignment: .leading, spacing: 14) {
                    heading("Portrait (vertical bar)", size: 17)
                    GalleryBar(surface: SurfaceTokens(.glassDark)) { SystemRows.portraits(.glassDark) }
                }
            }
            .padding(28)
            .background(galleryWallpaper(.glassDark))
        }
        .padding(40)
        .background(Palette.inkDeep)
    }

    private func heading(_ text: String, size: CGFloat) -> some View {
        Text(text).font(.system(size: size, weight: .bold)).foregroundStyle(.white)
    }
}

private struct SystemPanel: View {
    let style: SurfaceStyle

    var body: some View {
        let ink = style.isDark ? Color.white : Palette.ink
        let context = { (size: TileSize) in SystemRows.context(style, unit: 73)(size) }
        VStack(alignment: .leading, spacing: 12) {
            Text(style.rawValue).font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
            note("CPU C · M · W (under load) — Memory C · M — Network C · M", ink)
            GalleryBar(surface: SurfaceTokens(style)) { SystemRows.main(context) }
            note("Disk C · M — Battery C · M · low · desktop — Uptime C · M — Thermal cool · warm · hot · critical", ink)
            HStack(alignment: .top, spacing: 16) {
                GalleryBar(surface: SurfaceTokens(style)) { SystemRows.second(context) }
                GalleryBar(surface: SurfaceTokens(style)) { SystemRows.thermal(context) }
            }
            note("States — loading · memory high / critical · disk low · battery low / draining / charged / desktop M", ink)
            GalleryBar(surface: SurfaceTokens(style)) { SystemRows.states(context) }
        }
        .padding(28)
        .background(galleryWallpaper(style))
    }

    private func note(_ text: String, _ ink: Color) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(ink.opacity(0.6))
    }
}

@MainActor
private enum SystemRows {
    static func context(_ style: SurfaceStyle, unit: CGFloat) -> (TileSize) -> TileContext {
        { size in TileContext(unit: unit, size: size, surface: SurfaceTokens(style)) }
    }

    @ViewBuilder static func main(_ context: (TileSize) -> TileContext) -> some View {
        CPUTileView(usage: 0.23, history: Fixture.calm).asTile(context(.compact))
        CPUTileView(usage: 0.23, history: Fixture.calm).asTile(context(.medium))
        CPUTileView(usage: 0.78, history: Fixture.busy, clusters: Fixture.clusters).asTile(context(.wide))
        MemoryTileView(memory: Fixture.memory(.normal)).asTile(context(.compact))
        MemoryTileView(memory: Fixture.memory(.normal)).asTile(context(.medium))
        NetworkTileView(download: 4_200_000, upload: 380_000, downloadHistory: Fixture.down, uploadHistory: Fixture.upload)
            .asTile(context(.compact))
        NetworkTileView(download: 4_200_000, upload: 380_000, downloadHistory: Fixture.down, uploadHistory: Fixture.upload)
            .asTile(context(.medium))
    }

    @ViewBuilder static func second(_ context: (TileSize) -> TileContext) -> some View {
        DiskTileView(disk: Fixture.disk).asTile(context(.compact))
        DiskTileView(disk: Fixture.disk).asTile(context(.medium))
        BatteryTileView(battery: Fixture.charging).asTile(context(.compact))
        BatteryTileView(battery: Fixture.charging).asTile(context(.medium))
        BatteryTileView(battery: Fixture.low).asTile(context(.compact))
        BatteryTileView(battery: nil).asTile(context(.compact))
        UptimeTileView(boot: Fixture.boot, now: Samples.now).asTile(context(.compact))
        UptimeTileView(boot: Fixture.boot, now: Samples.now).asTile(context(.medium))
    }

    @ViewBuilder static func thermal(_ context: @escaping (TileSize) -> TileContext) -> some View {
        ForEach([ProcessInfo.ThermalState.nominal, .fair, .serious, .critical], id: \.self) {
            ThermalTileView(state: $0).asTile(context(.compact))
        }
    }

    @ViewBuilder static func states(_ context: (TileSize) -> TileContext) -> some View {
        CPUTileView(usage: nil, history: []).asTile(context(.compact))
        NetworkTileView(download: nil, upload: nil, downloadHistory: [], uploadHistory: []).asTile(context(.medium))
        MemoryTileView(memory: Fixture.memory(.critical, used: 15.1)).asTile(context(.compact))
        MemoryTileView(memory: Fixture.memory(.warning, used: 13.6)).asTile(context(.medium))
        DiskTileView(disk: Fixture.fullDisk).asTile(context(.compact))
        DiskTileView(disk: Fixture.fullDisk).asTile(context(.medium))
        BatteryTileView(battery: Fixture.low).asTile(context(.medium))
        BatteryTileView(battery: Fixture.draining).asTile(context(.compact))
        BatteryTileView(battery: Fixture.charged).asTile(context(.medium))
        BatteryTileView(battery: nil).asTile(context(.medium))
        CPUTileView(usage: 0.97, history: Fixture.busy.map { min($0 + 0.2, 1) }).asTile(context(.medium))
    }

    @ViewBuilder static func portraits(_ style: SurfaceStyle) -> some View {
        let context = TileContext(size: .medium, isPortrait: true, surface: SurfaceTokens(style))
        CPUTileView(usage: 0.23, history: Fixture.calm).asTile(context)
        MemoryTileView(memory: Fixture.memory(.normal)).asTile(context)
        NetworkTileView(download: 4_200_000, upload: 380_000, downloadHistory: Fixture.down, uploadHistory: Fixture.upload).asTile(context)
        DiskTileView(disk: Fixture.disk).asTile(context)
        BatteryTileView(battery: Fixture.charging).asTile(context)
        UptimeTileView(boot: Fixture.boot, now: Samples.now).asTile(context)
    }
}
#endif
