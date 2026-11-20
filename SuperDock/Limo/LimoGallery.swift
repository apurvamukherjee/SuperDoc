#if DEBUG
import SwiftUI

extension GallerySheets {
    /// Limo character sheet and alert pills.
    /// Compare with design/mockups/06-limo-character.png.
    static var limo: AnyView? { AnyView(LimoSheet()) }
}

private let sheetInk = Palette.ink
private let cardFill = Color(rgb: 0xF9F8F3)

private struct LimoSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            VStack(alignment: .leading, spacing: 4) {
                caption("SUPERDOCK'S RESIDENT · FORMERLY “BUDDY”")
                Text("Meet Limo").font(.system(size: 52, weight: .bold)).foregroundStyle(sheetInk)
            }
            HStack(alignment: .top, spacing: 24) {
                hero
                anatomy
            }
            reactions(dark: false)
            reactions(dark: true)
            HStack(alignment: .top, spacing: 24) {
                LimoPillsPanel()
                presence
            }
            emptyStates
        }
        .padding(60)
        .frame(width: 1900, alignment: .leading)
        .background(Color(rgb: 0xF3F1EC))
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            galleryWallpaper(.glassDark)
            VStack(spacing: -34) {
                LimoFigure(pose: .saysHi, gaze: CGVector(dx: 0.6, dy: 0.3)).frame(width: 260, height: 260)
                GalleryBar(surface: SurfaceTokens(.glassDark)) {
                    ForEach([2, 2, 1, 2], id: \.self) { columns in
                        RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08))
                            .frame(width: TileContext.length(columns: columns, unit: 73), height: 73)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
            Text("Limo sits on the bar's top edge, feet over the glass. It looks toward your cursor when you come close.")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.75)).padding(20)
        }
        .frame(width: 820, height: 460)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var anatomy: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("Eyes with pupils · gaze")
            HStack(spacing: 6) {
                ForEach(Self.gazes.indices, id: \.self) { index in
                    LimoFigure(gaze: Self.gazes[index], outlined: false).frame(width: 82, height: 82)
                }
            }
            title("Arms and feet · blink + breath")
            HStack(spacing: 6) {
                ForEach([LimoPose.idle, .saysHi, .celebrates, .checksGauge, .catchesIt], id: \.self) { pose in
                    LimoFigure(pose: pose, outlined: false).frame(width: 82, height: 82)
                }
                LimoFigure(blinking: true, outlined: false).frame(width: 82, height: 82)
                LimoFigure(outlined: false).scaleEffect(x: 1, y: 1.015, anchor: .bottom).frame(width: 82, height: 82)
            }
            note("rest · wave · up · hug · overhead · blink (140 ms every 6–10 s) · breath top (+1.5 %)")
            title("Coral cheek · mood light")
            HStack(spacing: 6) {
                ForEach(Self.moods, id: \.1) { mood, label in
                    VStack(spacing: 2) {
                        LimoFigure(mood: mood, outlined: false, faceOnly: true).frame(width: 60, height: 60)
                        note(label)
                    }
                    .frame(width: 82)
                }
            }
        }
        .padding(28)
        .frame(width: 960, height: 460, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private static let gazes: [CGVector] = [
        .zero, CGVector(dx: -1, dy: 0), CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: -1), CGVector(dx: 0, dy: 1),
        CGVector(dx: -0.7, dy: -0.7), CGVector(dx: 0.7, dy: -0.7), CGVector(dx: -0.7, dy: 0.7), CGVector(dx: 0.7, dy: 0.7)
    ]
    private static let moods: [(LimoLook.Mood, String)] = [
        (.calm, "calm"), (.bright, "needs you"), (.dim, "asleep"), (.flushed, "hot")
    ]

    private func reactions(dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                title("Limo reacts to everything" + (dark ? " · on dark" : ""), dark: dark)
                Spacer()
                note("12 core reactions. Each one is an event, so it costs nothing while nothing happens.", dark: dark)
            }
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(0..<2, id: \.self) { row in
                    GridRow {
                        ForEach(LimoPose.reactions[(row * 6)..<(row * 6 + 6)], id: \.self) { reactionCard($0, dark: dark) }
                    }
                }
            }
        }
        .padding(24)
        .background(dark ? AnyShapeStyle(galleryWallpaper(.glassDark)) : AnyShapeStyle(Color.white),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func reactionCard(_ pose: LimoPose, dark: Bool) -> some View {
        VStack(spacing: 6) {
            caption(pose.trigger.uppercased(), dark: dark)
            LimoFigure(pose: pose, gaze: pose == .saysHi ? CGVector(dx: 0.6, dy: 0.3) : .zero, outlined: dark)
                .frame(width: 140, height: 140)
            Text(pose.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(dark ? .white : sheetInk)
        }
        .padding(.vertical, 14)
        .frame(width: 284)
        .background(dark ? Color.white.opacity(0.06) : cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(dark ? .white.opacity(0.1) : .black.opacity(0.05)))
    }

    private var presence: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("Presence")
            note("Ambient: gestures in place · Notice: the pill pops for 5 s · Urgent: needs-you and frozen apps stay until handled.")
            HStack(alignment: .bottom, spacing: 18) {
                level("Ambient", LimoFigure(pose: .umbrella).frame(width: 70, height: 70))
                level("Notice", LimoFigure(pose: .celebrates).frame(width: 70, height: 70))
                level("Urgent", LimoFigure(pose: .handUp).frame(width: 70, height: 70))
            }
            .padding(16)
            .background(galleryWallpaper(.glassDark), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            title("Settings › Limo: Lively / Calm / Hidden")
            ForEach(LimoPresence.allCases, id: \.self) { presence in
                HStack(spacing: 14) {
                    Text(presence.rawValue.capitalized).font(.system(size: 13, weight: .semibold)).foregroundStyle(sheetInk)
                        .frame(width: 60, alignment: .leading)
                    LimoPillPreview(alert: LimoSamples.done, presence: presence)
                }
            }
            note("Calm: same pill, crossfade instead of spring, no bob or gaze-follow, no ambient gestures.")
            note("Hidden: no character anywhere; alerts arrive as plain pills.")
        }
        .padding(28)
        .frame(width: 830, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func level(_ name: String, _ figure: some View) -> some View {
        VStack(spacing: 4) {
            figure
            Text(name).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
        }
        .frame(width: 100)
    }

    private var emptyStates: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("Empty state · sleeping Limo")
            HStack(spacing: 24) {
                ForEach([SurfaceStyle.glassDark, .solidDark, .glassLight, .paper], id: \.self) { style in
                    GalleryBar(surface: SurfaceTokens(style)) {
                        let state = TileState.empty(title: "All quiet", detail: "No agents running")
                        TileStateView(state: state).asTile(TileContext(size: .compact, surface: SurfaceTokens(style)))
                        TileStateView(state: state).asTile(TileContext(size: .medium, surface: SurfaceTokens(style)))
                    }
                    .padding(18)
                    .background(galleryWallpaper(style), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            HStack(spacing: 18) {
                ForEach([LimoPose.naps, .curious, .idle, .handUp], id: \.self) { pose in
                    LimoFace(snoring: false, pose: pose).frame(width: 40, height: 40)
                        .padding(10).background(galleryWallpaper(.glassDark), in: RoundedRectangle(cornerRadius: 12))
                }
                note("LimoFace(pose:) · face-only glyphs (empty bar uses .curious)")
            }
        }
    }

    private func caption(_ text: String, dark: Bool = false) -> some View {
        Text(text).font(.system(size: 11, weight: .semibold)).tracking(1)
            .foregroundStyle(dark ? .white.opacity(0.6) : sheetInk.opacity(0.6))
    }

    private func title(_ text: String, dark: Bool = false) -> some View {
        Text(text).font(.system(size: 20, weight: .bold)).foregroundStyle(dark ? .white : sheetInk)
    }

    private func note(_ text: String, dark: Bool = false) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(dark ? .white.opacity(0.6) : sheetInk.opacity(0.6))
    }
}

/// Every alert pill state on the mockup's warm-to-violet wallpaper, plus the tucked-in first frame of the pop.
private struct LimoPillsPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("When Limo has something to say").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                Spacer()
                Text("Pill 48 tall · Limo spills 18 above · ≤ 1.5× bar").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
            }
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                ForEach(0..<4, id: \.self) { row in
                    GridRow {
                        ForEach(0..<2, id: \.self) { column in
                            LimoPillPreview(alert: LimoSamples.all[row * 2 + column])
                        }
                    }
                }
            }
            Text("Pop: tucked under the bar's edge → spring out (Motion.pop) → pill unrolls → 5 s → tucks back")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 24) {
                LimoPillPreview(alert: LimoSamples.done, isOut: false)
                    .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.3)).frame(height: 1) }
                LimoPillPreview(alert: LimoSamples.done)
                    .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.3)).frame(height: 1) }
            }
        }
        .padding(28)
        .frame(width: 940, alignment: .topLeading)
        .background(
            LinearGradient(colors: [Color(rgb: 0xE0566A), Color(rgb: 0x2A2552), Color(rgb: 0x1B2A5C), Color(rgb: 0x7357F0)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}

private struct LimoPillPreview: View {
    let alert: LimoAlert
    var presence = LimoPresence.lively
    var isOut = true

    var body: some View {
        let stage = LimoStage()
        stage.alert = alert
        stage.presence = presence
        stage.isOut = isOut
        return LimoPill(stage: stage) {}.clipped()
    }
}

@MainActor
private enum LimoSamples {
    static let done = LimoAlert(title: "api is done", detail: "Codex · just now", pose: .celebrates, tint: Palette.good)
    static let all: [LimoAlert] = [
        done,
        LimoAlert(title: "superdock needs you", detail: "Claude · 1m", pose: .handUp, action: ("Show", {})),
        LimoAlert(title: "Preview is frozen", detail: "20s, not responding", pose: .pokesIce, action: ("Force Quit", {})),
        LimoAlert(title: "Codex 5h at 86%", detail: "Resets in 38m", pose: .checksGauge),
        LimoAlert(title: "sip break?", detail: "3 of 8 glasses", pose: .takesSip, tint: Palette.water, action: ("+1", {})),
        LimoAlert(title: "want live Claude limits?", detail: "Reads status and % only", pose: .curious,
                  tint: Palette.claude, action: ("Connect", {})),
        LimoAlert(title: "3 agents done", detail: "api, web-app, infra", pose: .celebrates, tint: Palette.good),
        LimoAlert(title: "Preview isn't responding", pose: .pokesIce, action: ("Force Quit", {}))
    ]
}
#endif
