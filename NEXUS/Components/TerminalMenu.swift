import SwiftUI

struct TerminalMenu: View {
    let routes: [AppRoute]
    @Binding var selection: AppRoute?
    let action: (AppRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(routes) { route in
                TerminalMenuRow(route: route, selected: selection == route) {
                    selection = route; action(route)
                }
            }
        }
        .focusable()
        .onMoveCommand { direction in
            let index = selection.flatMap(routes.firstIndex) ?? 0
            if direction == .down { selection = routes[min(index + 1, routes.count - 1)] }
            if direction == .up { selection = routes[max(index - 1, 0)] }
        }
        .onSubmit { if let selection { action(selection) } }
    }
}

private struct TerminalMenuRow: View {
    let route: AppRoute
    let selected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text("[\(route.number)]").fontWeight(.bold)
                Image(systemName: route.symbol).frame(width: 18)
                Text(LocalizedStringKey(route.titleKey))
                Spacer()
                Text(route.isAvailable ? LocalizedStringKey("module.ready") : LocalizedStringKey("module.future"))
                    .font(.caption).foregroundStyle(route.isAvailable ? TerminalTokens.phosphor : TerminalTokens.disabled)
            }
            .padding(.horizontal, 12).frame(height: 42).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selected ? TerminalTokens.phosphor.opacity(0.14) : (hovered ? TerminalTokens.phosphor.opacity(0.07) : Color.clear))
        .overlay(alignment: .leading) { if selected { Rectangle().fill(TerminalTokens.phosphor).frame(width: 3) } }
        .onHover { hovered = $0 }
        .accessibilityHint(Text(route.isAvailable ? "module.openHint" : "module.futureHint"))
    }
}
