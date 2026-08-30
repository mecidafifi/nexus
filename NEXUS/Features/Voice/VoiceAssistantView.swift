import SwiftUI

struct VoiceOrbView: View {
    let state: VoiceAssistantState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isActive: Bool {
        switch state { case .activeListening, .processing, .speaking: true; default: false }
    }

    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .stroke(TerminalTokens.phosphor.opacity(0.24), lineWidth: 1)
                    .scaleEffect(reduceMotion ? 1 : 1.14)
                    .opacity(reduceMotion ? 0.45 : 0.75)
            }
            BootNetworkCore(reduceMotion: reduceMotion || !isActive)
                .scaleEffect(1.7)
        }
        .frame(width: 132, height: 132)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct VoiceAssistantPanelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var groundedQuestion = ""

    private var coordinator: VoiceAssistantCoordinator { appState.voiceAssistant }

    var body: some View {
        TerminalWindow {
            VStack(spacing: 0) {
                ZStack(alignment: .trailing) {
                    TerminalHeader(titleKey: "voice.title", subtitleKey: coordinator.statusKey)
                    Button("action.close") { dismiss() }
                        .buttonStyle(TerminalButtonStyle())
                        .padding(.trailing, 16)
                }
                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 10) {
                        VoiceOrbView(state: coordinator.state)
                        Label(LocalizedStringKey(coordinator.statusKey), systemImage: coordinator.statusSymbol)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(statusColor)
                        Text(String(format: String(localized: "voice.wakePhrase.waiting"), coordinator.wakePhrase))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(TerminalTokens.phosphorMuted)
                            .multilineTextAlignment(.center)
                        Button("voice.pushToTalk") { coordinator.beginPushToTalk() }
                            .buttonStyle(TerminalPrimaryButtonStyle())
                            .keyboardShortcut(.space, modifiers: [.command, .shift])
                            .disabled(!coordinator.isEnabled)
                        Button("voice.hardOff") { coordinator.hardOff() }
                            .buttonStyle(TerminalButtonStyle())
                            .disabled(!coordinator.isEnabled)
                    }
                    .frame(width: 190)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("voice.history.title").font(.system(.headline, design: .monospaced))
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    if coordinator.messages.isEmpty {
                                        Text("voice.history.empty").foregroundStyle(TerminalTokens.phosphorMuted)
                                    }
                                    ForEach(coordinator.messages.suffix(30)) { message in
                                        VoiceMessageRow(message: message).id(message.id)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .onChange(of: coordinator.messages.count) { _, _ in
                                if let last = coordinator.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .frame(minHeight: 250)
                        HStack {
                            TextField("voice.text.placeholder", text: Binding(
                                get: { coordinator.draftText },
                                set: { coordinator.draftText = $0 }
                            ))
                                .textFieldStyle(.plain)
                                .onSubmit { coordinator.submitText() }
                                .accessibilityIdentifier("voice.textInput")
                            Button("voice.sendQuestion") { coordinator.submitText() }
                                .buttonStyle(TerminalPrimaryButtonStyle())
                                .disabled(coordinator.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        HStack {
                            Label("voice.action.safeDraftHelp", systemImage: "checkmark.shield")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(TerminalTokens.phosphorMuted)
                            Spacer()
                            Button("voice.action.undo") { coordinator.undoLastVoiceAction() }
                                .buttonStyle(TerminalButtonStyle())
                                .disabled(!coordinator.canUndoVoiceAction)
                                .accessibilityHint(Text("voice.action.undo.help"))
                        }
                        Text("voice.questionTransmissionHelp")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(TerminalTokens.phosphorMuted)

                        if let report = coordinator.lastLocalReport {
                            Divider().overlay(TerminalTokens.border)
                            Text("voice.grounded.title").font(.system(.subheadline, design: .monospaced))
                            TextField("voice.grounded.questionPlaceholder", text: $groundedQuestion)
                                .textFieldStyle(.plain)
                            Button("voice.grounded.prepare") {
                                let question = groundedQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                                coordinator.prepareGroundedRemoteQuestion(question.isEmpty ? String(localized: "voice.grounded.defaultQuestion") : question, report: report)
                            }
                            .buttonStyle(TerminalButtonStyle())
                            .disabled(!coordinator.isAPIKeySaved)
                            Text("voice.grounded.defaultDeny")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(TerminalTokens.warning)
                        }
                    }
                }
                .padding(18)
                TerminalStatusBar(messageKey: "voice.statusBar")
            }
        }
        .frame(minWidth: 780, idealWidth: 860, minHeight: 560, idealHeight: 650)
        .accessibilityIdentifier("voice.assistant.screen")
        .sheet(item: Binding(
            get: { appState.voiceAssistant.pendingConsent },
            set: { appState.voiceAssistant.pendingConsent = $0 }
        )) { consent in
            VoiceDataConsentView(consent: consent)
                .environmentObject(appState)
        }
        .sheet(item: Binding(
            get: { appState.voiceAssistant.pendingAction },
            set: { if let value = $0 { appState.voiceAssistant.updatePendingAction(value) } }
        )) { draft in
            VoiceActionDraftView(draft: draft).environmentObject(appState)
        }
        .sheet(item: Binding(
            get: { appState.voiceAssistant.pendingDraftInterpretationConsent },
            set: { appState.voiceAssistant.pendingDraftInterpretationConsent = $0 }
        )) { consent in
            VoiceDraftInterpretationConsentView(consent: consent).environmentObject(appState)
        }
    }

    private var statusColor: Color {
        switch coordinator.state {
        case .error, .needsPermission, .locked: TerminalTokens.warning
        case .activeListening, .processing, .speaking: TerminalTokens.success
        default: TerminalTokens.phosphorMuted
        }
    }
}

