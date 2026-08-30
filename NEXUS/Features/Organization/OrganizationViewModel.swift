import Foundation
import SwiftData

struct OrganizationProgress: Equatable {
    let completed: Int
    let total: Int
    var ratio: Double { total == 0 ? 0 : Double(completed) / Double(total) }
}

enum OrganizationSort: String, CaseIterable, Identifiable {
    case deadline, priority, title, updated
    var id: String { rawValue }
    var titleKey: String { "organization.sort.\(rawValue)" }
}

@MainActor
final class OrganizationViewModel: ObservableObject {
    @Published var selectedProjectID: UUID?
    @Published var searchText = ""
    @Published var statusFilter: OrganizationStatus?
    @Published var priorityFilter: OrganizationPriority?
    @Published var sort: OrganizationSort = .deadline
    @Published var statusKey = "status.ready"
    @Published var errorMessage: String?

    func filteredProjects(_ projects: [ProjectRecord], tasks: [OrganizationTask]) -> [ProjectRecord] {
        projects.filter { project in
            guard !project.isArchived else { return false }
            guard !searchText.isEmpty else { return true }
            return project.title.localizedCaseInsensitiveContains(searchText) || project.details.localizedCaseInsensitiveContains(searchText) ||
                tasks.contains { $0.projectID == project.id && ($0.title.localizedCaseInsensitiveContains(searchText) || $0.details.localizedCaseInsensitiveContains(searchText)) }
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func filteredTasks(_ tasks: [OrganizationTask], projectID: UUID) -> [OrganizationTask] {
        tasks.filter {
            $0.projectID == projectID &&
            (statusFilter == nil || $0.status == statusFilter) &&
            (priorityFilter == nil || $0.priority == priorityFilter) &&
            (searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) || $0.details.localizedCaseInsensitiveContains(searchText))
        }.sorted(by: taskOrder)
    }

    func progress(tasks: [OrganizationTask], projectID: UUID) -> OrganizationProgress {
        let active = tasks.filter { $0.projectID == projectID && $0.status != .cancelled }
        return OrganizationProgress(completed: active.filter { $0.status == .completed }.count, total: active.count)
    }

    func saveProject(_ project: ProjectRecord?, title: String, details: String, dueDate: Date?, priority: OrganizationPriority, status: OrganizationStatus, context: ModelContext) throws {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw OrganizationValidationError.titleRequired }
        if let project { project.title = clean; project.details = details; project.dueDate = dueDate; project.priority = priority; project.status = status; project.updatedAt = .now }
        else { let value = ProjectRecord(title: clean, details: details, dueDate: dueDate, priority: priority, status: status); context.insert(value); selectedProjectID = value.id }
        try commit(context)
    }

    func saveTask(_ task: OrganizationTask?, projectID: UUID, parentTaskID: UUID?, title: String, details: String, dueDate: Date?, priority: OrganizationPriority, status: OrganizationStatus, allTasks: [OrganizationTask] = [], context: ModelContext) throws {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw OrganizationValidationError.titleRequired }
        if let task, parentTaskID == task.id { throw OrganizationValidationError.parentCycle }
        if let parentTaskID {
            guard let parent = allTasks.first(where: { $0.id == parentTaskID }), parent.projectID == projectID else { throw OrganizationValidationError.parentCycle }
            if let task, descendantIDs(of: task.id, tasks: allTasks).contains(parentTaskID) { throw OrganizationValidationError.parentCycle }
        }
        if let task { task.projectID = projectID; task.parentTaskID = parentTaskID; task.title = clean; task.details = details; task.dueDate = dueDate; task.priority = priority; task.status = status; task.updatedAt = .now }
        else { context.insert(OrganizationTask(projectID: projectID, parentTaskID: parentTaskID, title: clean, details: details, dueDate: dueDate, priority: priority, status: status)) }
        try commit(context)
    }

    func deleteProject(_ project: ProjectRecord, tasks: [OrganizationTask], context: ModelContext) throws {
        tasks.filter { $0.projectID == project.id }.forEach(context.delete)
        context.delete(project)
        if selectedProjectID == project.id { selectedProjectID = nil }
        try commit(context)
    }

    func deleteTask(_ task: OrganizationTask, allTasks: [OrganizationTask], context: ModelContext) throws {
        let descendants = descendantIDs(of: task.id, tasks: allTasks)
        allTasks.filter { descendants.contains($0.id) }.forEach(context.delete)
        context.delete(task)
        try commit(context)
    }

    private func descendantIDs(of id: UUID, tasks: [OrganizationTask], visited: Set<UUID> = []) -> Set<UUID> {
        guard !visited.contains(id) else { return [] }
        let nextVisited = visited.union([id])
        let direct = tasks.filter { $0.parentTaskID == id }.map(\.id)
        return direct.reduce(into: Set(direct)) { result, child in result.formUnion(descendantIDs(of: child, tasks: tasks, visited: nextVisited)) }
    }

    private func taskOrder(_ left: OrganizationTask, _ right: OrganizationTask) -> Bool {
        if left.parentTaskID == right.id { return false }
        if right.parentTaskID == left.id { return true }
        switch sort {
        case .deadline: return (left.dueDate ?? .distantFuture) < (right.dueDate ?? .distantFuture)
        case .priority: return priorityRank(left.priority) > priorityRank(right.priority)
        case .title: return left.title.localizedStandardCompare(right.title) == .orderedAscending
        case .updated: return left.updatedAt > right.updatedAt
        }
    }
    private func priorityRank(_ priority: OrganizationPriority) -> Int { switch priority { case .low: 0; case .normal: 1; case .high: 2; case .critical: 3 } }
    private func commit(_ context: ModelContext) throws { do { try context.save(); errorMessage = nil; statusKey = "status.saved" } catch { errorMessage = error.localizedDescription; statusKey = "status.saveFailed"; throw error } }
}

enum OrganizationValidationError: LocalizedError {
    case titleRequired, parentCycle
    var errorDescription: String? { switch self { case .titleRequired: String(localized: "organization.validation.title"); case .parentCycle: String(localized: "organization.validation.parent") } }
}
