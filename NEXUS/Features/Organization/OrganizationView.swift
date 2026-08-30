import SwiftUI
import SwiftData

struct OrganizationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query(sort: \ProjectRecord.updatedAt, order: .reverse) private var projects: [ProjectRecord]
    @Query(sort: \OrganizationTask.updatedAt, order: .reverse) private var tasks: [OrganizationTask]
    @StateObject private var viewModel = OrganizationViewModel()
    @State private var editor: OrganizationEditor?
    @State private var deletion: OrganizationDeletion?
    @FocusState private var searchFocused: Bool

    private var selectedProject: ProjectRecord? { projects.first { $0.id == viewModel.selectedProjectID } }
    private var rows: [OrganizationTask] { guard let id = selectedProject?.id else { return [] }; return viewModel.filteredTasks(tasks, projectID: id) }

    var body: some View {
        VStack(spacing: 0) {
            TerminalHeader(titleKey: "route.organization", subtitleKey: "organization.subtitle", onBack: appState.goHome)
            HStack(spacing: 0) { projectSidebar; Divider().overlay(TerminalTokens.border); taskArea }
            if let error = viewModel.errorMessage { Label(error, systemImage: "xmark.octagon").foregroundStyle(TerminalTokens.error).padding(.horizontal, 12).frame(height: 28) }
            else { TerminalStatusBar(messageKey: viewModel.statusKey) }
        }
        .sheet(item: $editor) { value in editorView(value) }
        .confirmationDialog("delete.confirm.title", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) {
            Button("action.delete", role: .destructive) { performDelete() }; Button("action.cancel", role: .cancel) { deletion = nil }
        } message: { Text("organization.delete.message") }
        .onReceive(NotificationCenter.default.publisher(for: .nexusNewItem)) { _ in newContextItem() }
        .onReceive(NotificationCenter.default.publisher(for: .nexusFocusSearch)) { _ in searchFocused = true }
        .onAppear { if viewModel.selectedProjectID == nil { viewModel.selectedProjectID = projects.first(where: { !$0.isArchived })?.id } }
        .accessibilityIdentifier("organization.screen")
    }

    private var projectSidebar: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text("organization.projects").font(.headline); Spacer(); Button { editor = .project(nil) } label: { Image(systemName: "plus") }.buttonStyle(.plain).accessibilityLabel(Text("organization.newProject")) }
            ForEach(viewModel.filteredProjects(projects, tasks: tasks)) { project in
                let progress = viewModel.progress(tasks: tasks, projectID: project.id)
                Button { viewModel.selectedProjectID = project.id } label: {
                    VStack(alignment: .leading, spacing: 4) { HStack { Text(project.title).lineLimit(1); Spacer(); Text("\(progress.completed)/\(progress.total)").font(.caption) }; TerminalProgressBar(value: progress.ratio, labelKey: "organization.progress") }
                }.buttonStyle(.plain).padding(8).background(viewModel.selectedProjectID == project.id ? TerminalTokens.phosphor.opacity(0.14) : TerminalTokens.surface.opacity(0.35))
                    .overlay(Rectangle().stroke(viewModel.selectedProjectID == project.id ? TerminalTokens.phosphor : TerminalTokens.border.opacity(0.55)))
                    .contextMenu { Button("action.edit") { editor = .project(project.id) }; Button("action.delete", role: .destructive) { deletion = .project(project.id) } }
            }
            if projects.filter({ !$0.isArchived }).isEmpty { Text("organization.empty.projects").foregroundStyle(TerminalTokens.phosphorMuted) }
            Spacer()
        }.padding(12).frame(width: 240).background(TerminalTokens.surface.opacity(0.25))
    }

    private var taskArea: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass"); TextField("organization.search", text: $viewModel.searchText).textFieldStyle(.plain).focused($searchFocused)
                Picker("organization.status", selection: $viewModel.statusFilter) { Text("filter.all").tag(OrganizationStatus?.none); ForEach(OrganizationStatus.allCases) { Text(LocalizedStringKey($0.titleKey)).tag(Optional($0)) } }.frame(width: 140)
                Picker("organization.priority", selection: $viewModel.priorityFilter) { Text("filter.all").tag(OrganizationPriority?.none); ForEach(OrganizationPriority.allCases) { Text(LocalizedStringKey($0.titleKey)).tag(Optional($0)) } }.frame(width: 130)
                Picker("organization.sort.title", selection: $viewModel.sort) { ForEach(OrganizationSort.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }.frame(width: 130)
                Button { if let id = selectedProject?.id { editor = .task(nil, id, nil) } } label: { Label("organization.newTask", systemImage: "plus") }.buttonStyle(TerminalPrimaryButtonStyle()).disabled(selectedProject == nil)
            }.padding(.horizontal, 12).frame(height: 52).background(TerminalTokens.surface.opacity(0.35))
            if let project = selectedProject {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(project.title).font(.title3).fontWeight(.bold); Text(LocalizedStringKey(project.status.titleKey)).foregroundStyle(TerminalTokens.phosphorMuted); Spacer(); if let due = project.dueDate { Label { Text(due, style: .date) } icon: { Image(systemName: "calendar") } } }
                    Text(project.details).foregroundStyle(TerminalTokens.phosphorMuted).lineLimit(2)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                if rows.isEmpty { TerminalEmptyState(titleKey: "organization.empty.tasks.title", messageKey: "organization.empty.tasks.message", actionKey: "organization.newTask", action: { editor = .task(nil, project.id, nil) }) }
                else { taskList(project: project) }
            } else { TerminalEmptyState(titleKey: "organization.empty.projects.title", messageKey: "organization.empty.projects.message", actionKey: "organization.newProject", action: { editor = .project(nil) }) }
        }
    }

    private func taskList(project: ProjectRecord) -> some View {
        List { ForEach(rows.filter { $0.parentTaskID == nil }) { task in
            taskRow(task, indent: 0, project: project)
            ForEach(rows.filter { $0.parentTaskID == task.id }) { subtask in taskRow(subtask, indent: 1, project: project) }
        } }.listStyle(.inset).scrollContentBackground(.hidden)
    }

    private func taskRow(_ task: OrganizationTask, indent: Int, project: ProjectRecord) -> some View {
        Button { editor = .task(task.id, project.id, task.parentTaskID) } label: {
            HStack { if indent > 0 { Image(systemName: "arrow.turn.down.right").foregroundStyle(TerminalTokens.phosphorMuted) }; Image(systemName: task.status == .completed ? "checkmark.square" : "square"); VStack(alignment: .leading) { Text(task.title).fontWeight(task.priority == .critical ? .bold : .regular); Text(task.details).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted).lineLimit(1) }; Spacer(); Text(LocalizedStringKey(task.priority.titleKey)).font(.caption); if let due = task.dueDate { Text(due, style: .date).monospacedDigit() } }
        }.buttonStyle(.plain).padding(.vertical, 4).padding(.leading, CGFloat(indent * 20)).contextMenu {
            Button("action.edit") { editor = .task(task.id, project.id, task.parentTaskID) }
            if indent == 0 { Button("organization.newSubtask") { editor = .task(nil, project.id, task.id) } }
            Button("action.delete", role: .destructive) { deletion = .task(task.id) }
        }
    }

    @ViewBuilder private func editorView(_ value: OrganizationEditor) -> some View {
        switch value {
        case .project(let id): OrganizationProjectEditor(project: projects.first { $0.id == id }, viewModel: viewModel)
        case .task(let id, let projectID, let parentID): OrganizationTaskEditor(task: tasks.first { $0.id == id }, projectID: projectID, parentTaskID: parentID, potentialParents: tasks.filter { $0.projectID == projectID && $0.parentTaskID == nil && $0.id != id }, viewModel: viewModel)
        }
    }
    private func newContextItem() { if let id = selectedProject?.id { editor = .task(nil, id, nil) } else { editor = .project(nil) } }
    private func performDelete() { guard let deletion else { return }; do { switch deletion { case .project(let id): if let value = projects.first(where: { $0.id == id }) { try viewModel.deleteProject(value, tasks: tasks, context: context) }; case .task(let id): if let value = tasks.first(where: { $0.id == id }) { try viewModel.deleteTask(value, allTasks: tasks, context: context) } } } catch { viewModel.errorMessage = error.localizedDescription }; self.deletion = nil }
}