private struct VoiceMessageRow: View {
    let message: VoiceConversationMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(LocalizedStringKey("voice.message.\(message.source.rawValue)"))
                    .font(.system(.caption2, design: .monospaced).bold())
                Spacer()
                if message.wasTransmitted {
                    Label("voice.message.transmitted", systemImage: "network")
                        .font(.caption2).foregroundStyle(TerminalTokens.warning)
                } else {
                    Label("voice.message.localOnly", systemImage: "internaldrive")
                        .font(.caption2).foregroundStyle(TerminalTokens.success)
                }
            }
            Text(message.text).textSelection(.enabled)
            if !message.scopes.isEmpty {
                Text(message.scopes.sorted { $0.rawValue < $1.rawValue }.map { String(localized: String.LocalizationValue($0.titleKey)) }.joined(separator: " • "))
                    .font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted)
            }
        }
        .padding(8)
        .background(TerminalTokens.surface.opacity(0.72))
        .overlay(Rectangle().stroke(TerminalTokens.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct VoiceDataConsentView: View {
    @EnvironmentObject private var appState: AppState
    let consent: VoiceRemoteConsent

    var body: some View {
        TerminalWindow {
            VStack(alignment: .leading, spacing: 14) {
                TerminalHeader(titleKey: "voice.consent.title", subtitleKey: "voice.consent.subtitle")
                Label("voice.consent.warning", systemImage: "exclamationmark.shield")
                    .foregroundStyle(TerminalTokens.warning)
                Text("voice.consent.scopes").font(.headline)
                ForEach(consent.report.scopes.sorted { $0.rawValue < $1.rawValue }) { scope in
                    Label(LocalizedStringKey(scope.titleKey), systemImage: "checkmark.square")
                }
                Text("voice.consent.exactPayload").font(.headline)
                ScrollView {
                    Text(consent.report.transmissionPreview)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .overlay(Rectangle().stroke(TerminalTokens.border))
                Text(String(format: String(localized: "voice.consent.question"), consent.question))
                    .textSelection(.enabled)
                HStack {
                    Button("voice.consent.deny") { appState.voiceAssistant.denyPendingConsent() }
                        .buttonStyle(TerminalButtonStyle())
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("voice.consent.allowOnce") { appState.voiceAssistant.approvePendingConsent() }
                        .buttonStyle(TerminalPrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(22)
        }
        .frame(width: 650, height: 570)
        .accessibilityIdentifier("voice.dataConsent")
    }
}

struct VoiceMenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VoiceOrbView(state: appState.voiceAssistant.state).frame(width: 54, height: 54)
                VStack(alignment: .leading) {
                    Text("voice.menu.title").font(.system(.headline, design: .monospaced))
                    Label(LocalizedStringKey(appState.voiceAssistant.statusKey), systemImage: appState.voiceAssistant.statusSymbol)
                        .font(.caption)
                }
            }
            Button("voice.menu.openAssistant") {
                appState.voiceAssistant.isPanelPresented = true
                openWindow(id: "main")
            }
            .keyboardShortcut("v")
            Button("voice.pushToTalk") {
                appState.voiceAssistant.beginPushToTalk()
            }
            .disabled(!appState.voiceAssistant.isEnabled || appState.appLock.blocksAccess)
            Divider()
            Button("voice.menu.openNexus") { openWindow(id: "main") }
            Button("voice.hardOff") { appState.voiceAssistant.hardOff() }
                .disabled(!appState.voiceAssistant.isEnabled)
            Divider()
            Text("voice.menu.backgroundNote").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
        }
        .padding(14)
        .frame(width: 330)
        .accessibilityIdentifier("voice.menuBar")
    }
}

struct VoiceMenuBarLabel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            VoiceOrbView(state: appState.voiceAssistant.state)
                .scaleEffect(0.14)
                .frame(width: 18, height: 18)
            Text("NEXUS")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("voice.menu.title"))
        .accessibilityValue(Text(LocalizedStringKey(appState.voiceAssistant.statusKey)))
    }
}

