import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("appearance.scanlines") private var scanlines = true
    @AppStorage("appearance.glow") private var glow = true
    @AppStorage("appearance.highContrast") private var highContrast = false
    @AppStorage("appearance.textScale") private var textScale = 1.0
    @AppStorage("appearance.motion") private var motion = true
    @AppStorage("notifications.enabled") private var notificationsEnabled = false
    @AppStorage("notifications.lessonStart") private var lessonNotifications = true
    @AppStorage("notifications.deadline") private var deadlineNotifications = true
    @AppStorage("notifications.attendanceRisk") private var attendanceNotifications = true
    @AppStorage("notifications.scheduleConflict") private var conflictNotifications = true
    @AppStorage("notifications.leadMinutes") private var notificationLeadMinutes = 15
    @AppStorage("notifications.hideDetails") private var hideNotificationDetails = true
    @AppStorage("security.lockTimeoutSeconds") private var lockTimeoutSeconds = 60
    @AppStorage("security.privacyMask") private var privacyMask = true
    @AppStorage("planning.conflictWarnings") private var conflictWarnings = true
    @AppStorage("planner.workStartMinutes") private var plannerWorkStart = 480
    @AppStorage("planner.workEndMinutes") private var plannerWorkEnd = 1200
    @AppStorage("planner.bufferMinutes") private var plannerBuffer = 10
    @AppStorage("planner.defaultDurationMinutes") private var plannerDefaultDuration = 45
    @AppStorage("eveningReview.endMinutes") private var eveningReviewEndMinutes = 1_200
    @State private var showsNotificationExplanation = false
    @State private var escapeMonitor: Any?

    var body: some View {
        Group {
            if appState.appLock.blocksAccess {
                AppLockView(coordinator: appState.appLock)
            } else {
                settingsContent
            }
        }
        .frame(width: 690, height: 820)
        .onAppear { installEscapeMonitor() }
        .onDisappear { removeEscapeMonitor() }
        .task { await appState.notificationService.refreshStatus() }
        .sheet(isPresented: $showsNotificationExplanation) {
            NotificationOptInExplanationView(preferences: currentNotificationPreferences) {
                showsNotificationExplanation = false
                NotificationCenter.default.post(name: .nexusNotificationEnableRequested, object: nil)
            }
        }
        .onReceive(appState.notificationService.$authorizationState) { state in
            if state.permitsScheduling { notificationsEnabled = true }
            if state == .denied { notificationsEnabled = false }
        }
        .onExitCommand { closeNativeSettingsWindow() }
    }

    private var settingsContent: some View {
        TerminalWindow {
            TerminalForm {
                Section("settings.appearance") {
                    Toggle("settings.scanlines", isOn: $scanlines)
                    Toggle("settings.glow", isOn: $glow)
                    Toggle("settings.motion", isOn: $motion)
                    Toggle("settings.highContrast", isOn: $highContrast)
                    Slider(value: $textScale, in: 0.9...1.3, step: 0.05) { Text("settings.textScale") }
                }
                Section("settings.privacy") {
                    LabeledContent("settings.storage", value: String(localized: "settings.storage.local"))
                    Text("settings.permissions.phase9").foregroundStyle(TerminalTokens.phosphorMuted)
                }
                VoiceSettingsView()
                notificationSection
                lockSection
                Section("settings.planner") {
                    Stepper(value: $plannerWorkStart, in: 0...1_380, step: 30) { LabeledContent("settings.planner.workStart", value: clock(plannerWorkStart)) }
                    Stepper(value: $plannerWorkEnd, in: max(plannerWorkStart + 30, 30)...1_440, step: 30) { LabeledContent("settings.planner.workEnd", value: clock(plannerWorkEnd)) }
                    Stepper(value: $plannerBuffer, in: 0...120, step: 5) { LabeledContent("settings.planner.buffer", value: String(format: String(localized: "format.minutes"), plannerBuffer)) }
                    Stepper(value: $plannerDefaultDuration, in: 10...360, step: 5) { LabeledContent("settings.planner.defaultDuration", value: String(format: String(localized: "format.minutes"), plannerDefaultDuration)) }
                    Text("settings.planner.help").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
                }
                Section("settings.eveningReview") {
                    Stepper(value: $eveningReviewEndMinutes, in: 1_020...1_410, step: 30) {
                        LabeledContent("settings.eveningReview.time", value: clock(eveningReviewEndMinutes))
                    }
                    Text("settings.eveningReview.help").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
                }
                Section("settings.language") {
                    LabeledContent("settings.language.default", value: String(localized: "language.turkish"))
                    Text("settings.language.future").foregroundStyle(TerminalTokens.phosphorMuted)
                }
                Section("settings.futureBoundary") {
                    Text("settings.futureFeatures").foregroundStyle(TerminalTokens.phosphorMuted)
                }
            }
        }
        .accessibilityIdentifier("settings.phase9.screen")
    }

    private var notificationSection: some View {
        Section("settings.notifications") {
            LabeledContent("notifications.permission", value: authorizationLabel)
            LabeledContent("notifications.pending", value: "\(appState.notificationService.scheduledCount)")
            Text("notifications.explanation").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            if notificationsEnabled {
                Label("notifications.enabled", systemImage: "checkmark.circle")
                    .foregroundStyle(TerminalTokens.success)
            } else {
                Button("notifications.enable") { showsNotificationExplanation = true }
                    .buttonStyle(TerminalPrimaryButtonStyle())
                    .disabled(appState.notificationService.isWorking)
            }
            Toggle("notifications.category.lessonStart", isOn: $lessonNotifications)
            Toggle("notifications.category.deadline", isOn: $deadlineNotifications)
            Toggle("notifications.category.attendanceRisk", isOn: $attendanceNotifications)
            Toggle("notifications.category.scheduleConflict", isOn: $conflictNotifications)
            Picker("settings.notifications.leadTime", selection: $notificationLeadMinutes) {
                ForEach([5, 15, 30, 60], id: \.self) { Text(String(format: String(localized: "format.minutes"), $0)).tag($0) }
            }
            Toggle("notifications.hideDetails", isOn: $hideNotificationDetails)
                .disabled(appState.appLock.isEnabled)
            Text("notifications.hideDetails.help").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            HStack {
                Button("notifications.reschedule") { NotificationCenter.default.post(name: .nexusNotificationRescheduleRequested, object: nil) }
                    .buttonStyle(TerminalButtonStyle()).disabled(!notificationsEnabled)
                Button("notifications.disable") {
                    notificationsEnabled = false
                    Task { await appState.notificationService.disableAndCancel() }
                }.buttonStyle(TerminalButtonStyle()).disabled(!notificationsEnabled)
            }
            Text(LocalizedStringKey(appState.notificationService.auditMessageKey)).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            if let error = appState.notificationService.errorMessage { Text(error).font(.caption).foregroundStyle(TerminalTokens.error) }
            Text("notifications.systemRevokeHelp").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
        }
        .onChange(of: notificationPreferenceFingerprint) { _, _ in
            if appState.appLock.isEnabled { hideNotificationDetails = true }
            NotificationCenter.default.post(name: .nexusNotificationSettingsChanged, object: nil)
        }
    }

    private var lockSection: some View {
        Section("lock.settings.title") {
            Text("lock.settings.explanation").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            LabeledContent("lock.settings.status", value: lockStatusLabel)
            if appState.appLock.isEnabled {
                Picker("lock.timeout", selection: $lockTimeoutSeconds) {
                    Text("lock.timeout.immediate").tag(0)
                    Text("lock.timeout.minute").tag(60)
                    Text("lock.timeout.fiveMinutes").tag(300)
                    Text("lock.timeout.fifteenMinutes").tag(900)
                }
                Toggle("lock.privacyMask.toggle", isOn: $privacyMask)
                HStack {
                    Button("lock.lockNow") { appState.appLock.lockNow() }.buttonStyle(TerminalButtonStyle())
                    Button("lock.disable") { appState.appLock.disable() }.buttonStyle(TerminalButtonStyle())
                }
            } else {
                Button("lock.enable") { Task { await appState.appLock.enable() } }
                    .buttonStyle(TerminalPrimaryButtonStyle())
            }
            Text("lock.keychainHelp").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            Text("lock.noPasswordFallback").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            if let error = appState.appLock.errorMessage { Text(error).font(.caption).foregroundStyle(TerminalTokens.error) }
        }
    }

    private var notificationPreferenceFingerprint: String {
        "\(notificationsEnabled)|\(lessonNotifications)|\(deadlineNotifications)|\(attendanceNotifications)|\(conflictNotifications)|\(notificationLeadMinutes)|\(hideNotificationDetails)|\(appState.appLock.isEnabled)"
    }

    private var currentNotificationPreferences: LocalNotificationPreferences {
        LocalNotificationPreferences(
            enabled: notificationsEnabled, lessonStart: lessonNotifications, deadline: deadlineNotifications,
            attendanceRisk: attendanceNotifications, scheduleConflict: conflictNotifications,
            leadMinutes: notificationLeadMinutes, hideDetails: hideNotificationDetails || appState.appLock.isEnabled
        )
    }

    private var authorizationLabel: String {
        switch appState.notificationService.authorizationState {
        case .notDetermined: String(localized: "notifications.status.notDetermined")
        case .denied: String(localized: "notifications.status.denied")
        case .authorized, .provisional, .ephemeral: String(localized: "notifications.status.authorized")
        case .unknown: String(localized: "notifications.status.unknown")
        }
    }

    private var lockStatusLabel: String {
        switch appState.appLock.state {
        case .initializing: String(localized: "lock.status.initializing")
        case .disabled: String(localized: "lock.status.disabled")
        case .unlocked: String(localized: "lock.status.enabled")
        case .locked: String(localized: "lock.status.locked")
        case .authenticating: String(localized: "lock.authenticating")
        case .unavailable: String(localized: "lock.status.unavailable")
        }
    }

    private func clock(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }

    private func closeNativeSettingsWindow() {
        guard NSApp.keyWindow?.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" else { return }
        NSApp.keyWindow?.close()
    }

    private func installEscapeMonitor() {
        removeEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let disallowedModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift, .function]
            guard event.keyCode == 53,
                  event.modifierFlags.intersection(disallowedModifiers).isEmpty
            else { return event }
            closeNativeSettingsWindow()
            return nil
        }
    }

    private func removeEscapeMonitor() {
        guard let escapeMonitor else { return }
        NSEvent.removeMonitor(escapeMonitor)
        self.escapeMonitor = nil
    }
}

