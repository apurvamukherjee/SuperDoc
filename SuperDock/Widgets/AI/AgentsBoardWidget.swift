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
        AgentsBoardTile()
    }
}

extension AgentStatus {
    /// Limo's alert pill still uses the old system colours; tiles use `tint` from the design tokens.
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

/// Reads the service and hands plain values to `AgentsBoardView`.
private struct AgentsBoardTile: View {
    private let service = AgentSessionService.shared

    var body: some View {
        // The minute tick only moves "12m" / "2m ago"; status changes arrive through the service.
        TimelineView(.everyMinute) { context in
            AgentsBoardView(agents: service.sessions.map {
                AgentItem(id: $0.id, project: $0.project, tool: $0.tool, status: $0.status, since: $0.since)
            }, now: context.date)
        }
        .onAppear { service.subscribe() }
        .onDisappear { service.unsubscribe() }
    }
}