struct VoiceSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("voice.openAIModel") private var model = "gpt-5-mini"
    @State private var wakePhrase = ""
    @State private var apiKey = ""
    @State private var error: String?
    @State private var showsEnableExplanation = false
    @State private var recognitionLocale = "tr-TR"

    private var coordinator: VoiceAssistantCoordinator { appState.voiceAssistant }

    var body: some View {
        Section("voice.settings.title") {
            LabeledContent("voice.settings.status", value: String(localized: String.LocalizationValue(coordinator.statusKey)))
            LabeledContent("voice.permission.microphone", value: permissionLabel(coordinator.microphonePermission))
            LabeledContent("voice.permission.speech", value: permissionLabel(coordinator.speechPermission))
            Text("voice.settings.localWakeHelp").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            Picker("voice.recognition.language", selection: $recognitionLocale) {
                Text("voice.recognition.turkish").tag("tr-TR")
                Text("voice.recognition.arabic").tag("ar-SA")
            }
            .onChange(of: recognitionLocale) { oldValue, newValue in
                guard oldValue != newValue else { return }
                if !coordinator.updateRecognitionLocale(newValue) {
                    recognitionLocale = oldValue
                    error = String(localized: "voice.recognition.unavailable")
                } else { error = nil }
            }
            Text("voice.recognition.localAvailability").font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted)
            HStack {
                TextField("voice.wakePhrase.label", text: $wakePhrase)
                Button("voice.wakePhrase.save") {
                    if coordinator.updateWakePhrase(wakePhrase) { error = nil }
                    else { error = String(localized: "voice.wakePhrase.validation") }
                }
                .buttonStyle(TerminalButtonStyle())
            }
            if coordinator.isEnabled {
                Button("voice.hardOff") { coordinator.hardOff() }.buttonStyle(TerminalButtonStyle())
            } else {
                Button("voice.enable") { showsEnableExplanation = true }
                    .buttonStyle(TerminalPrimaryButtonStyle())
            }
            Text("voice.background.explanation").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            Divider()
            Text("voice.api.title").font(.headline)
            Text("voice.api.billingSeparate").font(.caption).foregroundStyle(TerminalTokens.warning)
            if coordinator.isAPIKeySaved {
                Label("voice.api.saved", systemImage: "key.fill").foregroundStyle(TerminalTokens.success)
                HStack {
                    Button("voice.api.test") { Task { await coordinator.testAPIConnection() } }
                        .buttonStyle(TerminalButtonStyle())
                    Button("voice.api.remove") {
                        do { try coordinator.removeAPIKey(); error = nil }
                        catch { self.error = error.localizedDescription }
                    }
                    .buttonStyle(TerminalButtonStyle())
                }
                LabeledContent("voice.api.connectionStatus", value: String(localized: String.LocalizationValue(coordinator.connectionStatusKey)))
            } else {
                SecureField("voice.api.keyPlaceholder", text: $apiKey)
                    .textContentType(.password)
                    .accessibilityIdentifier("voice.apiKey")
                Button("voice.api.save") {
                    do { try coordinator.saveAPIKey(apiKey); apiKey = ""; error = nil }
                    catch { self.error = error.localizedDescription; apiKey = "" }
                }
                .buttonStyle(TerminalButtonStyle())
            }
            TextField("voice.api.model", text: $model)
            Text("voice.api.keyPrivacy").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            Text("voice.dataScope.policy").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            if let error { Text(error).font(.caption).foregroundStyle(TerminalTokens.error) }
        }
        .onAppear {
            wakePhrase = coordinator.wakePhrase
            recognitionLocale = coordinator.recognitionLocaleIdentifier
            coordinator.refreshPermissionState()
        }
        .sheet(isPresented: $showsEnableExplanation) {
            VoiceEnableExplanationView {
                showsEnableExplanation = false
                Task { await coordinator.enableAfterExplanation() }
            }
        }
    }

    private func permissionLabel(_ state: VoicePermissionState) -> String {
        switch state {
        case .notDetermined: String(localized: "voice.permission.notDetermined")
        case .denied: String(localized: "voice.permission.denied")
        case .authorized: String(localized: "voice.permission.authorized")
        case .restricted: String(localized: "voice.permission.restricted")
        }
    }
}

