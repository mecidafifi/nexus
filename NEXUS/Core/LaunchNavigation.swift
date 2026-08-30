import Foundation

enum LaunchStage: Equatable {
    case booting
    case dashboard
}

struct BootPresentationPolicy {
    static let standardDuration: TimeInterval = 2.4
    static let reducedMotionDuration: TimeInterval = 0.35

    static func duration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? reducedMotionDuration : standardDuration
    }
}

@MainActor
final class BootSequenceCoordinator: ObservableObject {
    @Published private(set) var stage: LaunchStage = .booting
    @Published private(set) var hasStarted = false
    private var transitionTask: Task<Void, Never>?

    var isBooting: Bool { stage == .booting }

    func begin(reduceMotion: Bool, forceSkip: Bool = false) {
        guard !hasStarted else { return }
        hasStarted = true
        guard !forceSkip else { complete(); return }
        let delay = BootPresentationPolicy.duration(reduceMotion: reduceMotion)
        transitionTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) }
            catch { return }
            guard !Task.isCancelled else { return }
            self?.complete()
        }
    }

    func complete() {
        transitionTask?.cancel()
        transitionTask = nil
        stage = .dashboard
    }
}

enum ControlSystemMode: Equatable {
    case modules
    case search
}

enum EscapeDestination: Equatable {
    case controlSystemToDashboard
    case dashboard
}

enum ControlSystemDestination: Equatable {
    case route(AppRoute)
    case settings
}

struct ManualNavigationPolicy {
    private static let numberByMacKeyCode: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9,
        83: 1, 84: 2, 85: 3, 86: 4, 87: 5, 88: 6, 89: 7, 91: 8, 92: 9
    ]

    static func route(forNumber number: Int) -> AppRoute? {
        AppRoute.allCases.first { $0.number == number }
    }

    static func controlDestination(forNumber number: Int) -> ControlSystemDestination? {
        if number == 9 { return .settings }
        return route(forNumber: number).map(ControlSystemDestination.route)
    }

    static func controlNumber(forMacKeyCode keyCode: UInt16) -> Int? {
        numberByMacKeyCode[keyCode]
    }

    static func escapeDestination(controlSystemPresented: Bool) -> EscapeDestination {
        controlSystemPresented ? .controlSystemToDashboard : .dashboard
    }
}
