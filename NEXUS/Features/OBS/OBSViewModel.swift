import Foundation
import SwiftData

enum OBSSection: String, CaseIterable, Identifiable { case overview, courses, assessments, gradeScale; var id: String { rawValue }; var titleKey: String { "obs.section.\(rawValue)" }; var symbol: String { switch self { case .overview: "chart.bar"; case .courses: "graduationcap"; case .assessments: "doc.text"; case .gradeScale: "ruler" } } }
enum OBSSort: String, CaseIterable, Identifiable { case date, course, title; var id: String { rawValue }; var titleKey: String { "obs.sort.\(rawValue)" } }

struct OBSGPAResult: Equatable { let gpa: Double; let gradedCredits: Double }

@MainActor
final class OBSViewModel: ObservableObject {
    @Published var section: OBSSection = .overview
    @Published var searchText = ""
    @Published var selectedCourseID: UUID?
    @Published var kindFilter: AssessmentKind?
    @Published var sort: OBSSort = .date
    @Published var statusMessageKey = "status.ready"
    @Published var errorMessage: String?

    func courseAverage(courseID: UUID, assessments: [OBSAssessment]) -> Double? {
        let graded = assessments.filter { $0.universityCourseID == courseID && $0.earnedPoints != nil && $0.maximumPoints > 0 }
        guard !graded.isEmpty else { return nil }
        let weighted = graded.filter { $0.weightPercent > 0 }
        if !weighted.isEmpty {
            let totalWeight = weighted.reduce(0) { $0 + $1.weightPercent }
            guard totalWeight > 0 else { return nil }
            return weighted.reduce(0) { $0 + (($1.earnedPoints! / $1.maximumPoints) * 100 * $1.weightPercent) } / totalWeight
        }
        return graded.reduce(0) { $0 + ($1.earnedPoints! / $1.maximumPoints * 100) } / Double(graded.count)
    }

    func weightedOverall(courses: [UniversityCourse], assessments: [OBSAssessment]) -> Double? {
        let values = courses.compactMap { course -> (Double, Double)? in guard let average = courseAverage(courseID: course.id, assessments: assessments), course.creditHours > 0 else { return nil }; return (average, course.creditHours) }
        let credits = values.reduce(0) { $0 + $1.1 }; guard credits > 0 else { return nil }
        return values.reduce(0) { $0 + $1.0 * $1.1 } / credits
    }

    func gradeBand(for percentage: Double, bands: [GradeScaleBand]) -> GradeScaleBand? {
        bands.filter { percentage >= $0.minimumPercent }.max { $0.minimumPercent < $1.minimumPercent }
    }

    func gpa(courses: [UniversityCourse], assessments: [OBSAssessment], bands: [GradeScaleBand]) -> OBSGPAResult? {
        guard !bands.isEmpty else { return nil }
        let values = courses.compactMap { course -> (Double, Double)? in
            guard course.creditHours > 0, let average = courseAverage(courseID: course.id, assessments: assessments), let band = gradeBand(for: average, bands: bands) else { return nil }
            return (band.gradePoints, course.creditHours)
        }
        let credits = values.reduce(0) { $0 + $1.1 }; guard credits > 0 else { return nil }
        return OBSGPAResult(gpa: values.reduce(0) { $0 + $1.0 * $1.1 } / credits, gradedCredits: credits)
    }

    func upcoming(_ assessments: [OBSAssessment], now: Date = .now) -> [OBSAssessment] {
        assessments.filter { $0.earnedPoints == nil && $0.dueDate >= Calendar.current.startOfDay(for: now) }.sorted { $0.dueDate < $1.dueDate }
    }

    func filteredCourses(_ courses: [UniversityCourse]) -> [UniversityCourse] { courses.filter { (selectedCourseID == nil || $0.id == selectedCourseID) && (searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) || $0.code.localizedCaseInsensitiveContains(searchText) || $0.semester.localizedCaseInsensitiveContains(searchText)) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }

    func filteredAssessments(_ assessments: [OBSAssessment], courses: [UniversityCourse]) -> [OBSAssessment] {
        assessments.filter { value in let courseName = courses.first(where: { $0.id == value.universityCourseID })?.name ?? ""; return (selectedCourseID == nil || value.universityCourseID == selectedCourseID) && (kindFilter == nil || value.kind == kindFilter) && (searchText.isEmpty || value.title.localizedCaseInsensitiveContains(searchText) || courseName.localizedCaseInsensitiveContains(searchText)) }.sorted { lhs, rhs in
            switch sort { case .date: lhs.dueDate < rhs.dueDate; case .title: lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending; case .course: (courses.first(where: { $0.id == lhs.universityCourseID })?.name ?? "") < (courses.first(where: { $0.id == rhs.universityCourseID })?.name ?? "") }
        }
    }

