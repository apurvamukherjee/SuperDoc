import SwiftUI

struct DateWidget: SuperWidget {
    typealias Settings = NoSettings

    static let id = "time.date"
    static var name: String { String(localized: "Date") }
    static let category = WidgetCategory.time
    static let symbol = "calendar"
    static let supportedSizes: [TileSize] = [.compact, .medium]

    static func view(size: TileSize, settings: Settings) -> some View {
        TimelineView(.everyMinute) { context in
            if size == .compact {
                // Calendar-page look: weekday over the day number.
                VStack(spacing: 0) {
                    Text(context.date, format: .dateTime.weekday(.abbreviated))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .textCase(.uppercase)
                    Text(context.date, format: .dateTime.day())
                        .font(.title.weight(.medium))
                }
                .tileText()
            } else {
                VStack(spacing: 2) {
                    Text(context.date, format: .dateTime.weekday(.wide))
                        .font(.headline)
                    Text(context.date, format: .dateTime.day().month(.wide))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tileText()
            }
        }
    }
}
