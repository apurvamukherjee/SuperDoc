#if DEBUG
import SwiftUI

extension GallerySheets {
    /// The bar: styles, scale, vertical, app strip, drag, empty bar. Every bar here is the live `BarLayout`, fed a
    /// context from `TileContext.bar` (the same call `WidgetHost` makes) and the real widget views on fixture data.
    /// Compare with design/mockups/01-bar-styles-scale-interactions.png.
    static var bar: AnyView? { AnyView(BarSheet()) }
}

@MainActor
private enum BarFixture {
    static func item(_ size: TileSize, _ name: String, _ view: some View) -> BarItem {
        BarItem(id: UUID(), size: size, name: name, supportedSizes: TileSize.allCases, view: AnyView(view))
    }

    static var limits: BarItem { item(.medium, "AI Limits", AILimitsView(content: .limits(AISamples.limits))) }
    static var agents: BarItem { item(.medium, "Coding Agents", AgentsBoardView(agents: AISamples.six, now: AISamples.now)) }
    /// US English like the Time sheet, so the clock reads "Thu 19" as in the mockup whatever this Mac's region is.
    static let calendar = {
        var calendar = Samples.calendar
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()
    static var clock: BarItem { item(.compact, "Clock", ClockWidgetView(date: Samples.now, calendar: calendar)) }
    static var cpu: BarItem { item(.compact, "CPU", CPUTileView(usage: 0.23, history: Samples.cpu.map { $0 / 100 })) }

    static func weather(_ size: TileSize) -> BarItem {
        item(size, "Weather", CurrentWeatherView(report: WeatherSamples.lisbon, city: "Lisbon", now: WeatherSamples.night))
    }

    static var hero: [BarItem] { [limits, agents, clock] }

    static let apps: [AppStrip.Item] = [
        ("/System/Library/CoreServices/Finder.app", true), ("/Applications/Safari.app", true),
        ("/System/Applications/Utilities/Terminal.app", true), ("/System/Applications/Notes.app", false),
        ("/System/Applications/Messages.app", true)
    ].map { AppStrip.Item(url: URL(fileURLWithPath: $0.0), isRunning: $0.1, isPinned: true) }

    static func context(_ style: BarStyle, dark: Bool, reduceTransparency: Bool = false, thickness: CGFloat = 85,
                        vertical: Bool = false) -> TileContext {
        .bar(surface: .bar(style, isDark: dark, reduceTransparency: reduceTransparency, tileBackgrounds: true),
             accent: Palette.progress, cornerRadius: AppearancePrefs.defaultCornerRadius, thickness: thickness,
             isVertical: vertical)
    }
}

/// The real bar layout over the kit's approximation of its AppKit background.
private struct GallerySampleBar: View {
    let context: TileContext
    let items: [BarItem]
    var appStrip: [AppStrip.Item]?
    var drag: BarDrag?

    var body: some View {
        BarLayout(context: context, items: items, appStrip: appStrip, drag: drag)
            .fixedSize()
            .background(BarBackdrop(surface: context.surface, radius: context.radius + 6))
    }
}

private struct Panel<Content: View>: View {
    let title: String
    let wallpaper: SurfaceStyle
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
            content
        }
        .padding(18)
        .background(galleryWallpaper(wallpaper), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct Heading: View {
    let title: String
    let note: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.system(size: 24, weight: .bold))
            Text(note).font(.system(size: 13)).opacity(0.6)
        }
        .foregroundStyle(Palette.ink)
    }
}

private struct StylePanel {
    let title: String
    let style: BarStyle
    let dark: Bool
    var reduceTransparency = false
    let wallpaper: SurfaceStyle
}

