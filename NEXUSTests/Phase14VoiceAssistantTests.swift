import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class Phase14VoiceAssistantTests: XCTestCase {
    func testWakePhraseMatchesLocallyAndReturnsRemainder() {
        let result = WakePhraseMatcher.match(
            transcript: "Merhaba Yardımcı bugün beni neler bekliyor?",
            phrase: "Merhaba Yardımcı"
        )
        XCTAssertTrue(result.matched)
        XCTAssertEqual(result.remainder, "bugun beni neler bekliyor")
        XCTAssertFalse(WakePhraseMatcher.match(transcript: "Bugün ne var?", phrase: "Merhaba Yardımcı").matched)
    }

    func testWakePhraseValidationRejectsShortOrSingleWordValues() {
        XCTAssertFalse(WakePhraseMatcher.isValid("Nexus"))
        XCTAssertFalse(WakePhraseMatcher.isValid("hey sen"))
        XCTAssertTrue(WakePhraseMatcher.isValid("Merhaba Yardımcı"))
    }

    func testTurkishParserRoutesAllSupportedLocalReports() {
        XCTAssertEqual(VoiceCommandParser.parse("Bugün özetim ne?"), .report(.today))
        XCTAssertEqual(VoiceCommandParser.parse("Bu hafta ne var?"), .report(.week))
        XCTAssertEqual(VoiceCommandParser.parse("Tamamlanmamış görevleri göster"), .report(.incompleteTasks))
        XCTAssertEqual(VoiceCommandParser.parse("Devamsızlık riskim nedir?"), .report(.attendanceRisk))
        XCTAssertEqual(VoiceCommandParser.parse("Yaklaşan son tarihler"), .report(.deadlines))
        XCTAssertEqual(VoiceCommandParser.parse("Finans bakiyem"), .report(.finance))
        XCTAssertEqual(VoiceCommandParser.parse("Spor ilerleme ve odak"), .report(.gymAndFocus))
    }

    func testTurkishParserKeepsManualNavigationDeterministic() {
        XCTAssertEqual(VoiceCommandParser.parse("Çalışma bölümünü aç"), .navigate(.study))
        XCTAssertEqual(VoiceCommandParser.parse("Devam bölümüne git"), .navigate(.attendance))
        XCTAssertEqual(VoiceCommandParser.parse("Spor bölümünü aç"), .navigate(.gym))
        XCTAssertEqual(VoiceCommandParser.parse("Finansı aç"), .navigate(.finance))
        XCTAssertEqual(VoiceCommandParser.parse("Notları göster"), .navigate(.notes))
        XCTAssertEqual(VoiceCommandParser.parse("Takvimi aç"), .navigate(.calendar))
        XCTAssertEqual(VoiceCommandParser.parse("OBS'yi aç"), .navigate(.obs))
        XCTAssertEqual(VoiceCommandParser.parse("Projeleri göster"), .navigate(.organization))
    }

    func testDisabledInitializationNeverRequestsPermissionOrStartsMicrophone() throws {
        let harness = try makeHarness()
        harness.coordinator.configure(context: harness.context, navigation: { _ in }, accessAllowed: { true })
        XCTAssertEqual(harness.permissions.microphoneRequests, 0)
        XCTAssertEqual(harness.permissions.speechRequests, 0)
        XCTAssertEqual(harness.recognizer.startCount, 0)
        XCTAssertEqual(harness.coordinator.state, .off)
    }

    func testExplicitEnableIsOnlyPathThatRequestsPermissionsAndStartsWakeListening() async throws {
        let harness = try makeHarness(microphone: .notDetermined, speech: .notDetermined)
        harness.coordinator.configure(context: harness.context, navigation: { _ in }, accessAllowed: { true })
        await harness.coordinator.enableAfterExplanation()
        XCTAssertEqual(harness.permissions.microphoneRequests, 1)
        XCTAssertEqual(harness.permissions.speechRequests, 1)
        XCTAssertEqual(harness.recognizer.startCount, 1)
        XCTAssertEqual(harness.coordinator.state, .waitingForWake)
        XCTAssertTrue(harness.defaults.bool(forKey: "voice.enabled"))
    }

    func testHardOffStopsRecognitionAndClearsConsent() async throws {
        let harness = try makeHarness(microphone: .authorized, speech: .authorized)
        harness.defaults.set(true, forKey: "voice.enabled")
        harness.coordinator.configure(context: harness.context, navigation: { _ in }, accessAllowed: { true })
        let report = VoiceReport(kind: .today, title: "Özet", spokenText: "Özet", details: ["1 görev"], scopes: [.tasks])
        harness.coordinator.prepareGroundedRemoteQuestion("Yorumla", report: report)
        harness.coordinator.hardOff()
        XCTAssertFalse(harness.defaults.bool(forKey: "voice.enabled"))
        XCTAssertNil(harness.coordinator.pendingConsent)
        XCTAssertEqual(harness.coordinator.state, .off)
        XCTAssertGreaterThanOrEqual(harness.recognizer.stopCount, 1)
    }

    func testEnabledAssistantDoesNotStartWakeRecognitionWhileTouchIDBlocksAccess() throws {
        let harness = try makeHarness(microphone: .authorized, speech: .authorized)
        harness.defaults.set(true, forKey: "voice.enabled")
        harness.coordinator.configure(context: harness.context, navigation: { _ in }, accessAllowed: { false })
        XCTAssertEqual(harness.coordinator.state, .locked)
        XCTAssertEqual(harness.recognizer.startCount, 0)
    }

    func testPrivacyLockSuspendsAndUnlockResumesLocalWakeListening() throws {
        let harness = try makeHarness(microphone: .authorized, speech: .authorized)
        harness.defaults.set(true, forKey: "voice.enabled")
        harness.coordinator.configure(context: harness.context, navigation: { _ in }, accessAllowed: { true })
        XCTAssertEqual(harness.recognizer.startCount, 1)
        harness.coordinator.suspendForPrivacyLock()
        XCTAssertEqual(harness.coordinator.state, .locked)
        let stopped = harness.recognizer.stopCount
        harness.coordinator.resumeAfterPrivacyUnlock()
        XCTAssertEqual(harness.coordinator.state, .waitingForWake)
        XCTAssertEqual(harness.recognizer.startCount, 2)
        XCTAssertGreaterThan(harness.recognizer.stopCount, stopped)
    }

    func testAPIKeyIsStoredOnlyThroughSecureStoreAndNeverDefaults() throws {
        let harness = try makeHarness()
        let secret = "sk-test-123456789012345678901234"
        try harness.coordinator.saveAPIKey(secret)
        XCTAssertEqual(harness.secureStore.value, secret)
        let defaultsDump = harness.defaults.dictionaryRepresentation().description
        XCTAssertFalse(defaultsDump.contains(secret))
        try harness.coordinator.removeAPIKey()
        XCTAssertNil(harness.secureStore.value)
    }

    func testUnknownQuestionSendsOnlyQuestionWithoutLocalContext() async throws {
        let harness = try makeHarness(key: "sk-test-123456789012345678901234")
        harness.coordinator.configure(context: harness.context, navigation: { _ in }, accessAllowed: { true })
        await harness.coordinator.processText("Fotosentezi kısaca açıkla")
        let calls = await harness.remote.answerCalls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.question, "Fotosentezi kısaca açıkla")
        XCTAssertNil(calls.first?.groundedContext)
        let userMessage = harness.coordinator.messages.first { $0.source == .user }
        XCTAssertEqual(userMessage?.text, "Fotosentezi kısaca açıkla")
        XCTAssertEqual(userMessage?.wasTransmitted, true)
        XCTAssertTrue(userMessage?.scopes.isEmpty == true)
    }

    func testGroundedLocalDataIsDefaultDenyAndTransmitsOnlyAfterOneTimeApproval() async throws {
        let harness = try makeHarness(key: "sk-test-123456789012345678901234")
        harness.coordinator.configure(context: harness.context, navigation: { _ in }, accessAllowed: { true })
        let report = VoiceReport(kind: .incompleteTasks, title: "Görevler", spokenText: "İki görev", details: ["A", "B"], scopes: [.tasks])
        harness.coordinator.prepareGroundedRemoteQuestion("Önceliklendir", report: report)
        var remoteCallCount = await harness.remote.answerCalls.count
        XCTAssertEqual(remoteCallCount, 0)
        XCTAssertEqual(harness.coordinator.pendingConsent?.report.transmissionPreview, "Görevler\nA\nB")
        harness.coordinator.denyPendingConsent()
        remoteCallCount = await harness.remote.answerCalls.count
        XCTAssertEqual(remoteCallCount, 0)

        harness.coordinator.prepareGroundedRemoteQuestion("Önceliklendir", report: report)
        await harness.coordinator.approvePendingConsentNow()
        let calls = await harness.remote.answerCalls
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.groundedContext, "Görevler\nA\nB")
        let transmittedQuestion = harness.coordinator.messages.first { $0.source == .user && $0.wasTransmitted }
        XCTAssertEqual(transmittedQuestion?.scopes, [.tasks])
    }

    func testLockedStateBlocksLocalDataAndNavigation() async throws {
        let harness = try makeHarness(key: "sk-test-123456789012345678901234")
        var routes: [AppRoute] = []
        harness.coordinator.configure(context: harness.context, navigation: { routes.append($0) }, accessAllowed: { false })
        await harness.coordinator.processText("Finansı aç")
        await harness.coordinator.processText("Bugün ne var?")
        XCTAssertTrue(routes.isEmpty)
        let remoteCallCount = await harness.remote.answerCalls.count
        XCTAssertEqual(remoteCallCount, 0)
        XCTAssertTrue(harness.coordinator.messages.contains { $0.text == String(localized: "voice.locked") })
    }

    func testTodayReportUsesRealDataAndCancelledLessonIsNotHeld() throws {
        let harness = try makeHarness()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 10))!
        let course = Course(name: "TEST — Yapay Zeka", semesterStart: date, semesterEnd: date.addingTimeInterval(86_400 * 30))
        let rule = StudyScheduleRule(courseID: course.id, weekday: calendar.component(.weekday, from: date), startMinutes: 600, effectiveStart: date, effectiveEnd: date.addingTimeInterval(86_400 * 30))
        harness.context.insert(course); harness.context.insert(rule)
        let occurrence = DailyPlanAggregator.occurrences(rules: [rule], on: date, courses: [course], calendar: calendar).first!
        harness.context.insert(AttendanceRecord(courseID: course.id, date: date, status: .cancelled, occurrenceID: occurrence.id, scheduleRuleID: rule.id))
        harness.context.insert(StudyTask(title: "TEST — Görev", dueDate: date, status: .planned))
        try harness.context.save()

        let report = try VoiceLocalReportService.make(.today, date: date, context: harness.context, calendar: calendar)
        XCTAssertTrue(report.spokenText.contains("0"), report.spokenText)
        XCTAssertTrue(report.spokenText.contains("1"), report.spokenText)
        XCTAssertTrue(report.scopes.contains(.attendance))
        XCTAssertTrue(report.scopes.contains(.tasks))
    }

    func testLocalReportIsReadOnly() async throws {
        let harness = try makeHarness()
        let task = StudyTask(title: "TEST — Değişmemeli", dueDate: .now, status: .planned)
        harness.context.insert(task)
        try harness.context.save()
        harness.coordinator.configure(context: harness.context, navigation: { _ in }, accessAllowed: { true })
        await harness.coordinator.processText("Tamamlanmamış görevleri göster")
        XCTAssertEqual(task.status, .planned)
        XCTAssertNil(task.completedAt)
        XCTAssertNotNil(harness.coordinator.lastLocalReport)
    }

    func testFutureWriteProposalContractIsConfirmationGatedAndSourceOwned() {
        let proposal = VoiceProposedMutation(kind: .add, owner: .study, summary: "Görev taslağı", proposedFields: ["title": "Rapor"])
        XCTAssertTrue(proposal.requiresExplicitConfirmation)
        XCTAssertEqual(proposal.owner, .study)
        XCTAssertEqual(proposal.proposedFields["title"], "Rapor")
    }

    func testBackupSchemaRemainsV9AndContainsNoVoiceSecretOrHistoryFields() throws {
        let harness = try makeHarness(key: "sk-test-123456789012345678901234")
        let backup = try BackupService.export(from: harness.context)
        let json = String(decoding: try JSONEncoder().encode(backup), as: UTF8.self)
        XCTAssertEqual(backup.schemaVersion, 9)
        XCTAssertFalse(json.contains("apiKey"))
        XCTAssertFalse(json.contains("wakePhrase"))
        XCTAssertFalse(json.contains("voice.enabled"))
        XCTAssertFalse(json.contains("conversation"))
    }

    private func makeHarness(
        microphone: VoicePermissionState = .notDetermined,
        speech: VoicePermissionState = .notDetermined,
        key: String? = nil
    ) throws -> Harness {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let suite = "NEXUS.Phase14Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let permissions = FakeVoicePermissions(microphone: microphone, speech: speech)
        let recognizer = FakeVoiceRecognizer()
        let speaker = FakeVoiceSpeaker()
        let store = FakeVoiceSecureStore(value: key)
        let remote = FakeVoiceRemote()
        let coordinator = VoiceAssistantCoordinator(
            permissions: permissions, recognizer: recognizer, speaker: speaker,
            secureStore: store, remote: remote, defaults: defaults
        )
        return Harness(container: container, defaults: defaults, permissions: permissions,
                       recognizer: recognizer, speaker: speaker, secureStore: store,
                       remote: remote, coordinator: coordinator)
    }
}

