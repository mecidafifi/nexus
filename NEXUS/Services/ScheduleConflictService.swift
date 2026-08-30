import Foundation
import SwiftData

struct ScheduleSlot: Equatable, Identifiable {
    let id: UUID
    let weekday: Int
    let startMinutes: Int
    let durationMinutes: Int
    var endMinutes: Int { startMinutes + durationMinutes }
}

enum ScheduleConflictService {
    static func conflicts(_ proposed: ScheduleSlot, with existing: [ScheduleSlot]) -> [ScheduleSlot] {
        existing.filter { $0.id != proposed.id && $0.weekday == proposed.weekday && proposed.startMinutes < $0.endMinutes && $0.startMinutes < proposed.endMinutes }
    }

    static func nextAvailableStart(for proposed: ScheduleSlot, existing: [ScheduleSlot], dayEndMinutes: Int = 20 * 60) -> Int? {
        var candidate = max(proposed.startMinutes, 8 * 60)
        while candidate + proposed.durationMinutes <= dayEndMinutes {
            let slot = ScheduleSlot(id: proposed.id, weekday: proposed.weekday, startMinutes: candidate, durationMinutes: proposed.durationMinutes)
            if conflicts(slot, with: existing).isEmpty { return candidate }
            candidate += 30
        }
        return nil
    }

    static func overlappingPairs(_ slots: [ScheduleSlot]) -> [(ScheduleSlot, ScheduleSlot)] {
        var pairs: [(ScheduleSlot, ScheduleSlot)] = []
        for leftIndex in slots.indices {
            for rightIndex in slots.indices where rightIndex > leftIndex {
                let left = slots[leftIndex], right = slots[rightIndex]
                if left.weekday == right.weekday && left.startMinutes < right.endMinutes && right.startMinutes < left.endMinutes { pairs.append((left, right)) }
            }
        }
        return pairs
    }
}

@MainActor
enum SemesterScheduleService {
    static func save(
        course: Course?, name: String, code: String, instructor: String, room: String,
        semesterStart: Date, semesterEnd: Date, allowedAbsences: Int, examDate: Date?,
        weekdays: Set<Int>, startMinutes: Int, durationMinutes: Int,
        existingRules: [StudyScheduleRule], context: ModelContext
    ) throws -> Course {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw StudyValidationError.emptyTitle }
        guard semesterEnd >= semesterStart else { throw StudyValidationError.invalidDateRange }
        guard !weekdays.isEmpty, weekdays.allSatisfy({ (1...7).contains($0) }), (0...1_439).contains(startMinutes), durationMinutes > 0 else { throw StudyValidationError.invalidDuration }
        let value: Course
        if let course { value = course }
        else { value = Course(name: clean); context.insert(value) }
        value.name = clean; value.code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        value.instructor = instructor.trimmingCharacters(in: .whitespacesAndNewlines); value.location = room.trimmingCharacters(in: .whitespacesAndNewlines)
        value.semesterStart = semesterStart; value.semesterEnd = semesterEnd; value.allowedAbsenceCount = max(allowedAbsences, 0); value.examDate = examDate; value.updatedAt = .now

        let courseRules = existingRules.filter { $0.courseID == value.id }
        for weekday in 1...7 {
            let matches = courseRules.filter { $0.weekday == weekday }
            if weekdays.contains(weekday) {
                if let rule = matches.first { rule.startMinutes = startMinutes; rule.durationMinutes = durationMinutes; rule.effectiveStart = semesterStart; rule.effectiveEnd = semesterEnd; rule.locationOverride = room; rule.isActive = true; rule.updatedAt = .now }
                else { context.insert(StudyScheduleRule(courseID: value.id, weekday: weekday, startMinutes: startMinutes, durationMinutes: durationMinutes, effectiveStart: semesterStart, effectiveEnd: semesterEnd, locationOverride: room)) }
            } else { matches.forEach { $0.isActive = false; $0.updatedAt = .now } }
        }
        try context.save()
        return value
    }
}
