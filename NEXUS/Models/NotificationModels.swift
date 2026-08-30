import Foundation

enum NexusNotificationCategory: String, CaseIterable, Codable, Identifiable {
    case lessonStart
    case deadline
    case attendanceRisk
    case scheduleConflict

    var id: String { rawValue }
    var titleKey: String { "notifications.category.\(rawValue)" }
}

enum NotificationAuthorizationState: String, Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown

    var permitsScheduling: Bool { self == .authorized || self == .provisional || self == .ephemeral }
}

struct LocalNotificationPreferences: Equatable {
    var enabled: Bool
    var lessonStart: Bool
    var deadline: Bool
    var attendanceRisk: Bool
    var scheduleConflict: Bool
    var leadMinutes: Int
    var hideDetails: Bool

    var enabledCategories: Set<NexusNotificationCategory> {
        var values: Set<NexusNotificationCategory> = []
        if lessonStart { values.insert(.lessonStart) }
        if deadline { values.insert(.deadline) }
        if attendanceRisk { values.insert(.attendanceRisk) }
        if scheduleConflict { values.insert(.scheduleConflict) }
        return values
    }

    var normalized: LocalNotificationPreferences {
        var copy = self
        copy.leadMinutes = [5, 15, 30, 60].contains(leadMinutes) ? leadMinutes : 15
        return copy
    }

    static func current(defaults: UserDefaults = .standard) -> LocalNotificationPreferences {
        LocalNotificationPreferences(
            enabled: defaults.bool(forKey: "notifications.enabled"),
            lessonStart: defaults.object(forKey: "notifications.lessonStart") as? Bool ?? true,
            deadline: defaults.object(forKey: "notifications.deadline") as? Bool ?? true,
            attendanceRisk: defaults.object(forKey: "notifications.attendanceRisk") as? Bool ?? true,
            scheduleConflict: defaults.object(forKey: "notifications.scheduleConflict") as? Bool ?? true,
            leadMinutes: defaults.object(forKey: "notifications.leadMinutes") as? Int ?? 15,
            hideDetails: defaults.object(forKey: "notifications.hideDetails") as? Bool ?? true
        ).normalized
    }
}

struct NotificationLessonSource: Equatable {
    let occurrenceID: String
    let courseID: UUID
    let title: String
    let start: Date
    let end: Date
}

struct NotificationDeadlineSource: Equatable {
    let id: String
    let title: String
    let dueDate: Date
    let isCompleted: Bool
}

struct NotificationAttendanceRiskSource: Equatable {
    let courseID: UUID
    let courseTitle: String
    let absentCount: Int
    let allowedAbsenceCount: Int
    let nextLessonStart: Date
}

struct NotificationConflictSource: Equatable {
    let leftID: String
    let rightID: String
    let start: Date
}

struct NotificationPlanningSnapshot: Equatable {
    var lessons: [NotificationLessonSource] = []
    var deadlines: [NotificationDeadlineSource] = []
    var attendanceRisks: [NotificationAttendanceRiskSource] = []
    var conflicts: [NotificationConflictSource] = []
}

struct PlannedLocalNotification: Equatable, Identifiable {
    static let identifierPrefix = "nexus.v9."

    let id: String
    let category: NexusNotificationCategory
    let title: String
    let body: String
    let fireDate: Date
}

enum LocalNotificationPlanner {
    static func plan(
        snapshot: NotificationPlanningSnapshot,
        preferences rawPreferences: LocalNotificationPreferences,
        now: Date = .now,
        limit: Int = 60
    ) -> [PlannedLocalNotification] {
        let preferences = rawPreferences.normalized
        guard preferences.enabled else { return [] }
        let lead = TimeInterval(preferences.leadMinutes * 60)
        var planned: [PlannedLocalNotification] = []

        if preferences.lessonStart {
            planned += snapshot.lessons.compactMap { lesson in
                notification(
                    id: "lesson.\(safe(lesson.occurrenceID))", category: .lessonStart,
                    detailedTitle: lesson.title,
                    privateTitle: String(localized: "notifications.private.lesson.title"),
                    detailedBody: String(format: String(localized: "notifications.lesson.body"), preferences.leadMinutes),
                    privateBody: String(localized: "notifications.private.body"),
                    fireDate: lesson.start.addingTimeInterval(-lead), now: now, hideDetails: preferences.hideDetails
                )
            }
        }

        if preferences.deadline {
            planned += snapshot.deadlines.filter { !$0.isCompleted }.compactMap { deadline in
                notification(
                    id: "deadline.\(safe(deadline.id))", category: .deadline,
                    detailedTitle: deadline.title,
                    privateTitle: String(localized: "notifications.private.deadline.title"),
                    detailedBody: String(format: String(localized: "notifications.deadline.body"), preferences.leadMinutes),
                    privateBody: String(localized: "notifications.private.body"),
                    fireDate: deadline.dueDate.addingTimeInterval(-lead), now: now, hideDetails: preferences.hideDetails
                )
            }
        }

        if preferences.attendanceRisk {
            planned += snapshot.attendanceRisks.filter { $0.absentCount >= max($0.allowedAbsenceCount - 1, 1) }.compactMap { risk in
                notification(
                    id: "attendance.\(risk.courseID.uuidString.lowercased()).\(Int64(risk.nextLessonStart.timeIntervalSince1970))",
                    category: .attendanceRisk,
                    detailedTitle: risk.courseTitle,
                    privateTitle: String(localized: "notifications.private.attendance.title"),
                    detailedBody: String(format: String(localized: "notifications.attendance.body"), risk.absentCount, risk.allowedAbsenceCount),
                    privateBody: String(localized: "notifications.private.body"),
                    fireDate: risk.nextLessonStart.addingTimeInterval(-lead), now: now, hideDetails: preferences.hideDetails
                )
            }
        }

        if preferences.scheduleConflict {
            planned += snapshot.conflicts.compactMap { conflict in
                let ids = [safe(conflict.leftID), safe(conflict.rightID)].sorted()
                return notification(
                    id: "conflict.\(ids.joined(separator: "."))", category: .scheduleConflict,
                    detailedTitle: String(localized: "notifications.conflict.title"),
                    privateTitle: String(localized: "notifications.private.conflict.title"),
                    detailedBody: String(localized: "notifications.conflict.body"),
                    privateBody: String(localized: "notifications.private.body"),
                    fireDate: conflict.start.addingTimeInterval(-lead), now: now, hideDetails: preferences.hideDetails
                )
            }
        }

        let unique = Dictionary(planned.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return unique.values.sorted {
            if $0.fireDate != $1.fireDate { return $0.fireDate < $1.fireDate }
            return $0.id < $1.id
        }.prefix(max(limit, 0)).map { $0 }
    }

    private static func notification(
        id: String, category: NexusNotificationCategory,
        detailedTitle: String, privateTitle: String, detailedBody: String, privateBody: String,
        fireDate: Date, now: Date, hideDetails: Bool
    ) -> PlannedLocalNotification? {
        guard fireDate > now else { return nil }
        return PlannedLocalNotification(
            id: PlannedLocalNotification.identifierPrefix + id,
            category: category,
            title: hideDetails ? privateTitle : detailedTitle,
            body: hideDetails ? privateBody : detailedBody,
            fireDate: fireDate
        )
    }

    private static func safe(_ value: String) -> String {
        value.lowercased().unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }.joined()
    }
}
