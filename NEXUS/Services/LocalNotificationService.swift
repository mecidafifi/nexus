import Foundation
import UserNotifications

protocol LocalNotificationCenterClient {
    func authorizationState() async -> NotificationAuthorizationState
    func requestAuthorization() async throws -> Bool
    func pendingIdentifiers() async -> Set<String>
    func add(_ notification: PlannedLocalNotification) async throws
    func removePending(identifiers: [String])
}

final class SystemLocalNotificationCenter: LocalNotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) { self.center = center }

    func authorizationState() async -> NotificationAuthorizationState {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .ephemeral: return .ephemeral
        @unknown default: return .unknown
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func pendingIdentifiers() async -> Set<String> {
        let requests = await center.pendingNotificationRequests()
        return Set(requests.map(\.identifier))
    }

    func add(_ notification: PlannedLocalNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.categoryIdentifier = "NEXUS_\(notification.category.rawValue.uppercased())"
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notification.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger))
    }

    func removePending(identifiers: [String]) { center.removePendingNotificationRequests(withIdentifiers: identifiers) }
}

@MainActor
final class LocalNotificationService: ObservableObject {
    @Published private(set) var authorizationState: NotificationAuthorizationState = .unknown
    @Published private(set) var scheduledCount = 0
    @Published private(set) var isWorking = false
    @Published private(set) var auditMessageKey = "notifications.audit.ready"
    @Published private(set) var errorMessage: String?

    private let client: LocalNotificationCenterClient
    private let defaults: UserDefaults
    private let now: () -> Date

    init(client: LocalNotificationCenterClient = SystemLocalNotificationCenter(), defaults: UserDefaults = .standard, now: @escaping () -> Date = { .now }) {
        self.client = client
        self.defaults = defaults
        self.now = now
    }

    func refreshStatus() async {
        authorizationState = await client.authorizationState()
        let pending = await client.pendingIdentifiers()
        scheduledCount = pending.filter { $0.hasPrefix(PlannedLocalNotification.identifierPrefix) }.count
    }

    /// This is the only method that may request notification authorization. It
    /// is called exclusively by the explicit Settings action.
    func enableFromExplicitUserAction(snapshot: NotificationPlanningSnapshot, preferences: LocalNotificationPreferences) async {
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        var state = await client.authorizationState()
        if state == .notDetermined {
            do {
                let granted = try await client.requestAuthorization()
                state = granted ? .authorized : .denied
            } catch {
                errorMessage = error.localizedDescription
                auditMessageKey = "notifications.audit.requestFailed"
                authorizationState = await client.authorizationState()
                return
            }
        }
        authorizationState = state
        guard state.permitsScheduling else {
            defaults.set(false, forKey: "notifications.enabled")
            auditMessageKey = state == .denied ? "notifications.audit.denied" : "notifications.audit.notAuthorized"
            await cancelNexusPending()
            return
        }
        defaults.set(true, forKey: "notifications.enabled")
        var enabled = preferences
        enabled.enabled = true
        await reconcile(snapshot: snapshot, preferences: enabled)
    }

    func reconcile(snapshot: NotificationPlanningSnapshot, preferences: LocalNotificationPreferences) async {
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        authorizationState = await client.authorizationState()
        guard preferences.enabled, authorizationState.permitsScheduling else {
            await cancelNexusPending()
            auditMessageKey = preferences.enabled ? "notifications.audit.notAuthorized" : "notifications.audit.disabled"
            return
        }

        let desired = LocalNotificationPlanner.plan(snapshot: snapshot, preferences: preferences, now: now())
        let desiredIDs = Set(desired.map(\.id))
        let existing = await client.pendingIdentifiers().filter { $0.hasPrefix(PlannedLocalNotification.identifierPrefix) }
        let obsolete = Array(existing.subtracting(desiredIDs))
        if !obsolete.isEmpty { client.removePending(identifiers: obsolete) }
        do {
            // Re-adding a stable identifier replaces an edited request without
            // producing duplicates in UNUserNotificationCenter.
            for request in desired { try await client.add(request) }
            scheduledCount = desired.count
            auditMessageKey = desired.isEmpty ? "notifications.audit.noneApplicable" : "notifications.audit.scheduled"
        } catch {
            errorMessage = error.localizedDescription
            auditMessageKey = "notifications.audit.scheduleFailed"
            await refreshStatus()
        }
    }

    func disableAndCancel() async {
        defaults.set(false, forKey: "notifications.enabled")
        await cancelNexusPending()
        await refreshStatus()
        auditMessageKey = "notifications.audit.disabled"
    }

    private func cancelNexusPending() async {
        let pending = await client.pendingIdentifiers().filter { $0.hasPrefix(PlannedLocalNotification.identifierPrefix) }
        if !pending.isEmpty { client.removePending(identifiers: Array(pending)) }
        scheduledCount = 0
    }
}
