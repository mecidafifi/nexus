import SwiftUI

struct RootView: View {
    @State private var selection: AppRoute? = .today

    var body: some View {
        NavigationSplitView {
            ZStack {
                PadTokens.background.ignoresSafeArea()
                List(AppRoute.allCases, selection: $selection) { route in
                    Label(route.title, systemImage: route.icon)
                        .font(.system(.body, design: .monospaced, weight: .medium))
                        .foregroundStyle(PadTokens.phosphor)
                        .padding(.vertical, 8)
                        .tag(route)
                        .accessibilityIdentifier("sidebar.route.\(route.rawValue)")
                        .accessibilityLabel(Text(route.title))
                        .accessibilityHint("Bölümü açar")
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("NEXUS // STUDY PAD")
            }
        } detail: {
            destination(selection ?? .today)
        }
        .tint(PadTokens.phosphor)
    }

    @ViewBuilder private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .today: HomeView { selection = .transfer }
        case .courses: CourseListView()
        case .documents: DocumentListView()
        case .notes: NoteListView()
        case .lectures: LectureListView()
        case .tasks: TaskListView()
        case .transfer: TransferView()
        }
    }
}
