import SwiftUI
import SwiftData
import AppKit

private struct ControlSearchResult: Identifiable {
    let id: String
    let route: AppRoute
    let title: String
    let subtitle: String
    let symbol: String
}

/// Full-window terminal control system. Numbered module rows are deliberately
/// static: the primary interaction is the physical 1–8 keys and native menus.
struct CommandPalette: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var appState: AppState
    @Query private var courses: [Course]
    @Query private var studyTasks: [StudyTask]
    @Query private var notes: [NexusNote]
    @Query private var calendarEntries: [CalendarEntry]
    @Query private var financeEntries: [FinanceEntry]
    @Query private var workoutPlans: [WorkoutPlan]
    @Query private var workoutRecords: [WorkoutRecord]
    @Query private var universityCourses: [UniversityCourse]
    @Query private var assessments: [OBSAssessment]
    @Query private var projects: [ProjectRecord]
    @Query private var organizationTasks: [OrganizationTask]
    @State private var query = ""
    @State private var keyboardMonitor: Any?
    @FocusState private var searchFocused: Bool
    @FocusState private var controlFocused: Bool

    private var searchResults: [ControlSearchResult] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2 else { return [] }
        func contains(_ values: String...) -> Bool { values.contains { $0.localizedCaseInsensitiveContains(needle) } }
        var values: [ControlSearchResult] = []
        values += courses.filter { contains($0.name, $0.code, $0.instructor, $0.location) }.map { .init(id: "course-\($0.id)", route: .study, title: $0.name, subtitle: String(localized: "command.result.course"), symbol: "book.closed") }
        values += studyTasks.filter { contains($0.title, $0.details) }.map { .init(id: "study-task-\($0.id)", route: .study, title: $0.title, subtitle: String(localized: "command.result.studyTask"), symbol: "checklist") }
        values += notes.filter { contains($0.title, $0.body) }.map { .init(id: "note-\($0.id)", route: .notes, title: $0.title, subtitle: String(localized: "command.result.note"), symbol: "note.text") }
        values += calendarEntries.filter { contains($0.title, $0.details) }.map { .init(id: "calendar-\($0.id)", route: .calendar, title: $0.title, subtitle: String(localized: "command.result.calendar"), symbol: "calendar") }
        values += financeEntries.filter { contains($0.title, $0.category) }.map { .init(id: "finance-\($0.id)", route: .finance, title: $0.title, subtitle: String(localized: "command.result.finance"), symbol: "banknote") }
        values += workoutPlans.filter { contains($0.name, $0.goal) }.map { .init(id: "workout-plan-\($0.id)", route: .gym, title: $0.name, subtitle: String(localized: "command.result.workoutPlan"), symbol: "figure.strengthtraining.traditional") }
        values += workoutRecords.filter { contains($0.title, $0.note) }.map { .init(id: "workout-\($0.id)", route: .gym, title: $0.title, subtitle: String(localized: "command.result.workout"), symbol: "figure.run") }
        values += universityCourses.filter { contains($0.name, $0.code, $0.semester) }.map { .init(id: "obs-course-\($0.id)", route: .obs, title: $0.name, subtitle: String(localized: "command.result.obsCourse"), symbol: "graduationcap") }
        values += assessments.filter { contains($0.title, $0.note) }.map { .init(id: "assessment-\($0.id)", route: .obs, title: $0.title, subtitle: String(localized: "command.result.assessment"), symbol: "doc.text.magnifyingglass") }
        values += projects.filter { contains($0.title, $0.details) }.map { .init(id: "project-\($0.id)", route: .organization, title: $0.title, subtitle: String(localized: "command.result.project"), symbol: "square.grid.2x2") }
        values += organizationTasks.filter { contains($0.title, $0.details) }.map { .init(id: "organization-task-\($0.id)", route: .organization, title: $0.title, subtitle: String(localized: "command.result.organizationTask"), symbol: "list.bullet.indent") }
        return Array(values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }.prefix(12))
    }

    var body: some View {
        ZStack {
            TerminalTokens.background.ignoresSafeArea()
            controlFrame

            Button { enterSearchMode() } label: { EmptyView() }
                .keyboardShortcut("/", modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)

        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("control.accessibilityLabel"))
        .accessibilityIdentifier("controlSystem.screen")
        .focusable()
        .focused($controlFocused)
        .onAppear {
            installKeyboardMonitor()
            if appState.controlSystemMode == .search { searchFocused = true }
            else { controlFocused = true }
        }
        .onDisappear { removeKeyboardMonitor() }
        .onChange(of: appState.controlSystemMode) { _, mode in
            searchFocused = mode == .search
            controlFocused = mode == .modules
        }
        .onExitCommand { appState.handleEscape() }
    }

    private var controlFrame: some View {
        VStack(spacing: 0) {
            VStack(spacing: 7) {
                TerminalRevealText(localizedKey: "home.systemTitle", intervalMilliseconds: 30)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .tracking(2.4)
                TerminalRevealText(localizedKey: "home.terminalReady", intervalMilliseconds: 24, showsCursor: false)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(TerminalTokens.phosphorMuted)
                Text("home.selectProgram")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(TerminalTokens.phosphorMuted)
            }
            .padding(.bottom, 16)

            Rectangle().fill(TerminalTokens.border).frame(height: 1)

            VStack(spacing: 0) {
                ForEach(AppRoute.allCases) { route in
                    moduleLine(route)
                }
                settingsLine
            }
            .padding(.vertical, 8)

            Rectangle().fill(TerminalTokens.border).frame(height: 1)

            if appState.controlSystemMode == .search {
                searchPanel
            } else {
                commandPrompt
            }

            footer
        }
        .frame(maxWidth: 760)
        .padding(.horizontal, 34)
        .padding(.vertical, 26)
        .overlay(Rectangle().stroke(TerminalTokens.border.opacity(0.72), lineWidth: 1))
        .overlay(alignment: .topLeading) { cornerMark.rotationEffect(.degrees(0)) }
        .overlay(alignment: .topTrailing) { cornerMark.rotationEffect(.degrees(90)) }
        .overlay(alignment: .bottomTrailing) { cornerMark.rotationEffect(.degrees(180)) }
        .overlay(alignment: .bottomLeading) { cornerMark.rotationEffect(.degrees(270)) }
        .padding(28)
    }

    private func moduleLine(_ route: AppRoute) -> some View {
        let title = String(localized: String.LocalizationValue(route.titleKey))
        return HStack(spacing: 18) {
            Text(String(format: "[%d]", route.number))
                .foregroundStyle(TerminalTokens.phosphor)
                .frame(width: 44, alignment: .trailing)
            TerminalRevealText(title.uppercased(), intervalMilliseconds: 14, showsCursor: false, isSkippable: false)
                .foregroundStyle(TerminalTokens.phosphor)
            Spacer()
            Text("control.keyHint")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(TerminalTokens.phosphorMuted.opacity(0.72))
        }
        .font(.system(.body, design: .monospaced, weight: .medium))
        .frame(height: 31)
        .padding(.horizontal, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(TerminalTokens.border.opacity(0.13)).frame(height: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: String(localized: "control.option.accessibility"), route.number, title, route.number)))
        .accessibilityHint(Text("control.option.hint"))
    }

    private var settingsLine: some View {
        HStack(spacing: 18) {
            Text("[9]")
                .foregroundStyle(TerminalTokens.phosphor)
                .frame(width: 44, alignment: .trailing)
            TerminalRevealText(localizedKey: "control.settings", intervalMilliseconds: 14, showsCursor: false, isSkippable: false)
                .foregroundStyle(TerminalTokens.phosphor)
            Spacer()
            Text("control.settingsKeyHint")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(TerminalTokens.phosphorMuted.opacity(0.72))
        }
        .font(.system(.body, design: .monospaced, weight: .medium))
        .frame(height: 31)
        .padding(.horizontal, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(TerminalTokens.border.opacity(0.13)).frame(height: 1) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("control.settings.accessibility"))
        .accessibilityHint(Text("control.settings.hint"))
        .accessibilityIdentifier("controlSystem.settings")
    }

    private var commandPrompt: some View {
        HStack(spacing: 8) {
            Text(">")
            TerminalRevealText(localizedKey: "control.prompt", intervalMilliseconds: 18, showsCursor: false)
            TerminalCommandCursor()
            Spacer()
        }
        .font(.system(.callout, design: .monospaced))
        .padding(.horizontal, 12)
        .frame(height: 54)
        .accessibilityElement(children: .combine)
    }

    private var searchPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("> FIND")
                TextField("control.search.placeholder", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .accessibilityIdentifier("controlSystem.search")
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .overlay(Rectangle().stroke(TerminalTokens.border.opacity(0.7)))

            if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                Text("control.search.minimum")
                    .font(.caption)
                    .foregroundStyle(TerminalTokens.phosphorMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if searchResults.isEmpty {
                Text("command.noResults")
                    .font(.caption)
                    .foregroundStyle(TerminalTokens.phosphorMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(searchResults) { result in
                            Button {
                                appState.open(result.route)
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: result.symbol)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title).lineLimit(1)
                                        Text(result.subtitle).font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted)
                                    }
                                }
                                .padding(.horizontal, 9)
                                .frame(height: 44)
                            }
                            .buttonStyle(TerminalButtonStyle())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 74)
    }

    private var footer: some View {
        HStack(spacing: 20) {
            Label("control.searchShortcut", systemImage: "magnifyingglass")
            Label("control.dashboardShortcut", systemImage: "escape")
            Spacer()
            Text("control.status")
        }
        .font(.system(.caption2, design: .monospaced))
        .foregroundStyle(TerminalTokens.phosphorMuted)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(TerminalTokens.surface.opacity(0.62))
        .accessibilityElement(children: .combine)
    }

    private var cornerMark: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 18))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 18, y: 0))
        }
        .stroke(TerminalTokens.phosphor.opacity(0.7), lineWidth: 1)
        .frame(width: 18, height: 18)
    }

    private func enterSearchMode() {
        appState.controlSystemMode = .search
        searchFocused = true
    }

    private func installKeyboardMonitor() {
        removeKeyboardMonitor()
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let disallowedModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift, .function]
            guard !event.isARepeat,
                  event.modifierFlags.intersection(disallowedModifiers).isEmpty,
                  event.window?.identifier?.rawValue != "com_apple_SwiftUI_Settings_window",
                  appState.controlSystemMode == .modules,
                  let number = ManualNavigationPolicy.controlNumber(forMacKeyCode: event.keyCode),
                  let destination = ManualNavigationPolicy.controlDestination(forNumber: number)
            else { return event }

            switch destination {
            case .route(let route): appState.open(route)
            case .settings: openSettings()
            }
            return nil
        }
    }

    private func removeKeyboardMonitor() {
        guard let keyboardMonitor else { return }
        NSEvent.removeMonitor(keyboardMonitor)
        self.keyboardMonitor = nil
    }

}

private struct TerminalCommandCursor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Text("▌").accessibilityHidden(true)
        } else {
            TimelineView(.periodic(from: .now, by: 0.55)) { timeline in
                Text("▌")
                    .opacity(Int(timeline.date.timeIntervalSinceReferenceDate * 2).isMultiple(of: 2) ? 1 : 0.2)
                    .accessibilityHidden(true)
            }
        }
    }
}
