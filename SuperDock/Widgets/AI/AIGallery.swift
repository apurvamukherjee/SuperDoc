#if DEBUG
import SwiftUI

extension GallerySheets {
    /// AI Limits and Coding Agents.
    /// Compare with design/mockups/04-hero-ai-limits-coding-agents.png.
    static var ai: AnyView? { AnyView(AISheet()) }
}

@MainActor
enum AISamples {
    static let now = Samples.now

    static let limits = [
        AILimit(provider: .claude, name: "5h", longName: "5-hour", used: 62, resetsIn: 2 * 3600 + 14 * 60),
        AILimit(provider: .claude, name: "Wk", longName: "Weekly", used: 41, resetsIn: 4 * 86400, resetDay: "Mon",
                isPrimary: false),
        AILimit(provider: .codex, name: "5h", longName: "5-hour", used: 86, resetsIn: 38 * 60),
        AILimit(provider: .codex, name: "Wk", longName: "Weekly", used: 23, resetsIn: 3 * 86400, resetDay: "Sun",
                isPrimary: false)
    ]
    static let calm = [
        AILimit(provider: .claude, name: "5h", longName: "5-hour", used: 63, resetsIn: 2 * 3600 + 14 * 60),
        AILimit(provider: .claude, name: "Wk", longName: "Weekly", used: 41, resetsIn: 4 * 86400, resetDay: "Mon",
                isPrimary: false)
    ]
    static let spent = [
        AILimit(provider: .claude, name: "5h", longName: "5-hour", used: 100, resetsIn: 2 * 3600 + 14 * 60),
        AILimit(provider: .claude, name: "Wk", longName: "Weekly", used: 71, resetsIn: 4 * 86400, resetDay: "Mon",
                isPrimary: false)
    ]

    private static func agent(_ project: String, _ tool: AIProvider, _ status: AgentStatus, minutes: Double? = nil) -> AgentItem {
        AgentItem(id: project, project: project, tool: tool, status: status,
                  since: minutes.map { now.addingTimeInterval(-$0 * 60) })
    }

    static let six = [
        agent("superdock", .claude, .needsInput), agent("web-app", .claude, .working, minutes: 12),
        agent("infra", .codex, .working), agent("mobile", .claude, .working), agent("api", .codex, .done, minutes: 2),
        agent("docs", .claude, .idle)
    ]
    static let ten = [
        agent("superdock", .claude, .needsInput), agent("billing", .codex, .needsInput),
        agent("web-app", .claude, .working, minutes: 12), agent("infra", .codex, .working), agent("mobile", .claude, .working),
        agent("api", .codex, .done, minutes: 2), agent("design-system", .claude, .done, minutes: 6),
        agent("docs", .claude, .idle), agent("site", .codex, .idle), agent("scripts", .claude, .idle)
    ]
    static let allDone = [
        agent("api", .codex, .done, minutes: 2), agent("web-app", .claude, .done, minutes: 5),
        agent("infra", .codex, .done, minutes: 8), agent("docs", .claude, .done, minutes: 9)
    ]
    static let single = [agent("web-app", .claude, .working, minutes: 12)]
    static let singleNeeds = [agent("superdock", .claude, .needsInput, minutes: 1)]
}

private struct AISheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            ForEach([SurfaceStyle.glassDark, .solidLight, .paper, .glassLight], id: \.self) { style in
                AIStylePanel(style: style)
            }
            AIScalePanel()
        }
        .padding(40)
        .background(Color(rgb: 0x101014))
    }
}

private struct AIStylePanel: View {
    let style: SurfaceStyle

    private var surface: SurfaceTokens { SurfaceTokens(style) }

