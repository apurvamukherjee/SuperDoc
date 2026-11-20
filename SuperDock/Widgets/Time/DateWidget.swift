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
            DateWidgetView(date: context.date)
        }
    }
}
