import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("briefing.lastAcknowledgedDay") private var lastBriefingDay = ""
    @AppStorage("security.lockTimeoutSeconds") private var lockTimeoutSeconds = 60

    var body: some View {
        ZStack {
            if appState.appLock.blocksAccess {
                AppLockView(coordinator: appState.appLock)
            } else if appState.bootSequence.isBooting {
                BootSplashView()
            } else {
                TerminalWindow {
                    ZStack {
                        if DailyPlanPresentationPolicy.showsNetworkBackdrop(
                            route: appState.route,
                            controlSystemPresented: appState.isCommandPalettePresented
                        ) {
                            DailyPlanNetworkBackdrop(reduceMotion: reduceMotion)
                        }
                        Group {
                            if let route = appState.route {
                                switch route {
                                case .study: StudyView()
                                case .attendance: AttendanceView()
                                case .gym: GymView()
                                case .finance: FinanceView()
                                case .notes: NotesView()
                                case .calendar: CalendarView()
                                case .obs: OBSView()
                                case .organization: OrganizationView()
                                }
                            } else { HomeView() }
                        }
                        .allowsHitTesting(!appState.isCommandPalettePresented)
                        .accessibilityHidden(appState.isCommandPalettePresented)
                        if appState.isCommandPalettePresented { CommandPalette() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            NotificationReconcilerView()
            if appState.appLock.privacyMaskVisible { PrivacyMaskView().zIndex(100) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onExitCommand { appState.handleEscape() }
        .background(PrimaryWindowConfigurator(transitionComplete: !appState.bootSequence.isBooting))
        .sheet(isPresented: $appState.isQuickEntryPresented) { QuickEntryView() }
        .sheet(isPresented: $appState.isMorningBriefingPresented) {
            MorningBriefingView(date: .now) { acknowledgeBriefing() }
        }
        .sheet(isPresented: $appState.isFocusModePresented, onDismiss: {
            if !appState.focusController.hasActiveSession { appState.isFocusModePresented = false }
        }) { FocusModeView(controller: appState.focusController) }
        .sheet(isPresented: Binding(get: { appState.voiceAssistant.isPanelPresented },
                                    set: { appState.voiceAssistant.isPanelPresented = $0 })) {
            VoiceAssistantPanelView().environmentObject(appState)
        }
        .onAppear {
#if DEBUG
            let isIsolatedLayoutProbe = Bundle.main.bundleIdentifier?.hasSuffix(".phase12probe") == true
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || isIsolatedLayoutProbe {
                appState.appLock.initializeForAutomatedTests()
            } else {
                appState.appLock.initialize()
            }
#else
            appState.appLock.initialize()
#endif
            appState.voiceAssistant.configure(context: modelContext, navigation: { appState.open($0) },
                                               accessAllowed: { !appState.appLock.blocksAccess })
            appState.startBoot(reduceMotion: reduceMotion, forceSkip: ProcessInfo.processInfo.arguments.contains("--skip-boot"))
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive, .background:
                appState.protectForInactiveState()
                appState.appLock.becameInactive(at: .now, timeoutSeconds: lockTimeoutSeconds)
            case .active:
                appState.appLock.becameActive(at: .now, timeoutSeconds: lockTimeoutSeconds)
                Task { await appState.notificationService.refreshStatus() }
            @unknown default: break
            }
        }
        .onChange(of: appState.appLock.state) { _, state in
            if appState.appLock.blocksAccess {
                appState.protectForInactiveState()
                appState.voiceAssistant.suspendForPrivacyLock()
            } else if state == .unlocked || state == .disabled {
                appState.voiceAssistant.resumeAfterPrivacyUnlock()
                appState.startBoot(reduceMotion: reduceMotion, forceSkip: ProcessInfo.processInfo.arguments.contains("--skip-boot"))
                presentPostBootContentIfNeeded()
            }
        }
        .onChange(of: appState.bootSequence.stage) { _, stage in
            if stage == .dashboard { presentPostBootContentIfNeeded() }
        }
    }

    private func acknowledgeBriefing() {
        lastBriefingDay = MorningBriefingAcknowledgement.dayKey(for: .now)
        appState.isMorningBriefingPresented = false
    }

    private func presentPostBootContentIfNeeded() {
        guard !appState.appLock.blocksAccess, appState.bootSequence.stage == .dashboard else { return }
        if appState.focusController.hasActiveSession { appState.isFocusModePresented = true }
        let environment = ProcessInfo.processInfo.environment
        let forceBriefing = ProcessInfo.processInfo.arguments.contains("--force-morning-briefing")
        let isAutomatedUIRun = environment["XCTestConfigurationFilePath"] != nil
        if forceBriefing || (!isAutomatedUIRun && MorningBriefingAcknowledgement.shouldPresent(lastAcknowledgedDay: lastBriefingDay, on: .now)) {
            appState.isMorningBriefingPresented = true
        }
    }
}
