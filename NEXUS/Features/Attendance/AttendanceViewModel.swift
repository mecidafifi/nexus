import Foundation
import SwiftData

struct AttendanceSummary: Equatable {
    let present: Int, absent: Int, late: Int, excused: Int, cancelled: Int, online: Int
    init(present: Int, absent: Int, late: Int, excused: Int, cancelled: Int = 0, online: Int = 0) { self.present = present; self.absent = absent; self.late = late; self.excused = excused; self.cancelled = cancelled; self.online = online }
    var held: Int { present + absent + late + online }
    var eligible: Int { held }
    var attended: Int { present + late + online }
    var percentage: Double? { eligible == 0 ? nil : Double(attended) / Double(eligible) * 100 }
}

enum AttendanceSort: String, CaseIterable, Identifiable { case newest, oldest, course; var id: String { rawValue }; var titleKey: String { "attendance.sort.\(rawValue)" } }

@MainActor
final class AttendanceViewModel: ObservableObject {
    @Published var selectedCourseID: UUID?
    @Published var searchText = ""
    @Published var statusFilter: AttendanceStatus?
    @Published var sort: AttendanceSort = .newest
    @Published var statusMessageKey = "status.ready"
    @Published var errorMessage: String?

    func summary(_ records: [AttendanceRecord], courseID: UUID? = nil) -> AttendanceSummary {
        let scoped = records.filter { courseID == nil || $0.courseID == courseID }
        return AttendanceSummary(
            present: scoped.filter { $0.status == .present }.count,
            absent: scoped.filter { $0.status == .absent }.count,
            late: scoped.filter { $0.status == .late }.count,
            excused: scoped.filter { $0.status == .excused }.count,
            cancelled: scoped.filter { $0.status == .cancelled }.count,
            online: scoped.filter { $0.status == .online }.count
        )
    }

    func isBelowThreshold(_ summary: AttendanceSummary, threshold: Double) -> Bool {
        guard let percentage = summary.percentage else { return false }
        return percentage < threshold
    }

    func remainingAbsences(_ summary: AttendanceSummary, allowed: Int) -> Int { max(allowed - summary.absent, 0) }
    func isAbsenceDanger(_ summary: AttendanceSummary, allowed: Int) -> Bool { summary.absent >= allowed && summary.absent > 0 }

    func filtered(_ records: [AttendanceRecord], courses: [Course]) -> [AttendanceRecord] {
        records.filter { record in
            let courseName = courses.first(where: { $0.id == record.courseID })?.name ?? ""
            return (selectedCourseID == nil || record.courseID == selectedCourseID) &&
                (statusFilter == nil || record.status == statusFilter) &&
                (searchText.isEmpty || record.note.localizedCaseInsensitiveContains(searchText) || courseName.localizedCaseInsensitiveContains(searchText))
        }.sorted { lhs, rhs in
            switch sort {
            case .newest: return lhs.date > rhs.date
            case .oldest: return lhs.date < rhs.date
            case .course:
                let left = courses.first(where: { $0.id == lhs.courseID })?.name ?? ""
                let right = courses.first(where: { $0.id == rhs.courseID })?.name ?? ""
                return left.localizedStandardCompare(right) == .orderedAscending
            }
        }
    }

    func save(_ record: AttendanceRecord?, courseID: UUID?, date: Date, status: AttendanceStatus, note: String, context: ModelContext) throws {
        guard let courseID else { throw AttendanceValidationError.courseRequired }
        if let record { record.courseID = courseID; record.date = date; record.status = status; record.note = note; record.updatedAt = .now }
        else { context.insert(AttendanceRecord(courseID: courseID, date: date, status: status, note: note)) }
        try commit(context)
    }

    func delete(_ record: AttendanceRecord, context: ModelContext) throws { context.delete(record); try commit(context) }

    private func commit(_ context: ModelContext) throws {
        do { try context.save(); errorMessage = nil; statusMessageKey = "status.saved" }
        catch { errorMessage = error.localizedDescription; statusMessageKey = "status.saveFailed"; throw error }
    }
}

enum AttendanceValidationError: LocalizedError {
    case courseRequired
    var errorDescription: String? { String(localized: "attendance.validation.course") }
}