private struct VoiceActionDraftView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State var draft: VoiceActionDraft

    private var coordinator: VoiceAssistantCoordinator { appState.voiceAssistant }

    var body: some View {
        TerminalWindow {
            VStack(alignment: .leading, spacing: 14) {
                TerminalHeader(titleKey: "voice.action.preview.title", subtitleKey: "voice.action.preview.subtitle")
                Label("voice.action.noWriteYet", systemImage: "lock.shield")
                    .foregroundStyle(TerminalTokens.warning)
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("voice.action.field.kind", selection: $draft.kind) {
                            ForEach(VoiceActionKind.allCases) { kind in Text(LocalizedStringKey(kind.titleKey)).tag(kind) }
                        }.disabled(draft.verb != .create)
                        TextField("voice.action.field.title", text: $draft.title).textFieldStyle(.roundedBorder)
                        TextField("voice.action.field.details", text: $draft.details, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
                        if needsDate {
                            DatePicker("voice.action.field.date", selection: dateBinding, displayedComponents: [.date, .hourAndMinute])
                        }
                        if needsDuration {
                            Stepper(value: $draft.durationMinutes, in: 10...720, step: 5) {
                                LabeledContent("voice.action.field.duration", value: "\(draft.durationMinutes) dk")
                            }
                        }
                        if draft.kind == .weeklyLesson {
                            Picker("voice.action.field.weekday", selection: Binding(get: { draft.weekday ?? 2 }, set: { draft.weekday = $0 })) {
                                ForEach(1...7, id: \.self) { day in Text(Calendar.current.weekdaySymbols[day - 1]).tag(day) }
                            }
                            DatePicker("voice.action.field.recurrenceEnd", selection: recurrenceEndBinding, displayedComponents: .date)
                            TextField("voice.action.field.course", text: $draft.courseName).textFieldStyle(.roundedBorder)
                        }
                        if draft.kind == .organizationTask {
                            TextField("voice.action.field.project", text: $draft.projectName).textFieldStyle(.roundedBorder)
                        }
                        if draft.kind == .financeExpense || draft.kind == .financeIncome {
                            TextField("voice.action.field.amount", value: amountBinding, format: .number).textFieldStyle(.roundedBorder)
                            TextField("voice.action.field.currency", text: $draft.currencyCode).textFieldStyle(.roundedBorder)
                        }
                        Divider().overlay(TerminalTokens.border)
                        Text("voice.action.exactFields").font(.headline)
                        ForEach(draft.exactFieldLines, id: \.self) { Text("• \($0)").font(.system(.caption, design: .monospaced)) }
                        if let conflict = coordinator.pendingActionConflict {
                            Label(conflict.message, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(TerminalTokens.warning).accessibilityIdentifier("voice.action.conflict")
                            HStack {
                                if let suggested = conflict.suggestedStart {
                                    Button("voice.action.conflict.findAnother") {
                                        draft = VoiceActionPersistenceService.rescheduled(draft, to: suggested)
                                        coordinator.updatePendingAction(draft)
                                    }
                                        .buttonStyle(TerminalButtonStyle())
                                }
                                Button("voice.action.conflict.keep") {
                                    draft.keepConflict = true
                                    coordinator.keepPendingConflict()
                                }
                                    .buttonStyle(TerminalButtonStyle())
                                Button("action.cancel") { coordinator.cancelPendingAction(); dismiss() }
                                    .buttonStyle(TerminalButtonStyle())
                            }
                        }
                    }
                }
                HStack {
                    Button("action.cancel") { coordinator.cancelPendingAction(); dismiss() }
                        .buttonStyle(TerminalButtonStyle()).keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("voice.action.preview.applyEdits") { coordinator.updatePendingAction(draft) }
                        .buttonStyle(TerminalButtonStyle())
                    Button("voice.action.confirm") { coordinator.updatePendingAction(draft); coordinator.confirmPendingAction(); dismiss() }
                        .buttonStyle(TerminalPrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                        .disabled(coordinator.pendingActionConflict != nil || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(22)
        }
        .frame(width: 720, height: 720)
        .accessibilityIdentifier("voice.action.preview")
    }

    private var needsDate: Bool {
        ![VoiceActionKind.studyCourse, .organizationProject, .note, .financeExpense, .financeIncome].contains(draft.kind)
    }
    private var needsDuration: Bool { [.weeklyLesson, .studyTask, .organizationTask, .calendarEvent, .calendarTask, .gymSession].contains(draft.kind) }
    private var dateBinding: Binding<Date> {
        Binding(get: { draft.startDate ?? draft.dueDate ?? .now }, set: { value in
            if draft.kind == .studyTask || draft.kind == .organizationTask { draft.dueDate = value }
            else { draft.startDate = value; draft.endDate = Calendar.current.date(byAdding: .minute, value: max(draft.durationMinutes, 0), to: value) }
            if draft.kind == .weeklyLesson { draft.weekday = Calendar.current.component(.weekday, from: value) }
        })
    }
    private var recurrenceEndBinding: Binding<Date> { Binding(get: { draft.recurrenceEnd ?? draft.startDate ?? .now }, set: { draft.recurrenceEnd = $0 }) }
    private var amountBinding: Binding<Double> { Binding(get: { Double(draft.amountMinorUnits ?? 0) / 100 }, set: { draft.amountMinorUnits = Int(($0 * 100).rounded()) }) }
}

private struct VoiceDraftInterpretationConsentView: View {
    @EnvironmentObject private var appState: AppState
    let consent: VoiceDraftInterpretationConsent

    var body: some View {
        TerminalWindow {
            VStack(alignment: .leading, spacing: 14) {
                TerminalHeader(titleKey: "voice.action.remote.consentTitle", subtitleKey: "voice.action.remote.consentSubtitle")
                Label("voice.action.remote.noExecution", systemImage: "checkmark.shield")
                    .foregroundStyle(TerminalTokens.warning)
                Text("voice.action.remote.exactOutgoing").font(.headline)
                Text(consent.exactOutgoingText).textSelection(.enabled).padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(Rectangle().stroke(TerminalTokens.border))
                Text("voice.action.remote.storeFalse").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
                HStack {
                    Button("voice.consent.deny") { appState.voiceAssistant.denyDraftInterpretationConsent() }
                        .buttonStyle(TerminalButtonStyle()).keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("voice.consent.allowOnce") { appState.voiceAssistant.approveDraftInterpretationConsent() }
                        .buttonStyle(TerminalPrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                }
            }.padding(22)
        }
        .frame(width: 650, height: 470)
        .accessibilityIdentifier("voice.action.remoteConsent")
    }
}

private struct VoiceEnableExplanationView: View {
    @Environment(\.dismiss) private var dismiss
    let onEnable: () -> Void

    var body: some View {
        TerminalWindow {
            VStack(alignment: .leading, spacing: 15) {
                TerminalHeader(titleKey: "voice.enable.title", subtitleKey: "voice.enable.subtitle")
                Label("voice.enable.microphone", systemImage: "mic")
                Label("voice.enable.speech", systemImage: "waveform")
                Label("voice.enable.localOnly", systemImage: "internaldrive")
                Text("voice.enable.noRecording").foregroundStyle(TerminalTokens.phosphorMuted)
                Text("voice.enable.permissionTiming").foregroundStyle(TerminalTokens.warning)
                HStack {
                    Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle()).keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("voice.enable.confirm") { onEnable() }
                        .buttonStyle(TerminalPrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                }
            }
            .padding(22)
        }
        .frame(width: 620, height: 430)
        .accessibilityIdentifier("voice.enableExplanation")
    }
}