private enum OrganizationEditor: Identifiable {
    case project(UUID?)
    case task(UUID?, UUID, UUID?)

    var id: String {
        switch self {
        case .project(let id):
            "project-\(id?.uuidString ?? "new")"
        case .task(let id, let projectID, let parentID):
            "task-\(id?.uuidString ?? "new-\(projectID.uuidString)-\(parentID?.uuidString ?? "root")")"
        }
    }
}
private enum OrganizationDeletion { case project(UUID), task(UUID) }

private struct OrganizationProjectEditor: View {
    @Environment(\.modelContext) private var context; @Environment(\.dismiss) private var dismiss
    let project: ProjectRecord?; @ObservedObject var viewModel: OrganizationViewModel
    @State private var title: String; @State private var details: String; @State private var hasDue: Bool; @State private var due: Date
    @State private var priority: OrganizationPriority; @State private var status: OrganizationStatus; @State private var error: String?
    init(project: ProjectRecord?, viewModel: OrganizationViewModel) { self.project = project; self.viewModel = viewModel; _title = State(initialValue: project?.title ?? ""); _details = State(initialValue: project?.details ?? ""); _hasDue = State(initialValue: project?.dueDate != nil); _due = State(initialValue: project?.dueDate ?? .now); _priority = State(initialValue: project?.priority ?? .normal); _status = State(initialValue: project?.status ?? .planned) }
    var body: some View { TerminalWindow { TerminalDialog(titleKey: project == nil ? "organization.editor.project.new" : "organization.editor.project.edit") { TerminalForm { TextField("organization.title", text: $title); TextField("organization.details", text: $details, axis: .vertical).lineLimit(3...6); Picker("organization.priority", selection: $priority) { ForEach(OrganizationPriority.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }; Picker("organization.status", selection: $status) { ForEach(OrganizationStatus.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }; Toggle("organization.hasDeadline", isOn: $hasDue); if hasDue { DatePicker("organization.deadline", selection: $due) } }.frame(height: 360); if let error { Text(error).foregroundStyle(TerminalTokens.error) }; HStack { Spacer(); Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle()); Button("action.save") { save() }.buttonStyle(TerminalPrimaryButtonStyle()) } }.padding() }.frame(width: 560, height: 540).onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in save() } }
    private func save() { do { try viewModel.saveProject(project, title: title, details: details, dueDate: hasDue ? due : nil, priority: priority, status: status, context: context); dismiss() } catch { self.error = error.localizedDescription } }
}