@MainActor
private struct Harness {
    let container: ModelContainer
    let defaults: UserDefaults
    let permissions: FakeVoicePermissions
    let recognizer: FakeVoiceRecognizer
    let speaker: FakeVoiceSpeaker
    let secureStore: FakeVoiceSecureStore
    let remote: FakeVoiceRemote
    let coordinator: VoiceAssistantCoordinator
    var context: ModelContext { container.mainContext }
}

private final class FakeVoicePermissions: VoicePermissionProviding {
    var microphoneState: VoicePermissionState
    var speechState: VoicePermissionState
    var microphoneRequests = 0
    var speechRequests = 0

    init(microphone: VoicePermissionState, speech: VoicePermissionState) {
        microphoneState = microphone; speechState = speech
    }
    func requestMicrophone() async -> VoicePermissionState { microphoneRequests += 1; microphoneState = .authorized; return .authorized }
    func requestSpeech() async -> VoicePermissionState { speechRequests += 1; speechState = .authorized; return .authorized }
}

private final class FakeVoiceRecognizer: VoiceSpeechRecognizing {
    var startCount = 0
    var stopCount = 0
    var supportsLocal = true
    func supportsOnDeviceRecognition(localeIdentifier: String) -> Bool { supportsLocal }
    func start(localeIdentifier: String, onTranscript: @escaping (String, Bool) -> Void,
               onError: @escaping (Error) -> Void) throws { startCount += 1 }
    func stop() { stopCount += 1 }
}

private final class FakeVoiceSpeaker: VoiceSpeaking {
    var spoken: [String] = []
    func speak(_ text: String, completion: @escaping () -> Void) { spoken.append(text) }
    func stop() {}
}

private final class FakeVoiceSecureStore: SecureStringStore {
    var value: String?
    init(value: String?) { self.value = value }
    func read() throws -> String? { value }
    func write(_ value: String) throws { self.value = value }
    func delete() throws { value = nil }
}

private actor FakeVoiceRemote: VoiceRemoteAnswering {
    struct Call: Equatable { let question: String; let groundedContext: String?; let model: String; let apiKey: String }
    private(set) var answerCalls: [Call] = []
    private(set) var testCalls = 0
    func testConnection(apiKey: String) async throws { testCalls += 1 }
    func answer(question: String, groundedContext: String?, model: String, apiKey: String) async throws -> String {
        answerCalls.append(.init(question: question, groundedContext: groundedContext, model: model, apiKey: apiKey))
        return "TEST — yanıt"
    }
}