    func saveCourse(_ course: UniversityCourse?, name: String, code: String, semester: String, creditHours: Double, linkedStudyCourseID: UUID?, isActive: Bool, context: ModelContext) throws {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !clean.isEmpty else { throw OBSValidationError.titleRequired }; guard creditHours > 0 else { throw OBSValidationError.invalidCredits }
        if let course { course.name = clean; course.code = code; course.semester = semester; course.creditHours = creditHours; course.linkedStudyCourseID = linkedStudyCourseID; course.isActive = isActive; course.updatedAt = .now }
        else { context.insert(UniversityCourse(name: clean, code: code, semester: semester, creditHours: creditHours, linkedStudyCourseID: linkedStudyCourseID, isActive: isActive)) }
        try commit(context)
    }

    func saveAssessment(_ assessment: OBSAssessment?, courseID: UUID?, title: String, kind: AssessmentKind, dueDate: Date, maximumPoints: Double, earnedPoints: Double?, weightPercent: Double, note: String, context: ModelContext) throws {
        guard let courseID else { throw OBSValidationError.courseRequired }; let clean = title.trimmingCharacters(in: .whitespacesAndNewlines); guard !clean.isEmpty else { throw OBSValidationError.titleRequired }; guard maximumPoints > 0 else { throw OBSValidationError.invalidMaximum }; guard (0...100).contains(weightPercent) else { throw OBSValidationError.invalidWeight }; if let earnedPoints, !(0...maximumPoints).contains(earnedPoints) { throw OBSValidationError.invalidScore }
        if let assessment { assessment.universityCourseID = courseID; assessment.title = clean; assessment.kind = kind; assessment.dueDate = dueDate; assessment.maximumPoints = maximumPoints; assessment.earnedPoints = earnedPoints; assessment.weightPercent = weightPercent; assessment.note = note; assessment.updatedAt = .now }
        else { context.insert(OBSAssessment(universityCourseID: courseID, title: clean, kind: kind, dueDate: dueDate, maximumPoints: maximumPoints, earnedPoints: earnedPoints, weightPercent: weightPercent, note: note)) }
        try commit(context)
    }

    func saveBand(_ band: GradeScaleBand?, letter: String, minimum: Double, points: Double, existing: [GradeScaleBand], context: ModelContext) throws {
        let clean = letter.trimmingCharacters(in: .whitespacesAndNewlines); guard !clean.isEmpty else { throw OBSValidationError.titleRequired }; guard (0...100).contains(minimum), points >= 0 else { throw OBSValidationError.invalidBand }; guard !existing.contains(where: { $0.id != band?.id && abs($0.minimumPercent - minimum) < 0.0001 }) else { throw OBSValidationError.duplicateBand }
        if let band { band.letter = clean; band.minimumPercent = minimum; band.gradePoints = points } else { context.insert(GradeScaleBand(letter: clean, minimumPercent: minimum, gradePoints: points)) }
        try commit(context)
    }

    func deleteCourse(_ course: UniversityCourse, assessments: [OBSAssessment], context: ModelContext) throws { assessments.filter { $0.universityCourseID == course.id }.forEach(context.delete); context.delete(course); try commit(context) }
    func delete<T: PersistentModel>(_ value: T, context: ModelContext) throws { context.delete(value); try commit(context) }
    private func commit(_ context: ModelContext) throws { do { try context.save(); errorMessage = nil; statusMessageKey = "status.saved" } catch { errorMessage = error.localizedDescription; statusMessageKey = "status.saveFailed"; throw error } }
}

enum OBSValidationError: LocalizedError {
    case titleRequired, courseRequired, invalidCredits, invalidMaximum, invalidWeight, invalidScore, invalidBand, duplicateBand
    var errorDescription: String? { switch self {
    case .titleRequired: String(localized: "validation.titleRequired"); case .courseRequired: String(localized: "obs.validation.course"); case .invalidCredits: String(localized: "obs.validation.credits"); case .invalidMaximum: String(localized: "obs.validation.maximum"); case .invalidWeight: String(localized: "obs.validation.weight"); case .invalidScore: String(localized: "obs.validation.score"); case .invalidBand: String(localized: "obs.validation.band"); case .duplicateBand: String(localized: "obs.validation.duplicateBand")
    } }
}