private struct OrganizationTaskEditor: View {
    @Environment(\.modelContext) private var context; @Environment(\.dismiss) private var dismiss
    let task: OrganizationTask?; let projectID: UUID; let potentialParents: [OrganizationTask]; @ObservedObject var viewModel: OrganizationViewModel
    @State private var parentTaskID: UUID?; @State private var title: String; @State private var details: String; @State private var hasDue: Bool; @State private var due: Date
    @State private var priority: OrganizationPriority; @State private var status: OrganizationStatus; @State private var error: String?
    init(task: OrganizationTask?, projectID: UUID, parentTaskID: UUID?, potentialParents: [OrganizationTask], viewModel: OrganizationViewModel) { self.task = task; self.projectID = projectID; self.potentialParents = potentialParents; self.viewModel = viewModel; _parentTaskID = State(initialValue: task?.parentTaskID ?? parentTaskID); _title = State(initialValue: task?.title ?? ""); _details = State(initialValue: task?.details ?? ""); _hasDue = State(initialValue: task?.dueDate != nil); _due = State(initialValue: task?.dueDate ?? .now); _priority = State(initialValue: task?.priority ?? .normal); _status = State(initialValue: task?.status ?? .planned) }
    var body: some View { TerminalWindow { TerminalDialog(titleKey: task == nil ? "organization.editor.task.new" : "organization.editor.task.edit") { TerminalForm { TextField("organization.title", text: $title); TextField("organization.details", text: $details, axis: .vertical).lineLimit(2...5); Picker("organization.parent", selection: $parentTaskID) { Text("organization.noParent").tag(UUID?.none); ForEach(potentialParents) { Text($0.title).tag(Optional($0.id)) } }; Picker("organization.priority", selection: $priority) { ForEach(OrganizationPriority.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }; Picker("organization.status", selection: $status) { ForEach(OrganizationStatus.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }; Toggle("organization.hasDeadline", isOn: $hasDue); if hasDue { DatePicker("organization.deadline", selection: $due) } }.frame(height: 390); if let error { Text(error).foregroundStyle(TerminalTokens.error) }; HStack { Spacer(); Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle()); Button("action.save") { save() }.buttonStyle(TerminalPrimaryButtonStyle()) } }.padding() }.frame(width: 570, height: 570).onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in save() } }
    private func save() { do { try viewModel.saveTask(task, projectID: projectID, parentTaskID: parentTaskID, title: title, details: details, dueDate: hasDue ? due : nil, priority: priority, status: status, allTasks: potentialParents + (task.map { [$0] } ?? []), context: context); dismiss() } catch { self.error = error.localizedDescription } }
}
