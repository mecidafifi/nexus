import Foundation

enum AppRoute: String, CaseIterable, Identifiable, Codable {
    case study
    case attendance
    case gym
    case finance
    case notes
    case calendar
    case obs
    case organization

    var id: String { rawValue }
    var number: Int { Self.allCases.firstIndex(of: self)! + 1 }
    var titleKey: String { "route.\(rawValue)" }
    var symbol: String {
        switch self {
        case .study: "book.closed"
        case .attendance: "checkmark.rectangle.stack"
        case .gym: "figure.strengthtraining.traditional"
        case .finance: "banknote"
        case .notes: "note.text"
        case .calendar: "calendar"
        case .obs: "graduationcap"
        case .organization: "square.grid.2x2"
        }
    }
    var isAvailable: Bool { true }
}
