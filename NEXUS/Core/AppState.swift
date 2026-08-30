import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute?
    @Published var isCommandPalettePresented = false
    @Published var controlSystemMode: ControlSystemMode = .modules
    @Published var isQuickEntryPresented = false
    @Published var isMorningBriefingPresented = false
    @Published var isFocusModePresented = false
    @Published var statusKey = "status.ready"
    @Published var requestedStudySection: StudySection?
    let focusController = FocusSessionController()
    let notificationService: LocalNotificationService
    let appLock: AppLockCoordinator
    let bootSequence: BootSequenceCoordinator
    let voiceAssistant: VoiceAssistantCoordinator
    private var hasAppliedDailyPlanLaunchDefault = false
    private var cancellables: Set<AnyCancellable> = []

    init(notificationService: LocalNotificationService, appLock: AppLockCoordinator, bootSequence: BootSequenceCoordinator,
         voiceAssistant: VoiceAssistantCoordinator) {
        self.notificationService = notificationService
        self.appLock = appLock
        self.bootSequence = bootSequence
        self.voiceAssistant = voiceAssistant
        notificationService.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        appLock.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        bootSequence.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        voiceAssistant.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }

    convenience init(notificationService: LocalNotificationService, appLock: AppLockCoordinator, bootSequence: BootSequenceCoordinator) {
        self.init(notificationService: notificationService, appLock: appLock, bootSequence: bootSequence,
                  voiceAssistant: VoiceAssistantCoordinator())
    }

    convenience init() {
        self.init(notificationService: LocalNotificationService(), appLock: AppLockCoordinator(), bootSequence: BootSequenceCoordinator())
    }

    convenience init(bootSequence: BootSequenceCoordinator) {
        self.init(notificationService: LocalNotificationService(), appLock: AppLockCoordinator(), bootSequence: bootSequence)
    }

    func open(_ route: AppRoute) {
        guard !appLock.blocksAccess else { return }
        self.route = route
        isCommandPalettePresented = false
        controlSystemMode = .modules
        statusKey = route.isAvailable ? "status.moduleOpened" : "status.futureModule"
    }

    func open(number: Int) {
        guard let route = ManualNavigationPolicy.route(forNumber: number) else { return }
        open(route)
    }

    func goHome() {
        guard !appLock.blocksAccess else { return }
        route = nil
        isCommandPalettePresented = false
        controlSystemMode = .modules
        statusKey = "status.ready"
    }

    func openControlSystem(mode: ControlSystemMode = .modules) {
        guard !appLock.blocksAccess, !bootSequence.isBooting else { return }
        controlSystemMode = mode
        isCommandPalettePresented = true
    }

    func toggleControlSystem() {
        if isCommandPalettePresented { closeControlSystem() }
        else { openControlSystem() }
    }

    func closeControlSystem() {
        isCommandPalettePresented = false
        controlSystemMode = .modules
    }

    func handleEscape() {
        switch ManualNavigationPolicy.escapeDestination(controlSystemPresented: isCommandPalettePresented) {
        case .controlSystemToDashboard, .dashboard: goHome()
        }
    }

    func startBoot(reduceMotion: Bool, forceSkip: Bool = false) {
        guard !appLock.blocksAccess else { return }
        bootSequence.begin(reduceMotion: reduceMotion, forceSkip: forceSkip)
    }

    func completeBoot() {
        bootSequence.complete()
    }

    func consumeDailyPlanLaunchDefault() -> DailyPlanMode? {
        guard !hasAppliedDailyPlanLaunchDefault else { return nil }
        hasAppliedDailyPlanLaunchDefault = true
        return DailyPlanPresentationPolicy.defaultMode
    }

    func openSemesterSetup() {
        requestedStudySection = .semesterSetup
        open(.study)
    }

    func openQuickEntry() {
        guard !appLock.blocksAccess else { return }
        isCommandPalettePresented = false
        isQuickEntryPresented = true
    }

    func openMorningBriefing() {
        guard !appLock.blocksAccess else { return }
        isCommandPalettePresented = false
        isMorningBriefingPresented = true
    }

    func openVoiceAssistant() {
        guard !appLock.blocksAccess else { return }
        isCommandPalettePresented = false
        voiceAssistant.isPanelPresented = true
    }

    func startFocus(_ request: FocusRequest) {
        guard !appLock.blocksAccess else { return }
        isCommandPalettePresented = false
        _ = focusController.begin(request)
        isFocusModePresented = true
    }

    func protectForInactiveState() {
        closeControlSystem()
        isQuickEntryPresented = false
        isMorningBriefingPresented = false
        isFocusModePresented = false
        voiceAssistant.isPanelPresented = false
    }
}
