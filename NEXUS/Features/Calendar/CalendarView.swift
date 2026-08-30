import SwiftUI
import SwiftData

struct CalendarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query private var entries: [CalendarEntry]
    @Query private var studyTasks: [StudyTask]
    @Query private var courses: [Course]
    @Query private var scheduleRules: [StudyScheduleRule]
    @StateObject private var viewModel = CalendarViewModel()
    @State private var editor: UUID?
    @State private var creating = false
    @State private var deletion: CalendarEntry?
    @State private var showReminderInfo = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TerminalHeader(titleKey: "route.calendar", subtitleKey: "calendar.subtitle", onBack: appState.goHome)
            calendarToolbar
            HStack(spacing: 0) {
                Group { if viewModel.displayMode == .month { monthView } else { weekView } }
                Divider().overlay(TerminalTokens.border)
                agenda
            }
            if let error = viewModel.errorMessage { HStack { Image(systemName: "xmark.octagon"); Text(error); Spacer() }.foregroundStyle(TerminalTokens.error).padding(.horizontal, 12).frame(height: 28).background(TerminalTokens.surface) }
            else { TerminalStatusBar(messageKey: viewModel.statusMessageKey, kind: viewModel.statusMessageKey == "status.saved" ? .success : .neutral) }
        }
        .sheet(isPresented: $creating) { CalendarEntryEditor(entry: nil, initialDate: viewModel.selectedDate, studyTasks: studyTasks, courses: courses, viewModel: viewModel) }
        .sheet(item: $editor) { id in CalendarEntryEditor(entry: entries.first { $0.id == id }, initialDate: viewModel.selectedDate, studyTasks: studyTasks, courses: courses, viewModel: viewModel) }
        .sheet(isPresented: $showReminderInfo) { ReminderSettingsView() }
        .confirmationDialog("delete.confirm.title", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) {
            Button("action.delete", role: .destructive) { deleteEntry() }; Button("action.cancel", role: .cancel) { deletion = nil }
        } message: { Text("delete.confirm.message") }
        .onReceive(NotificationCenter.default.publisher(for: .nexusNewItem)) { _ in creating = true }
        .onReceive(NotificationCenter.default.publisher(for: .nexusFocusSearch)) { _ in searchFocused = true }
        .accessibilityIdentifier("calendar.screen")
    }

    private var calendarToolbar: some View {
        HStack(spacing: 9) {
            Button { viewModel.move(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(TerminalButtonStyle()).accessibilityLabel(Text("calendar.previous"))
            Button("calendar.today") { viewModel.goToday() }.buttonStyle(TerminalButtonStyle())
            Button { viewModel.move(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(TerminalButtonStyle()).accessibilityLabel(Text("calendar.next"))
            Text(viewModel.displayedDate, format: .dateTime.month(.wide).year()).font(.system(.title3, design: .monospaced, weight: .bold)).frame(minWidth: 180)
            Picker("calendar.view", selection: $viewModel.displayMode) { ForEach(CalendarDisplayMode.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }.pickerStyle(.segmented).frame(width: 160)
            Spacer()
            Image(systemName: "magnifyingglass"); TextField("calendar.search", text: $viewModel.searchText).textFieldStyle(.plain).focused($searchFocused).frame(maxWidth: 190)
            Picker("calendar.filter", selection: $viewModel.kindFilter) { Text("filter.all").tag(CalendarEntryKind?.none); ForEach(CalendarEntryKind.allCases) { Text(LocalizedStringKey($0.titleKey)).tag(Optional($0)) } }.frame(width: 130)
            Button { showReminderInfo = true } label: { Image(systemName: "bell") }.buttonStyle(TerminalButtonStyle()).accessibilityLabel(Text("calendar.reminders.settings"))
            Button { creating = true } label: { Label("action.new", systemImage: "plus") }.buttonStyle(TerminalPrimaryButtonStyle())
        }.padding(.horizontal, 12).frame(height: 54).background(TerminalTokens.surface.opacity(0.4))
    }

    private var monthView: some View {
        let days = viewModel.monthDays(for: viewModel.displayedDate)
        return VStack(spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                ForEach(Array(viewModel.weekDays(for: viewModel.displayedDate).enumerated()), id: \.offset) { _, day in Text(day, format: .dateTime.weekday(.abbreviated)).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted).frame(maxWidth: .infinity).padding(6) }
                ForEach(days, id: \.self) { day in dayCell(day) }
            }.padding(10)
            Spacer(minLength: 0)
        }.focusable().onMoveCommand { direction in moveSelection(direction) }
    }

    private func dayCell(_ day: Date) -> some View {
        let dayEntries = viewModel.entries(entries, on: day)
        let dueTasks = viewModel.studyTasks(studyTasks, on: day)
        let lessons = lessonOccurrences(on: day)
        let inMonth = Calendar.current.isDate(day, equalTo: viewModel.displayedDate, toGranularity: .month)
        let selected = Calendar.current.isDate(day, inSameDayAs: viewModel.selectedDate)
        return Button { viewModel.selectedDate = day } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(day, format: .dateTime.day()).fontWeight(Calendar.current.isDateInToday(day) ? .bold : .regular); Spacer(); if !dayEntries.isEmpty || !dueTasks.isEmpty || !lessons.isEmpty { Text("\(dayEntries.count + dueTasks.count + lessons.count)").font(.caption2).padding(3).background(TerminalTokens.phosphor.opacity(0.15)) } }
                ForEach(dayEntries.prefix(2)) { entry in HStack(spacing: 3) { Image(systemName: entry.kind.symbol); Text(entry.title).lineLimit(1) }.font(.caption2) }
                if let lesson = lessons.first { HStack(spacing: 3) { Image(systemName: "clock.badge"); Text(lesson.title).lineLimit(1) }.font(.caption2) }
                if !dueTasks.isEmpty { HStack(spacing: 3) { Image(systemName: "book.closed"); Text("calendar.studyDue").lineLimit(1) }.font(.caption2) }
                Spacer(minLength: 0)
            }.padding(6).frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(inMonth ? TerminalTokens.phosphor : TerminalTokens.disabled).background(selected ? TerminalTokens.phosphor.opacity(0.14) : TerminalTokens.surface.opacity(0.35)).overlay(Rectangle().stroke(selected ? TerminalTokens.phosphor : TerminalTokens.border.opacity(0.4), lineWidth: selected ? 2 : 1)).accessibilityLabel(Text(day, format: .dateTime.day().month().year())).accessibilityValue(Text(String(format: String(localized: "calendar.items.count"), dayEntries.count + dueTasks.count + lessons.count)))
    }

    private var weekView: some View {
        HStack(spacing: 1) { ForEach(viewModel.weekDays(for: viewModel.displayedDate), id: \.self) { day in
            Button { viewModel.selectedDate = day } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(day, format: .dateTime.weekday(.abbreviated).day()).font(.headline)
                    ForEach(viewModel.entries(entries, on: day)) { entry in VStack(alignment: .leading) { Label(entry.title, systemImage: entry.kind.symbol).lineLimit(2); if !entry.isAllDay { Text(entry.startDate, style: .time).font(.caption) } }.padding(6).frame(maxWidth: .infinity, alignment: .leading).background(TerminalTokens.surfaceRaised) }
                    ForEach(lessonOccurrences(on: day)) { lesson in VStack(alignment: .leading) { Label(lesson.title, systemImage: "clock.badge").lineLimit(2); Text(lesson.start, style: .time).font(.caption) }.padding(6).frame(maxWidth: .infinity, alignment: .leading).background(TerminalTokens.phosphor.opacity(0.08)) }
                    ForEach(viewModel.studyTasks(studyTasks, on: day)) { task in Label(task.title, systemImage: "book.closed").font(.caption).padding(6).frame(maxWidth: .infinity, alignment: .leading).background(TerminalTokens.phosphor.opacity(0.08)) }
                    Spacer()
                }.padding(8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).background(Calendar.current.isDate(day, inSameDayAs: viewModel.selectedDate) ? TerminalTokens.phosphor.opacity(0.10) : .clear).contentShape(Rectangle())
            }.buttonStyle(.plain)
        } }.padding(10).focusable().onMoveCommand { moveSelection($0) }
    }

    private var agenda: some View {
        let dayEntries = viewModel.entries(entries, on: viewModel.selectedDate)
        let dueTasks = viewModel.studyTasks(studyTasks, on: viewModel.selectedDate)
        let lessons = lessonOccurrences(on: viewModel.selectedDate)
        return VStack(alignment: .leading, spacing: 0) {
            HStack { VStack(alignment: .leading) { Text("calendar.agenda").font(.headline); Text(viewModel.selectedDate, format: .dateTime.weekday(.wide).day().month(.wide)).foregroundStyle(TerminalTokens.phosphorMuted) }; Spacer(); Button { creating = true } label: { Image(systemName: "plus") }.buttonStyle(TerminalButtonStyle()) }.padding(12)
            Divider().overlay(TerminalTokens.border)
            if dayEntries.isEmpty && dueTasks.isEmpty && lessons.isEmpty { TerminalEmptyState(titleKey: "calendar.empty.title", messageKey: "calendar.empty.message", actionKey: "action.new", action: { creating = true }) }
            else { ScrollView { VStack(spacing: 8) {
                ForEach(dayEntries) { entry in Button { editor = entry.id } label: { VStack(alignment: .leading, spacing: 5) { HStack { Image(systemName: entry.kind.symbol); Text(entry.title).fontWeight(.semibold); Spacer(); if entry.isCompleted { Image(systemName: "checkmark.circle.fill").accessibilityLabel(Text("task.status.completed")) } }; if !entry.isAllDay { Text(entry.startDate, style: .time).font(.caption) }; if entry.reminderDate != nil { Label("calendar.reminder.modeled", systemImage: "bell").font(.caption) }; Text(entry.details).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted).lineLimit(2) }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(TerminalTokens.surface).overlay(RoundedRectangle(cornerRadius: 3).stroke(TerminalTokens.border)) }.buttonStyle(.plain).contextMenu { Button("action.edit") { editor = entry.id }; Button("action.delete", role: .destructive) { deletion = entry } }
                }
                ForEach(dueTasks) { task in VStack(alignment: .leading, spacing: 4) { Label(task.title, systemImage: "book.closed").fontWeight(.semibold); Text("calendar.studyTask.linked").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted) }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(TerminalTokens.phosphor.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 3).stroke(TerminalTokens.border)) }
                ForEach(lessons) { lesson in Button { appState.openSemesterSetup() } label: { VStack(alignment: .leading, spacing: 4) { Label(lesson.title, systemImage: "clock.badge").fontWeight(.semibold); Text(lesson.start, format: .dateTime.hour().minute()); if !lesson.subtitle.isEmpty { Text(lesson.subtitle).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted) }; Text("calendar.lesson.transient").font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted) }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(TerminalTokens.phosphor.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 3).stroke(TerminalTokens.border)) }.buttonStyle(.plain) }
            }.padding(10) } }
        }.frame(minWidth: 260, idealWidth: 310, maxWidth: 360).background(TerminalTokens.surface.opacity(0.25))
    }

    private func moveSelection(_ direction: MoveCommandDirection) { let delta = switch direction { case .left: -1; case .right: 1; case .up: -7; case .down: 7; @unknown default: 0 }; viewModel.selectedDate = Calendar.current.date(byAdding: .day, value: delta, to: viewModel.selectedDate) ?? viewModel.selectedDate; viewModel.displayedDate = viewModel.selectedDate }
    private func lessonOccurrences(on day: Date) -> [LessonOccurrence] { DailyPlanAggregator.occurrences(rules: scheduleRules, on: day, courses: courses) }
    private func deleteEntry() { guard let deletion else { return }; do { try viewModel.delete(deletion, context: context) } catch { viewModel.errorMessage = error.localizedDescription }; self.deletion = nil }
}

extension UUID: @retroactive Identifiable { public var id: UUID { self } }
