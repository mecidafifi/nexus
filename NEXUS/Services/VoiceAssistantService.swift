import Foundation
import AVFoundation
import Speech
import Security
import SwiftData

enum VoicePermissionState: String, Equatable {
    case notDetermined, denied, authorized, restricted
}

protocol VoicePermissionProviding {
    var microphoneState: VoicePermissionState { get }
    var speechState: VoicePermissionState { get }
    func requestMicrophone() async -> VoicePermissionState
    func requestSpeech() async -> VoicePermissionState
}

struct SystemVoicePermissionProvider: VoicePermissionProviding {
    var microphoneState: VoicePermissionState { Self.map(AVCaptureDevice.authorizationStatus(for: .audio)) }
    var speechState: VoicePermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }

    func requestMicrophone() async -> VoicePermissionState {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        return granted ? .authorized : .denied
    }

    func requestSpeech() async -> VoicePermissionState {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let state: VoicePermissionState = switch status {
                case .notDetermined: .notDetermined
                case .denied: .denied
                case .authorized: .authorized
                case .restricted: .restricted
                @unknown default: .restricted
                }
                continuation.resume(returning: state)
            }
        }
    }

    private static func map(_ status: AVAuthorizationStatus) -> VoicePermissionState {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }
}

protocol VoiceSpeechRecognizing: AnyObject {
    func supportsOnDeviceRecognition(localeIdentifier: String) -> Bool
    func start(localeIdentifier: String, onTranscript: @escaping (String, Bool) -> Void,
               onError: @escaping (Error) -> Void) throws
    func stop()
}

enum VoiceRecognitionError: LocalizedError {
    case localRecognitionUnavailable, noInputDevice
    var errorDescription: String? {
        switch self {
        case .localRecognitionUnavailable: String(localized: "voice.error.localRecognitionUnavailable")
        case .noInputDevice: String(localized: "voice.error.noInputDevice")
        }
    }
}

final class AppleOnDeviceSpeechRecognizer: VoiceSpeechRecognizing {
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false

    func supportsOnDeviceRecognition(localeIdentifier: String) -> Bool {
        SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))?.supportsOnDeviceRecognition == true
    }

    func start(localeIdentifier: String, onTranscript: @escaping (String, Bool) -> Void,
               onError: @escaping (Error) -> Void) throws {
        stop()
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.supportsOnDeviceRecognition else { throw VoiceRecognitionError.localRecognitionUnavailable }
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw VoiceRecognitionError.noInputDevice }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation
        self.request = request
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in request.append(buffer) }
        tapInstalled = true
        task = recognizer.recognitionTask(with: request) { result, error in
            if let result { onTranscript(result.bestTranscription.formattedString, result.isFinal) }
            if let error { onError(error) }
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() {
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
    }

    deinit { stop() }
}

protocol VoiceSpeaking: AnyObject {
    func speak(_ text: String, completion: @escaping () -> Void)
    func stop()
}

final class SystemVoiceSpeaker: NSObject, VoiceSpeaking, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private var completion: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, completion: @escaping () -> Void) {
        stop()
        self.completion = completion
        let utterance = AVSpeechUtterance(string: text)
        let containsArabic = text.range(of: #"[\u{0600}-\u{06FF}]"#, options: .regularExpression) != nil
        utterance.voice = AVSpeechSynthesisVoice(language: containsArabic ? "ar-SA" : "tr-TR")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        completion = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let callback = completion
        completion = nil
        callback?()
    }
}

protocol SecureStringStore {
    func read() throws -> String?
    func write(_ value: String) throws
    func delete() throws
}

struct KeychainSecureStringStore: SecureStringStore {
    private let service = "com.nexus.studentlife.voice"
    private let account = "openai-api-key"

    func read() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { throw VoiceSecureStoreError.keychain(status) }
        return value
    }

    func write(_ value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addition = query
            addition[kSecValueData as String] = data
            addition[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let status = SecItemAdd(addition as CFDictionary, nil)
            guard status == errSecSuccess else { throw VoiceSecureStoreError.keychain(status) }
        } else if updateStatus != errSecSuccess { throw VoiceSecureStoreError.keychain(updateStatus) }
    }

    func delete() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw VoiceSecureStoreError.keychain(status) }
    }
}