private struct NotificationOptInExplanationView: View {
    @Environment(\.dismiss) private var dismiss
    let preferences: LocalNotificationPreferences
    let enable: () -> Void

    var body: some View {
        TerminalWindow {
            TerminalDialog(titleKey: "notifications.optIn.title") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("notifications.optIn.message")
                    if preferences.lessonStart { Label("notifications.optIn.lesson", systemImage: "book") }
                    if preferences.deadline { Label("notifications.optIn.deadline", systemImage: "calendar.badge.exclamationmark") }
                    if preferences.attendanceRisk { Label("notifications.optIn.attendance", systemImage: "person.badge.clock") }
                    if preferences.scheduleConflict { Label("notifications.optIn.conflict", systemImage: "exclamationmark.triangle") }
                    if preferences.enabledCategories.isEmpty {
                        Label("notifications.optIn.noneSelected", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(TerminalTokens.warning)
                    }
                    Text("notifications.optIn.localOnly").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
                    Text("notifications.optIn.noAutomaticRequest").font(.caption).foregroundStyle(TerminalTokens.warning)
                    HStack {
                        Spacer()
                        Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle())
                        Button("notifications.requestPermission") { enable() }.buttonStyle(TerminalPrimaryButtonStyle())
                            .keyboardShortcut(.return, modifiers: [])
                            .disabled(preferences.enabledCategories.isEmpty)
                    }
                }
            }.padding()
        }
        .frame(width: 620, height: 500)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notifications.optIn")
    }
}
