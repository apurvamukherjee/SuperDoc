import SwiftUI

/// Sheet listing every widget by category, with search.
struct WidgetPicker: View {
    let onPick: (WidgetDescriptor) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(WidgetCategory.allCases, id: \.self) { category in
                    let matches = WidgetRegistry.all.filter {
                        $0.category == category && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
                    }
                    if !matches.isEmpty {
                        Section(category.title) {
                            ForEach(matches) { row($0) }
                        }
                    }
                }
            }
            .searchable(text: $search, placement: .toolbar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .frame(width: 380, height: 440)
    }

    private func row(_ widget: WidgetDescriptor) -> some View {
        Button {
            onPick(widget)
            dismiss()
        } label: {
            HStack {
                Label(widget.name, systemImage: widget.symbol)
                Spacer()
                if widget.usesNetwork {
                    Image(systemName: "network")
                        .foregroundStyle(.secondary)
                        .help("Uses the internet")
                        .accessibilityLabel("Uses the internet")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