enum VoiceSecureStoreError: LocalizedError {
    case keychain(OSStatus)
    var errorDescription: String? {
        switch self { case .keychain(let status): String(format: String(localized: "voice.error.keychain"), Int(status)) }
    }
}

protocol VoiceRemoteAnswering {
    func testConnection(apiKey: String) async throws
    func answer(question: String, groundedContext: String?, model: String, apiKey: String) async throws -> String
}

actor OpenAIResponsesClient: VoiceRemoteAnswering {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func testConnection(apiKey: String) async throws {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw VoiceRemoteError.connectionRejected((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    func answer(question: String, groundedContext: String?, model: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let context = groundedContext.map { "\n\nKullanıcının açıkça göndermeyi onayladığı NEXUS yerel özeti:\n\($0)" } ?? ""
        let body = ResponsesRequest(model: model, instructions: String(localized: "voice.remote.instructions"),
                                    input: question + context, store: false, max_output_tokens: 500)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw VoiceRemoteError.requestRejected((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try JSONDecoder().decode(ResponsesResponse.self, from: data)
        let text = decoded.output.flatMap { $0.content ?? [] }.compactMap(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw VoiceRemoteError.emptyResponse }
        return text
    }

    /// The model may only emit arguments for one inert proposal function. NEXUS
    /// never sends a function result and never executes a write from this call.
    func proposeAction(text: String, model: String, apiKey: String) async throws -> VoiceActionDraft {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try VoiceRemoteDraftRequestBuilder.makeBody(text: text, model: model)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw VoiceRemoteError.requestRejected((response as? HTTPURLResponse)?.statusCode ?? -1) }
        let decoded = try JSONDecoder().decode(DraftResponse.self, from: data)
        guard let arguments = decoded.output.first(where: { $0.type == "function_call" && $0.name == "propose_nexus_action" })?.arguments,
              let argumentData = arguments.data(using: .utf8) else { throw VoiceRemoteError.emptyResponse }
        let payload = try JSONDecoder().decode(RemoteDraftPayload.self, from: argumentData)
        guard !payload.needsClarification, let kind = VoiceActionKind(rawValue: payload.kind) else {
            throw VoiceRemoteDraftError.clarification(payload.clarificationQuestion)
        }
        let formatter = ISO8601DateFormatter()
        return VoiceActionDraft(kind: kind, title: payload.title, details: payload.details,
                                startDate: payload.startISO8601.flatMap(formatter.date), endDate: payload.endISO8601.flatMap(formatter.date),
                                dueDate: payload.dueISO8601.flatMap(formatter.date), weekday: payload.weekday,
                                durationMinutes: payload.durationMinutes, recurrenceEnd: payload.recurrenceEndISO8601.flatMap(formatter.date),
                                courseName: payload.courseName, projectName: payload.projectName,
                                amountMinorUnits: payload.amountMinorUnits, currencyCode: payload.currencyCode,
                                originalText: text, interpretationSource: .remote)
    }

    private struct ResponsesRequest: Encodable {
        let model: String
        let instructions: String
        let input: String
        let store: Bool
        let max_output_tokens: Int
    }
    private struct ResponsesResponse: Decodable {
        struct Item: Decodable { let content: [Content]? }
        struct Content: Decodable { let text: String? }
        let output: [Item]
    }
    private struct DraftResponse: Decodable {
        struct Item: Decodable { let type: String; let name: String?; let arguments: String? }
        let output: [Item]
    }
    private struct RemoteDraftPayload: Decodable {
        let kind: String; let title: String; let details: String
        let startISO8601: String?; let endISO8601: String?; let dueISO8601: String?
        let weekday: Int?; let durationMinutes: Int; let recurrenceEndISO8601: String?
        let courseName: String; let projectName: String; let amountMinorUnits: Int?; let currencyCode: String
        let needsClarification: Bool; let clarificationQuestion: String
    }
}

extension OpenAIResponsesClient: VoiceRemoteDraftInterpreting {}

enum VoiceRemoteDraftError: LocalizedError {
    case clarification(String)
    var errorDescription: String? {
        switch self { case .clarification(let question): question.isEmpty ? String(localized: "voice.action.clarify.remote") : question }
    }
}

enum VoiceRemoteError: LocalizedError {
    case connectionRejected(Int), requestRejected(Int), emptyResponse, missingKey
    var errorDescription: String? {
        switch self {
        case .connectionRejected(let code): String(format: String(localized: "voice.error.connection"), code)
        case .requestRejected(let code): String(format: String(localized: "voice.error.remote"), code)
        case .emptyResponse: String(localized: "voice.error.emptyResponse")
        case .missingKey: String(localized: "voice.error.missingKey")
        }
    }
}

enum WakePhraseMatcher {
    static func isValid(_ phrase: String) -> Bool {
        let words = VoiceCommandParser.normalized(phrase).split(separator: " ")
        return words.count >= 2 && words.joined().count >= 8
    }

    static func match(transcript: String, phrase: String) -> (matched: Bool, remainder: String) {
        let normalizedTranscript = VoiceCommandParser.normalized(transcript)
        let normalizedPhrase = VoiceCommandParser.normalized(phrase)
        guard isValid(phrase), let range = normalizedTranscript.range(of: normalizedPhrase) else { return (false, "") }
        return (true, String(normalizedTranscript[range.upperBound...]).trimmingCharacters(in: .whitespaces))
    }
}

enum VoiceAssistantState: Equatable {
    case off, locked, needsPermission, waitingForWake, activeListening, processing, speaking, error(String)
}

struct VoiceConversationMessage: Identifiable, Equatable {
    enum Source: String { case user, local, openAI, system }
    let id: UUID
    let source: Source
    let text: String
    let createdAt: Date
    let scopes: Set<VoiceDataScope>
    let wasTransmitted: Bool

    init(id: UUID = UUID(), source: Source, text: String, createdAt: Date = .now,
         scopes: Set<VoiceDataScope> = [], wasTransmitted: Bool = false) {
        self.id = id; self.source = source; self.text = text; self.createdAt = createdAt
        self.scopes = scopes; self.wasTransmitted = wasTransmitted
    }
}

struct VoiceRemoteConsent: Identifiable, Equatable {
    let id = UUID()
    let question: String
    let report: VoiceReport
}

@MainActor
final class VoiceAssistantCoordinator: ObservableObject {
    @Published private(set) var state: VoiceAssistantState = .off
    @Published private(set) var microphonePermission: VoicePermissionState = .notDetermined
    @Published private(set) var speechPermission: VoicePermissionState = .notDetermined
    @Published private(set) var isAPIKeySaved = false
    @Published private(set) var connectionStatusKey = "voice.api.notTested"
    @Published private(set) var messages: [VoiceConversationMessage] = []
    @Published private(set) var lastLocalReport: VoiceReport?
    @Published var pendingAction: VoiceActionDraft?
    @Published var pendingActionConflict: VoiceActionConflict?
    @Published var pendingDraftInterpretationConsent: VoiceDraftInterpretationConsent?
    @Published var pendingConsent: VoiceRemoteConsent?
    @Published var draftText = ""
    @Published var wakePhrase: String
    @Published var isPanelPresented = false

    private let permissions: VoicePermissionProviding
    private let recognizer: VoiceSpeechRecognizing
    private let speaker: VoiceSpeaking
    private let secureStore: SecureStringStore
    private let remote: VoiceRemoteAnswering
    private let remoteDraftInterpreter: VoiceRemoteDraftInterpreting
    private let defaults: UserDefaults
    private var context: ModelContext?
    private var navigation: ((AppRoute) -> Void)?
    private var accessAllowed: (() -> Bool)?
    private var initialized = false
    private var recognitionGeneration = 0
    private var lastUndoToken: VoiceActionUndoToken?

    init(permissions: VoicePermissionProviding = SystemVoicePermissionProvider(),
         recognizer: VoiceSpeechRecognizing = AppleOnDeviceSpeechRecognizer(),
         speaker: VoiceSpeaking = SystemVoiceSpeaker(), secureStore: SecureStringStore = KeychainSecureStringStore(),
         remote: VoiceRemoteAnswering = OpenAIResponsesClient(),
         remoteDraftInterpreter: VoiceRemoteDraftInterpreting = OpenAIResponsesClient(), defaults: UserDefaults = .standard) {
        self.permissions = permissions; self.recognizer = recognizer; self.speaker = speaker
        self.secureStore = secureStore; self.remote = remote; self.remoteDraftInterpreter = remoteDraftInterpreter; self.defaults = defaults
        let stored = defaults.string(forKey: "voice.wakePhrase") ?? String(localized: "voice.wakePhrase.default")
        self.wakePhrase = WakePhraseMatcher.isValid(stored) ? stored : String(localized: "voice.wakePhrase.default")
    }

    var isEnabled: Bool { defaults.bool(forKey: "voice.enabled") }
    var canUndoVoiceAction: Bool { lastUndoToken != nil }
    var recognitionLocaleIdentifier: String { defaults.string(forKey: "voice.recognitionLocale") ?? "tr-TR" }
    var statusSymbol: String {
        switch state {
        case .off: "mic.slash"
        case .locked: "lock.fill"
        case .needsPermission: "mic.badge.xmark"
        case .waitingForWake: "waveform"
        case .activeListening: "waveform.badge.mic"
        case .processing: "ellipsis.circle"
        case .speaking: "speaker.wave.2"
        case .error: "exclamationmark.triangle"
        }
    }
    var statusKey: String {
        switch state {
        case .off: "voice.status.off"
        case .locked: "voice.status.locked"
        case .needsPermission: "voice.status.needsPermission"
        case .waitingForWake: "voice.status.waiting"
        case .activeListening: "voice.status.listening"
        case .processing: "voice.status.processing"
        case .speaking: "voice.status.speaking"
        case .error: "voice.status.error"
        }
    }

    func configure(context: ModelContext, navigation: @escaping (AppRoute) -> Void,
                   accessAllowed: @escaping () -> Bool) {
        self.context = context
        self.navigation = navigation
        self.accessAllowed = accessAllowed
        initializeIfNeeded()
    }

    func initializeIfNeeded() {
        guard !initialized else { return }
        initialized = true
        refreshPermissionState()
        do { isAPIKeySaved = try secureStore.read()?.isEmpty == false }
        catch { appendSystem(error.localizedDescription); isAPIKeySaved = false }
        if isEnabled {
            if !canAccessPrivateData() { state = .locked }
            else if microphonePermission == .authorized && speechPermission == .authorized { startWakeListening() }
            else { state = .needsPermission }
        } else { state = .off }
    }

    func refreshPermissionState() {
        microphonePermission = permissions.microphoneState
        speechPermission = permissions.speechState
    }

    func enableAfterExplanation() async {
        refreshPermissionState()
        if microphonePermission == .notDetermined { microphonePermission = await permissions.requestMicrophone() }
        guard microphonePermission == .authorized else { state = .needsPermission; return }
        if speechPermission == .notDetermined { speechPermission = await permissions.requestSpeech() }
        guard speechPermission == .authorized else { state = .needsPermission; return }
        guard recognizer.supportsOnDeviceRecognition(localeIdentifier: recognitionLocaleIdentifier) else {
            state = .error(String(localized: "voice.error.localRecognitionUnavailable")); return
        }
        defaults.set(true, forKey: "voice.enabled")
        startWakeListening()
    }

    func hardOff() {
        defaults.set(false, forKey: "voice.enabled")
        recognitionGeneration += 1
        recognizer.stop()
        speaker.stop()
        state = .off
        pendingConsent = nil
        pendingAction = nil
        pendingActionConflict = nil
        pendingDraftInterpretationConsent = nil
        lastLocalReport = nil
    }

    func suspendForPrivacyLock() {
        guard isEnabled else { return }
        recognitionGeneration += 1
        recognizer.stop()
        speaker.stop()
        pendingConsent = nil
        pendingAction = nil
        pendingActionConflict = nil
        pendingDraftInterpretationConsent = nil
        state = .locked
    }

    func resumeAfterPrivacyUnlock() {
        guard isEnabled else { state = .off; return }
        refreshPermissionState()
        if microphonePermission == .authorized && speechPermission == .authorized { startWakeListening() }
        else { state = .needsPermission }
    }

    func updateWakePhrase(_ value: String) -> Bool {
        guard WakePhraseMatcher.isValid(value) else { return false }
        wakePhrase = value.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(wakePhrase, forKey: "voice.wakePhrase")
        if isEnabled { startWakeListening() }
        return true
    }

    func updateRecognitionLocale(_ identifier: String) -> Bool {
        guard ["tr-TR", "ar-SA"].contains(identifier), recognizer.supportsOnDeviceRecognition(localeIdentifier: identifier) else { return false }
        defaults.set(identifier, forKey: "voice.recognitionLocale")
        if isEnabled { startWakeListening() }
        return true
    }

    func beginPushToTalk() {
        guard isEnabled else { state = .off; return }
        guard canAccessPrivateData() else { denyWhileLocked(); return }
        guard microphonePermission == .authorized && speechPermission == .authorized else { state = .needsPermission; return }
        startRecognition(mode: .command)
    }

    func stopCurrentAudio() {
        recognitionGeneration += 1
        recognizer.stop()
        speaker.stop()
        if isEnabled { startWakeListening() } else { state = .off }
    }

    func submitText() {
        let value = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        draftText = ""
        Task { await handleQuestion(value) }
    }

    /// Processes a user-confirmed text or recognized utterance. Public so the
    /// deterministic privacy and routing behavior can be verified without audio hardware.
    func processText(_ value: String) async {
        let question = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        await handleQuestion(question)
    }

    func prepareGroundedRemoteQuestion(_ question: String, report: VoiceReport) {
        pendingConsent = VoiceRemoteConsent(question: question, report: report)
    }

    func approvePendingConsent() {
        Task { await approvePendingConsentNow() }
    }

    func approvePendingConsentNow() async {
        guard let consent = pendingConsent else { return }
        pendingConsent = nil
        await askRemote(question: consent.question, report: consent.report)
    }

    func denyPendingConsent() { pendingConsent = nil }

    func updatePendingAction(_ value: VoiceActionDraft) { stageAction(value) }

    func cancelPendingAction() {
        pendingAction = nil; pendingActionConflict = nil
        answerLocally(String(localized: "voice.action.cancelled"), scopes: [])
    }

    func confirmPendingAction() {
        guard let action = pendingAction else { return }
        Task { await performConfirmation(action) }
    }

    func confirmPendingActionNow() async {
        guard let action = pendingAction else { return }
        await performConfirmation(action)
    }

    private func performConfirmation(_ action: VoiceActionDraft) async {
        guard canAccessPrivateData() else { denyWhileLocked(); return }
        guard let context else { return }
        do {
            let undo = try VoiceActionPersistenceService.confirm(action, context: context)
            lastUndoToken = undo
            pendingAction = nil; pendingActionConflict = nil
            answerLocally(String(format: String(localized: "voice.action.saved"), undo.summary), scopes: [])
        } catch { fail(error) }
    }

    func keepPendingConflict() {
        guard var action = pendingAction else { return }
        action.keepConflict = true
        pendingAction = action; pendingActionConflict = nil
        answerLocally(String(localized: "voice.action.conflict.keptPreview"), scopes: [])
    }

    func useSuggestedTime() {
        guard let action = pendingAction, let suggested = pendingActionConflict?.suggestedStart else { return }
        stageAction(VoiceActionPersistenceService.rescheduled(action, to: suggested))
    }

    func undoLastVoiceAction() { Task { await undoLastVoiceActionNow() } }

    func undoLastVoiceActionNow() async {
        guard canAccessPrivateData() else { denyWhileLocked(); return }
        guard let token = lastUndoToken, let context else { answerLocally(String(localized: "voice.action.error.nothingToUndo"), scopes: []); return }
        do {
            try VoiceActionPersistenceService.undo(token, context: context)
            lastUndoToken = nil
            answerLocally(String(format: String(localized: "voice.action.undone"), token.summary), scopes: [])
        } catch { fail(error) }
    }

    func approveDraftInterpretationConsent() {
        Task { await approveDraftInterpretationConsentNow() }
    }

    func approveDraftInterpretationConsentNow() async {
        guard let consent = pendingDraftInterpretationConsent else { return }
        pendingDraftInterpretationConsent = nil
        guard canAccessPrivateData() else { denyWhileLocked(); return }
        do {
            guard let key = try secureStore.read(), !key.isEmpty else { throw VoiceRemoteError.missingKey }
            state = .processing
            let model = defaults.string(forKey: "voice.openAIModel") ?? "gpt-5-mini"
            messages.append(.init(source: .user, text: consent.exactOutgoingText, wasTransmitted: true))
            let draft = try await remoteDraftInterpreter.proposeAction(text: consent.exactOutgoingText, model: model, apiKey: key)
            stageAction(draft)
        } catch { fail(error) }
    }

    func denyDraftInterpretationConsent() {
        pendingDraftInterpretationConsent = nil
        answerLocally(String(localized: "voice.action.remote.denied"), scopes: [])
    }

    func saveAPIKey(_ value: String) throws {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count >= 20, key.hasPrefix("sk-") else { throw VoiceRemoteError.missingKey }
        try secureStore.write(key)
        isAPIKeySaved = true
        connectionStatusKey = "voice.api.savedNotTested"
    }

    func removeAPIKey() throws {
        try secureStore.delete()
        isAPIKeySaved = false
        connectionStatusKey = "voice.api.notConfigured"
    }

    func testAPIConnection() async {
        connectionStatusKey = "voice.api.testing"
        do {
            guard let key = try secureStore.read(), !key.isEmpty else { throw VoiceRemoteError.missingKey }
            try await remote.testConnection(apiKey: key)
            connectionStatusKey = "voice.api.connected"
        } catch {
            connectionStatusKey = "voice.api.failed"
            appendSystem(error.localizedDescription)
        }
    }

    func clearSessionHistory() { messages.removeAll() }

    private enum RecognitionMode { case wake, command }

    private func startWakeListening() {
        guard isEnabled else { state = .off; return }
        guard canAccessPrivateData() else { state = .locked; return }
        startRecognition(mode: .wake)
    }

    private func startRecognition(mode: RecognitionMode) {
        recognitionGeneration += 1
        let generation = recognitionGeneration
        recognizer.stop()
        state = mode == .wake ? .waitingForWake : .activeListening
        do {
            try recognizer.start(localeIdentifier: recognitionLocaleIdentifier) { [weak self] transcript, isFinal in
                Task { @MainActor in
                    guard let self, generation == self.recognitionGeneration else { return }
                    self.receive(transcript: transcript, final: isFinal, mode: mode)
                }
            } onError: { [weak self] error in
                Task { @MainActor in
                    guard let self, generation == self.recognitionGeneration else { return }
                    self.recognitionFailed(error)
                }
            }
        } catch { state = .error(error.localizedDescription) }
    }

    private func receive(transcript: String, final: Bool, mode: RecognitionMode) {
        switch mode {
        case .wake:
            let match = WakePhraseMatcher.match(transcript: transcript, phrase: wakePhrase)
            guard match.matched else {
                if final { scheduleWakeRestart() }
                return
            }
            recognizer.stop()
            recognitionGeneration += 1
            isPanelPresented = true
            if !canAccessPrivateData() { denyWhileLocked(); return }
            if match.remainder.count >= 2 { Task { await handleQuestion(match.remainder) } }
            else { startRecognition(mode: .command) }
        case .command:
            guard final else { return }
            recognizer.stop()
            recognitionGeneration += 1
            let question = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if question.isEmpty { startWakeListening() }
            else { Task { await handleQuestion(question) } }
        }
    }

    private func recognitionFailed(_ error: Error) {
        if isEnabled {
            state = .error(error.localizedDescription)
            scheduleWakeRestart()
        } else { state = .off }
    }

    private func scheduleWakeRestart() {
        let generation = recognitionGeneration
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, self.isEnabled, generation == self.recognitionGeneration else { return }
            self.startWakeListening()
        }
    }

    private func handleQuestion(_ question: String) async {
        guard canAccessPrivateData() else { denyWhileLocked(); return }
        state = .processing
        if let control = VoiceActionSpeechControl.parse(question) {
            switch control {
            case .confirm where pendingAction != nil: await confirmPendingActionNow()
            case .cancel where pendingAction != nil: cancelPendingAction()
            case .undo: await undoLastVoiceActionNow()
            case .keepConflict where pendingActionConflict != nil: keepPendingConflict()
            case .findAnotherTime where pendingActionConflict?.suggestedStart != nil: useSuggestedTime()
            case .correction(let correction) where pendingAction != nil:
                stageAction(LocalVoiceActionParser.applying(correction, to: pendingAction!))
            default: answerLocally(String(localized: "voice.action.control.noPending"), scopes: [])
            }
            return
        }
        switch LocalVoiceActionParser.parse(question) {
        case .draft(let draft):
            messages.append(.init(source: .user, text: question))
            stageAction(draft)
            return
        case .clarification(let text):
            messages.append(.init(source: .user, text: question))
            answerLocally(text, scopes: [])
            return
        case .unsupported: break
        }
        switch VoiceCommandParser.parse(question) {
        case .navigate(let route):
            messages.append(.init(source: .user, text: question))
            navigation?(route)
            answerLocally(String(format: String(localized: "voice.navigation.opened"), String(localized: String.LocalizationValue(route.titleKey))), scopes: [])
        case .report(let kind):
            messages.append(.init(source: .user, text: question))
            do {
                guard let context else { throw VoiceRuntimeError.notConfigured }
                let report = try VoiceLocalReportService.make(kind, context: context)
                lastLocalReport = report
                messages.append(.init(source: .local, text: ([report.title] + report.details).joined(separator: "\n"), scopes: report.scopes))
                speak(report.spokenText)
            } catch { fail(error) }
        case .remoteQuestion(let value):
            guard !value.isEmpty else { answerLocally(String(localized: "voice.error.emptyQuestion"), scopes: []); return }
            if isAPIKeySaved && looksLikeWriteRequest(value) {
                pendingDraftInterpretationConsent = VoiceDraftInterpretationConsent(exactOutgoingText: value)
                answerLocally(String(localized: "voice.action.remote.consentNeeded"), scopes: [])
            } else { await askRemote(question: value, report: nil) }
        }
    }

    private func stageAction(_ draft: VoiceActionDraft) {
        guard canAccessPrivateData(), let context else { denyWhileLocked(); return }
        do {
            let (prepared, validation) = try VoiceActionPersistenceService.prepare(draft, context: context)
            pendingAction = prepared
            switch validation {
            case .valid: pendingActionConflict = nil
            case .conflict(let conflict): pendingActionConflict = conflict
            }
            messages.append(.init(source: .local, text: prepared.exactFieldLines.joined(separator: "\n")))
            speak(prepared.spokenPreview)
        } catch { fail(error) }
    }

    private func looksLikeWriteRequest(_ value: String) -> Bool {
        let text = VoiceCommandParser.normalized(value)
        let turkish = ["ekle", "olustur", "kaydet", "degistir", "tasi", "iptal et"]
        let arabic = ["أضف", "اضف", "حط", "غيّر", "غير", "احذف", "إلغاء"]
        return turkish.contains(where: text.contains) || arabic.contains(where: value.contains)
    }

    private func askRemote(question: String, report: VoiceReport?) async {
        guard canAccessPrivateData() else { denyWhileLocked(); return }
        do {
            guard let key = try secureStore.read(), !key.isEmpty else {
                messages.append(.init(source: .user, text: question))
                answerLocally(String(localized: "voice.remote.keyNeeded"), scopes: []); return
            }
            state = .processing
            let model = defaults.string(forKey: "voice.openAIModel") ?? "gpt-5-mini"
            messages.append(.init(source: .user, text: question, scopes: report?.scopes ?? [], wasTransmitted: true))
            let response = try await remote.answer(question: question, groundedContext: report?.transmissionPreview, model: model, apiKey: key)
            messages.append(.init(source: .openAI, text: response, scopes: report?.scopes ?? [], wasTransmitted: true))
            speak(response)
        } catch { fail(error) }
    }

    private func answerLocally(_ text: String, scopes: Set<VoiceDataScope>) {
        messages.append(.init(source: .local, text: text, scopes: scopes))
        speak(text)
    }

    private func speak(_ text: String) {
        state = .speaking
        speaker.speak(text) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.isEnabled { self.startWakeListening() } else { self.state = .off }
            }
        }
    }

    private func fail(_ error: Error) {
        state = .error(error.localizedDescription)
        appendSystem(error.localizedDescription)
        scheduleWakeRestart()
    }

    private func appendSystem(_ text: String) { messages.append(.init(source: .system, text: text)) }
    private func canAccessPrivateData() -> Bool { accessAllowed?() ?? false }
    private func denyWhileLocked() {
        recognizer.stop()
        recognitionGeneration += 1
        pendingAction = nil
        pendingActionConflict = nil
        pendingDraftInterpretationConsent = nil
        state = .error(String(localized: "voice.locked"))
        appendSystem(String(localized: "voice.locked"))
    }
}

enum VoiceRuntimeError: LocalizedError {
    case notConfigured
    var errorDescription: String? { String(localized: "voice.error.notConfigured") }
}
