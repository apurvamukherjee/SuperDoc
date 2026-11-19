import SwiftUI

/// Coding-agent sessions across all projects: working / needs input / done / idle.
struct AgentsBoardWidget: SuperWidget {
    typealias Settings = NoSettings

    static let id = "ai.agents"
    static var name: String { String(localized: "Coding Agents") }
    static let category = WidgetCategory.ai
    static let symbol = "person.2.wave.2"
    static let supportedSizes: [TileSize] = [.compact, .medium, .wide, .large]

    static func view(size: TileSize, settings: Settings) -> some View {
        AgentsBoardTile(size: size)
    }
}

extension AgentStatus {
    var color: Color {
        switch self {
        case .working: .blue
        case .needsInput: .orange
        case .done: .green
        case .idle: .gray
        }
    }

    var title: String {
        switch self {
        case .working: String(localized: "Working")
        case .needsInput: String(localized: "Needs input")
        case .done: String(localized: "Done")
        case .idle: String(localized: "Idle")
        }
    }
}

private struct AgentsBoardTile: View {
    let size: TileSize
    private let service = AgentSessionService.shared

    var body: some View {
        Group {
            if service.sessions.isEmpty {
                Image(systemName: "moon.zzz").font(.title3).foregroundStyle(.secondary)
                    .accessibilityLabel("No coding agents running")
            } else if size == .compact {
                counts
            } else {
                list
            }
        }
        .onAppear { service.subscribe() }
        .onDisappear { service.unsubscribe() }
    }

    /// One dot + count per status that has sessions.
    private var counts: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(AgentStatus.allCases, id: \.self) { status in
                let count = service.sessions.filter { $0.status == status }.count
                if count > 0 {
                    HStack(spacing: 4) {
                        Circle().fill(status.color).frame(width: 7, height: 7)
                        Text("\(count)").font(.caption.monospacedDigit().weight(.semibold))
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(count) \(status.title)")
                }
            }
        }
    }

    private var list: some View {
        let limit = size == .medium ? 3 : 3 * (size.columns - 1)
        let shown = service.sessions.prefix(limit)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: max(size.columns - 1, 1)),
                         alignment: .leading, spacing: 2) {
            ForEach(shown) { session in
                HStack(spacing: 4) {
                    Circle().fill(session.status.color).frame(width: 7, height: 7)
                    // Truncate rather than shrink: one long folder name shouldn't make its row smaller than the rest.
                    Text(session.project).font(.caption2.weight(.medium)).truncationMode(.middle)
                    Text(session.tool.title).font(.caption2).foregroundStyle(.secondary).fixedSize()
                }
                .lineLimit(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(session.project), \(session.tool.title), \(session.status.title)")
            }
            if service.sessions.count > limit {
                Text("+\(service.sessions.count - limit) more").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