    private func context(_ size: TileSize, unit: CGFloat = 73, portrait: Bool = false) -> TileContext {
        TileContext(unit: unit, size: size, isPortrait: portrait, surface: surface)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 30) {
            VStack(alignment: .leading, spacing: 14) {
                caption("\(style.rawValue) · AI Limits · C rings · M both 5-hour · W all four · L next reset")
                GalleryBar(surface: surface) {
                    ForEach(TileSize.allCases) { size in
                        AILimitsView(content: .limits(AISamples.limits)).asTile(context(size))
                    }
                }
                caption("States · calm (Claude only) · remaining · connect · no data · spent → resets")
                GalleryBar(surface: surface) {
                    AILimitsView(content: .limits(AISamples.calm)).asTile(context(.compact))
                    AILimitsView(content: .limits(AISamples.limits), showRemaining: true).asTile(context(.medium))
                    AILimitsView(content: .connect).asTile(context(.medium))
                    AILimitsView(content: .connect).asTile(context(.compact))
                    AILimitsView(content: .noData).asTile(context(.compact))
                    AILimitsView(content: .noData).asTile(context(.medium))
                    AILimitsView(content: .limits(AISamples.spent)).asTile(context(.compact))
                }
                caption("Coding Agents · C counts · M three rows · W 2×3 · L 3×3")
                GalleryBar(surface: surface) {
                    AgentsBoardView(agents: AISamples.six, now: AISamples.now).asTile(context(.compact))
                    AgentsBoardView(agents: AISamples.six, now: AISamples.now).asTile(context(.medium))
                    AgentsBoardView(agents: AISamples.six, now: AISamples.now).asTile(context(.wide))
                    AgentsBoardView(agents: AISamples.ten, now: AISamples.now).asTile(context(.large))
                }
                caption("States · empty · all done · single session · single needs-you")
                GalleryBar(surface: surface) {
                    AgentsBoardView(agents: []).asTile(context(.compact))
                    AgentsBoardView(agents: []).asTile(context(.medium))
                    AgentsBoardView(agents: AISamples.allDone, now: AISamples.now).asTile(context(.medium))
                    AgentsBoardView(agents: AISamples.single, now: AISamples.now).asTile(context(.wide))
                    AgentsBoardView(agents: AISamples.singleNeeds, now: AISamples.now).asTile(context(.medium))
                    AgentsBoardView(agents: AISamples.allDone, now: AISamples.now).asTile(context(.compact))
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                caption("Portrait · M · W · L")
                HStack(alignment: .top, spacing: 14) {
                    GalleryBar(surface: surface, vertical: true) {
                        AILimitsView(content: .limits(AISamples.limits)).asTile(context(.medium, portrait: true))
                        AgentsBoardView(agents: AISamples.six, now: AISamples.now).asTile(context(.medium, portrait: true))
                    }
                    GalleryBar(surface: surface, vertical: true) {
                        AILimitsView(content: .limits(AISamples.limits)).asTile(context(.wide, portrait: true))
                        AgentsBoardView(agents: AISamples.ten, now: AISamples.now).asTile(context(.wide, portrait: true))
                    }
                    GalleryBar(surface: surface, vertical: true) {
                        AILimitsView(content: .limits(AISamples.limits)).asTile(context(.large, portrait: true))
                        AgentsBoardView(agents: AISamples.ten, now: AISamples.now).asTile(context(.large, portrait: true))
                    }
                }
            }
        }
        .padding(28)
        .background(galleryWallpaper(style), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .semibold))
            .foregroundStyle(style.isDark ? Color.white.opacity(0.7) : Palette.ink.opacity(0.7))
    }
}

/// 56 pt tight and 120 pt roomy, like mockup 01's scale strip.
private struct AIScalePanel: View {
    var body: some View {
        let surface = SurfaceTokens(.glassDark)
        VStack(alignment: .leading, spacing: 14) {
            ForEach([56, 120], id: \.self) { bar in
                let unit = CGFloat(bar) - 2 * TileContext.spacing
                Text("\(bar) pt").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                GalleryBar(surface: surface) {
                    ForEach(TileSize.allCases) { size in
                        AILimitsView(content: .limits(AISamples.limits))
                            .asTile(TileContext(unit: unit, size: size, surface: surface))
                    }
                }
                GalleryBar(surface: surface) {
                    ForEach(TileSize.allCases) { size in
                        AgentsBoardView(agents: size == .large ? AISamples.ten : AISamples.six, now: AISamples.now)
                            .asTile(TileContext(unit: unit, size: size, surface: surface))
                    }
                }
            }
        }
        .padding(28)
        .background(galleryWallpaper(.glassDark), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
#endif