private struct BarSheet: View {
    private let styles = [
        StylePanel(title: "Liquid Glass · dark", style: .glass, dark: true, wallpaper: .glassDark),
        StylePanel(title: "Liquid Glass · light", style: .glass, dark: false, wallpaper: .glassLight),
        StylePanel(title: "Frosted · dark", style: .frosted, dark: true, wallpaper: .frostedDark),
        StylePanel(title: "Frosted · light", style: .frosted, dark: false, wallpaper: .frostedLight),
        StylePanel(title: "Solid dark", style: .dark, dark: true, wallpaper: .solidDark),
        StylePanel(title: "Solid light", style: .light, dark: false, wallpaper: .solidLight),
        StylePanel(title: "Paper", style: .paper, dark: false, wallpaper: .paper),
        StylePanel(title: "Reduce Transparency → solid", style: .glass, dark: false, reduceTransparency: true,
                   wallpaper: .glassLight)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            Text("The bar · styles, scale, orientation & interactions").font(.system(size: 36, weight: .bold))
                .foregroundStyle(Palette.ink)
            HStack(alignment: .top, spacing: 36) {
                VStack(alignment: .leading, spacing: 36) {
                    stylesSection
                    scaleSection
                    dockSection
                }
                VStack(alignment: .leading, spacing: 36) {
                    verticalSection
                    dragSection
                    emptySection
                }
            }
        }
        .padding(60)
        .background(Palette.cream)
    }

    private var stylesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Heading(title: "4 styles × light/dark", note: "+ Paper and Reduce Transparency. Tiles read only surface tokens.")
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                ForEach(0..<4, id: \.self) { line in
                    GridRow {
                        ForEach(styles.dropFirst(line * 2).prefix(2), id: \.title) { panel in
                            Panel(title: panel.title, wallpaper: panel.wallpaper) {
                                GallerySampleBar(context: BarFixture.context(panel.style, dark: panel.dark,
                                                                             reduceTransparency: panel.reduceTransparency),
                                                 items: BarFixture.hero)
                            }
                        }
                    }
                }
            }
        }
    }

    private var scaleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Heading(title: "Scale: 56 · 85 · 120 pt", note: "Same tiles; tight drops labels, roomy adds detail.")
            Panel(title: "Liquid Glass · dark", wallpaper: .glassDark) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach([56, 85, 120], id: \.self) { thickness in
                        GallerySampleBar(context: BarFixture.context(.glass, dark: true, thickness: CGFloat(thickness)),
                                         items: [BarFixture.limits, BarFixture.agents, BarFixture.clock, BarFixture.weather(.compact)])
                    }
                }
            }
        }
    }

    private var dockSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Heading(title: "Dock replacement mode", note: "App strip at the Dock's icon size (56 pt), running dots, divider, tiles.")
            Panel(title: "Liquid Glass · dark", wallpaper: .glassDark) {
                GallerySampleBar(context: BarFixture.context(.glass, dark: true, thickness: 56 + 2 * TileContext.spacing),
                                 items: [BarFixture.limits, BarFixture.clock], appStrip: BarFixture.apps)
            }
            Panel(title: "Solid light", wallpaper: .solidLight) {
                GallerySampleBar(context: BarFixture.context(.light, dark: false, thickness: 56 + 2 * TileContext.spacing),
                                 items: [BarFixture.limits, BarFixture.clock], appStrip: BarFixture.apps)
            }
        }
    }

    private var verticalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Heading(title: "Vertical, beside a left Dock", note: "Portrait tiles.")
            Panel(title: "Liquid Glass · dark", wallpaper: .glassDark) {
                GallerySampleBar(context: BarFixture.context(.glass, dark: true, vertical: true),
                                 items: [BarFixture.limits, BarFixture.agents, BarFixture.clock, BarFixture.weather(.compact),
                                         BarFixture.cpu])
            }
        }
    }

    private var dragSection: some View {
        let lifted = [BarFixture.clock, BarFixture.weather(.medium), BarFixture.cpu]
        let passed = [BarFixture.clock, BarFixture.weather(.medium), BarFixture.cpu]
        return VStack(alignment: .leading, spacing: 14) {
            Heading(title: "Drag to reorder", note: "Lift 1.06×, deeper shadow, slot outline, neighbours settle.")
            Panel(title: "Just lifted", wallpaper: .glassDark) {
                GallerySampleBar(context: BarFixture.context(.glass, dark: true), items: lifted,
                                 drag: BarDrag(id: lifted[1].id, translation: 14))
            }
            Panel(title: "Dragged past CPU: CPU slides over, slot follows", wallpaper: .glassDark) {
                GallerySampleBar(context: BarFixture.context(.glass, dark: true), items: passed,
                                 drag: BarDrag(id: passed[1].id, translation: 60))
            }
            Panel(title: "Solid light, just lifted", wallpaper: .solidLight) {
                GallerySampleBar(context: BarFixture.context(.light, dark: false), items: lifted,
                                 drag: BarDrag(id: lifted[1].id, translation: 14))
            }
        }
    }

    private var emptySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Heading(title: "Empty bar", note: "One invitation, Limo beside it.")
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    Panel(title: "Liquid Glass · dark", wallpaper: .glassDark) {
                        GallerySampleBar(context: BarFixture.context(.glass, dark: true), items: [])
                    }
                    Panel(title: "Paper · 56 pt", wallpaper: .paper) {
                        GallerySampleBar(context: BarFixture.context(.paper, dark: false, thickness: 56), items: [])
                    }
                }
                Panel(title: "Vertical", wallpaper: .glassDark) {
                    GallerySampleBar(context: BarFixture.context(.glass, dark: true, vertical: true), items: [])
                }
            }
        }
    }
}
#endif
