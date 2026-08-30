import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class Phase9WorkflowTests: XCTestCase {
    private func date(_ day: Int = 27, hour: Int = 10, minute: Int = 0) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: TimeZone(identifier: "Europe/Istanbul"), year: 2026, month: 8, day: day, hour: hour, minute: minute))!
    }

    private var preferences: LocalNotificationPreferences {
        LocalNotificationPreferences(enabled: true, lessonStart: true, deadline: true, attendanceRisk: true, scheduleConflict: true, leadMinutes: 15, hideDetails: false)
    }

    func testNotificationPlannerDisabledAndPastGuards() {
        var disabled = preferences; disabled.enabled = false
        let snapshot = NotificationPlanningSnapshot(lessons: [
            NotificationLessonSource(occurrenceID: "past", courseID: UUID(), title: "Geçmiş", start: date(hour: 9), end: date(hour: 10)),
            NotificationLessonSource(occurrenceID: "future", courseID: UUID(), title: "Gelecek", start: date(hour: 12), end: date(hour: 13))
        ])
        XCTAssertTrue(LocalNotificationPlanner.plan(snapshot: snapshot, preferences: disabled, now: date()).isEmpty)
        XCTAssertEqual(LocalNotificationPlanner.plan(snapshot: snapshot, preferences: preferences, now: date()).map(\.id), ["nexus.v9.lesson.future"])
    }

    func testNotificationIdentifiersAreStableUniqueAndDeterministic() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let lesson = NotificationLessonSource(occurrenceID: "lesson:\(id):1787817600", courseID: id, title: "Yapay Zeka", start: date(hour: 12), end: date(hour: 13))
        let snapshot = NotificationPlanningSnapshot(lessons: [lesson, lesson])
        let first = LocalNotificationPlanner.plan(snapshot: snapshot, preferences: preferences, now: date())
        let second = LocalNotificationPlanner.plan(snapshot: snapshot, preferences: preferences, now: date())
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 1)
        XCTAssertTrue(first[0].id.hasPrefix(PlannedLocalNotification.identifierPrefix))
        XCTAssertEqual(first[0].fireDate, date(hour: 11, minute: 45))
    }

    func testPrivacySafePlanningNeverIncludesSourceTitles() {
        var privatePreferences = preferences; privatePreferences.hideDetails = true
        let secret = "Özel Proje Başlığı"
        let snapshot = NotificationPlanningSnapshot(deadlines: [NotificationDeadlineSource(id: "task", title: secret, dueDate: date(hour: 14), isCompleted: false)])
        let request = LocalNotificationPlanner.plan(snapshot: snapshot, preferences: privatePreferences, now: date()).first!
        XCTAssertFalse(request.title.contains(secret))
        XCTAssertFalse(request.body.contains(secret))
        XCTAssertEqual(request.title, String(localized: "notifications.private.deadline.title"))
    }

    func testCompletedDeadlineAndDisabledCategoryAreExcluded() {
        var value = preferences; value.lessonStart = false
        let snapshot = NotificationPlanningSnapshot(
            lessons: [NotificationLessonSource(occurrenceID: "lesson", courseID: UUID(), title: "Ders", start: date(hour: 12), end: date(hour: 13))],
            deadlines: [NotificationDeadlineSource(id: "done", title: "Bitti", dueDate: date(hour: 15), isCompleted: true)]
        )
        XCTAssertTrue(LocalNotificationPlanner.plan(snapshot: snapshot, preferences: value, now: date()).isEmpty)
    }

    func testAttendanceRiskRequiresMeaningfulThresholdAndFutureLesson() {
        let course = UUID()
        let safe = NotificationAttendanceRiskSource(courseID: course, courseTitle: "Ders", absentCount: 1, allowedAbsenceCount: 3, nextLessonStart: date(hour: 13))
        let risky = NotificationAttendanceRiskSource(courseID: course, courseTitle: "Ders", absentCount: 2, allowedAbsenceCount: 3, nextLessonStart: date(hour: 13))
        XCTAssertTrue(LocalNotificationPlanner.plan(snapshot: .init(attendanceRisks: [safe]), preferences: preferences, now: date()).isEmpty)
        XCTAssertEqual(LocalNotificationPlanner.plan(snapshot: .init(attendanceRisks: [risky]), preferences: preferences, now: date()).first?.category, .attendanceRisk)
    }

    func testConflictIdentifierIsStableRegardlessOfPairOrder() {
        let left = NotificationConflictSource(leftID: "b", rightID: "a", start: date(hour: 13))
        let right = NotificationConflictSource(leftID: "a", rightID: "b", start: date(hour: 13))
        let first = LocalNotificationPlanner.plan(snapshot: .init(conflicts: [left]), preferences: preferences, now: date())
        let second = LocalNotificationPlanner.plan(snapshot: .init(conflicts: [right]), preferences: preferences, now: date())
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testAuthorizedReconciliationRemovesObsoleteAndUpsertsDesired() async {
        let fake = FakeNotificationCenter(state: .authorized)
        fake.pending = ["nexus.v9.deadline.old", "another.app.request"]
        let defaults = isolatedDefaults()
        let service = LocalNotificationService(client: fake, defaults: defaults, now: { self.date() })
        let snapshot = NotificationPlanningSnapshot(deadlines: [NotificationDeadlineSource(id: "new", title: "Yeni", dueDate: date(hour: 14), isCompleted: false)])
        XCTAssertEqual(LocalNotificationPlanner.plan(snapshot: snapshot, preferences: preferences, now: date()).map(\.id), ["nexus.v9.deadline.new"])
        await service.reconcile(snapshot: snapshot, preferences: preferences)
        XCTAssertEqual(fake.removed, ["nexus.v9.deadline.old"])
        XCTAssertEqual(fake.added.map(\.id), ["nexus.v9.deadline.new"])
        XCTAssertFalse(fake.removed.contains("another.app.request"))
        XCTAssertEqual(service.scheduledCount, 1)
    }

    func testDeniedAndNotDeterminedReconcileNeverRequestOrSchedule() async {
        for state in [NotificationAuthorizationState.denied, .notDetermined] {
            let fake = FakeNotificationCenter(state: state)
            fake.pending = ["nexus.v9.lesson.old"]
            let service = LocalNotificationService(client: fake, defaults: isolatedDefaults())
            await service.reconcile(snapshot: NotificationPlanningSnapshot(lessons: [NotificationLessonSource(occurrenceID: "new", courseID: UUID(), title: "Ders", start: date(hour: 12), end: date(hour: 13))]), preferences: preferences)
            XCTAssertEqual(fake.requestCount, 0)
            XCTAssertTrue(fake.added.isEmpty)
            XCTAssertEqual(fake.removed, ["nexus.v9.lesson.old"])
        }
    }

    func testAuthorizationRequestOccursOnlyFromExplicitEnableAction() async {
        let fake = FakeNotificationCenter(state: .notDetermined)
        let defaults = isolatedDefaults()
        let service = LocalNotificationService(client: fake, defaults: defaults)
        await service.reconcile(snapshot: .init(), preferences: preferences)
        XCTAssertEqual(fake.requestCount, 0)
        fake.requestResult = true
        await service.enableFromExplicitUserAction(snapshot: .init(), preferences: preferences)
        XCTAssertEqual(fake.requestCount, 1)
        XCTAssertTrue(defaults.bool(forKey: "notifications.enabled"))
    }

    func testAppLockInitializesDisabledWithoutAuthentication() {
        let auth = FakeBiometricAuthenticator()
        let store = FakeSecureBoolStore(value: false)
        let lock = AppLockCoordinator(authenticator: auth, secureStore: store, defaults: isolatedDefaults())
        lock.initialize()
        XCTAssertEqual(lock.state, .disabled)
        XCTAssertFalse(lock.blocksAccess)
        XCTAssertEqual(auth.authenticationCount, 0)
    }

    func testEnabledFlagStartsLockedAndDoesNotExposeData() {
        let lock = AppLockCoordinator(authenticator: FakeBiometricAuthenticator(), secureStore: FakeSecureBoolStore(value: true), defaults: isolatedDefaults())
        lock.initialize()
        XCTAssertEqual(lock.state, .locked)
        XCTAssertTrue(lock.blocksAccess)
    }

    func testExplicitEnableAuthenticatesBeforeWritingSecureFlag() async {
        let auth = FakeBiometricAuthenticator()
        let store = FakeSecureBoolStore(value: false)
        let lock = AppLockCoordinator(authenticator: auth, secureStore: store, defaults: isolatedDefaults())
        lock.initialize()
        await lock.enable()
        XCTAssertEqual(auth.authenticationCount, 1)
        XCTAssertEqual(store.writes, [true])
        XCTAssertTrue(lock.isEnabled)
        XCTAssertEqual(lock.state, .unlocked)
    }

    func testUnavailableBiometricCannotEnableAndDoesNotBlockDisabledApp() async {
        let auth = FakeBiometricAuthenticator(availability: .unavailable("Yok"))
        let store = FakeSecureBoolStore(value: false)
        let lock = AppLockCoordinator(authenticator: auth, secureStore: store, defaults: isolatedDefaults())
        lock.initialize()
        await lock.enable()
        XCTAssertEqual(lock.state, .unavailable("Yok"))
        XCTAssertTrue(store.writes.isEmpty)
        XCTAssertFalse(lock.isEnabled)
        XCTAssertFalse(lock.blocksAccess)
    }

    func testFailedAuthenticationDoesNotEnableOrWriteFlag() async {
        let auth = FakeBiometricAuthenticator(result: .failure(NSError(domain: "test", code: 1)))
        let store = FakeSecureBoolStore(value: false)
        let lock = AppLockCoordinator(authenticator: auth, secureStore: store, defaults: isolatedDefaults())
        lock.initialize()
        await lock.enable()
        XCTAssertFalse(lock.isEnabled)
        XCTAssertEqual(lock.state, .disabled)
        XCTAssertTrue(store.writes.isEmpty)
    }

    func testInactivityLocksOnlyAtConfiguredThresholdAndPrivacyMaskCoversInactiveState() async {
        let defaults = isolatedDefaults(); defaults.set(true, forKey: "security.privacyMask")
        let enabledStore = FakeSecureBoolStore(value: false)
        let enabled = AppLockCoordinator(authenticator: FakeBiometricAuthenticator(), secureStore: enabledStore, defaults: defaults)
        enabled.initialize()
        await enabled.enable()
        enabled.becameInactive(at: date())
        XCTAssertTrue(enabled.privacyMaskVisible)
        enabled.becameActive(at: date(hour: 10, minute: 0).addingTimeInterval(59), timeoutSeconds: 60)
        XCTAssertEqual(enabled.state, .unlocked)
        enabled.becameInactive(at: date())
        enabled.becameActive(at: date().addingTimeInterval(60), timeoutSeconds: 60)
        XCTAssertEqual(enabled.state, .locked)
        XCTAssertFalse(enabled.privacyMaskVisible)
    }

    func testBackupSchemaV9AcceptsV8AndContainsNoPermissionOrCredentialFields() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let backup = try BackupService.export(from: container.mainContext)
        XCTAssertEqual(backup.schemaVersion, 9)
        let json = String(data: try JSONEncoder().encode(backup), encoding: .utf8)!
        XCTAssertFalse(json.contains("authorizationState"))
        XCTAssertFalse(json.contains("touch-id-lock-enabled"))
        let legacy = NEXUSBackup(schemaVersion: 8, createdAt: date(), courses: [], tasks: [], goals: [], sessions: [])
        XCTAssertNoThrow(try BackupService.validate(legacy))
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "NEXUS.Phase9Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

private final class FakeNotificationCenter: LocalNotificationCenterClient {
    var state: NotificationAuthorizationState
    var requestResult = false
    var requestCount = 0
    var pending: Set<String> = []
    var added: [PlannedLocalNotification] = []
    var removed: [String] = []

    init(state: NotificationAuthorizationState) { self.state = state }
    func authorizationState() async -> NotificationAuthorizationState { state }
    func requestAuthorization() async throws -> Bool { requestCount += 1; state = requestResult ? .authorized : .denied; return requestResult }
    func pendingIdentifiers() async -> Set<String> { pending }
    func add(_ notification: PlannedLocalNotification) async throws { added.append(notification); pending.insert(notification.id) }
    func removePending(identifiers: [String]) { removed += identifiers.sorted(); pending.subtract(identifiers) }
}

private final class FakeBiometricAuthenticator: BiometricAuthenticating {
    var availabilityValue: BiometricAvailability
    var result: Result<Void, Error>
    var authenticationCount = 0
    init(availability: BiometricAvailability = .available, result: Result<Void, Error> = .success(())) { availabilityValue = availability; self.result = result }
    func availability() -> BiometricAvailability { availabilityValue }
    func authenticate(reason: String) async -> Result<Void, Error> { authenticationCount += 1; return result }
}

private final class FakeSecureBoolStore: SecureBoolStore {
    var value: Bool
    var writes: [Bool] = []
    init(value: Bool) { self.value = value }
    func read() throws -> Bool { value }
    func write(_ value: Bool) throws { self.value = value; writes.append(value) }
}
