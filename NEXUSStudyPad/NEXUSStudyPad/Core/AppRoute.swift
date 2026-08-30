import SwiftUI

enum AppRoute: String, CaseIterable, Identifiable {
    case today, courses, documents, notes, lectures, tasks, transfer
    var id: String { rawValue }
    var titleText: String {
        switch self {
        case .today: "Bugün"
        case .courses: "Dersler"
        case .documents: "Belgeler"
        case .notes: "Notlar"
        case .lectures: "Oturumlar"
        case .tasks: "Görevler"
        case .transfer: "Mac'ten aktar"
        }
    }
    var title: LocalizedStringKey { LocalizedStringKey(titleText) }
    var icon: String {
        switch self {
        case .today: "calendar.day.timeline.left"
        case .courses: "books.vertical"
        case .documents: "doc.richtext"
        case .notes: "note.text"
        case .lectures: "person.wave.2"
        case .tasks: "checklist"
        case .transfer: "square.and.arrow.down.on.square"
        }
    }
}
