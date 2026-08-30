import Foundation
import LocalAuthentication
import Security

enum BiometricAvailability: Equatable {
    case available
    case unavailable(String)
}

protocol BiometricAuthenticating {
    func availability() -> BiometricAvailability
    func authenticate(reason: String) async -> Result<Void, Error>
}

final class SystemBiometricAuthenticator: BiometricAuthenticating {
    func availability() -> BiometricAvailability {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .unavailable(error?.localizedDescription ?? String(localized: "lock.error.unavailable"))
        }
        return .available
    }

    func authenticate(reason: String) async -> Result<Void, Error> {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "action.cancel")
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if success { continuation.resume(returning: .success(())) }
                else { continuation.resume(returning: .failure(error ?? AppLockError.authenticationFailed)) }
            }
        }
    }
}

protocol SecureBoolStore {
    func read() throws -> Bool
    func write(_ value: Bool) throws
}

struct KeychainBoolStore: SecureBoolStore {
    private let service = "com.nexus.studentlife.security"
    private let account = "touch-id-lock-enabled"

    func read() throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return false }
        guard status == errSecSuccess, let data = result as? Data else { throw AppLockError.keychain(status) }
        return data.first == 1
    }

    func write(_ value: Bool) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if !value {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw AppLockError.keychain(status) }
            return
        }
        let update: [String: Any] = [kSecValueData as String: Data([1])]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addition = query
            addition[kSecValueData as String] = Data([1])
            addition[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addition as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw AppLockError.keychain(addStatus) }
        } else if updateStatus != errSecSuccess { throw AppLockError.keychain(updateStatus) }
    }
}

enum AppLockError: LocalizedError {
    case authenticationFailed
    case unavailable(String)
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .authenticationFailed: String(localized: "lock.error.failed")
        case .unavailable(let detail): detail
        case .keychain(let status): String(format: String(localized: "lock.error.keychain"), Int(status))
        }
    }
}

@MainActor
final class AppLockCoordinator: ObservableObject {
    enum State: Equatable { case initializing, disabled, unlocked, locked, authenticating, unavailable(String) }

    @Published private(set) var state: State = .initializing
    @Published private(set) var isEnabled = false
    @Published private(set) var privacyMaskVisible = false
    @Published private(set) var errorMessage: String?

    private let authenticator: BiometricAuthenticating
    private let secureStore: SecureBoolStore
    private let defaults: UserDefaults
    private var inactiveAt: Date?
    private var backgroundLockTask: Task<Void, Never>?

    init(authenticator: BiometricAuthenticating = SystemBiometricAuthenticator(), secureStore: SecureBoolStore = KeychainBoolStore(), defaults: UserDefaults = .standard) {
        self.authenticator = authenticator
        self.secureStore = secureStore
        self.defaults = defaults
    }

    var blocksAccess: Bool {
        switch state {
        case .locked, .authenticating, .initializing: true
        case .unavailable: isEnabled
        case .disabled, .unlocked: false
        }
    }

    func initialize() {
        guard state == .initializing else { return }
        do {
            isEnabled = try secureStore.read()
            if isEnabled {
                switch authenticator.availability() {
                case .available: state = .locked
                case .unavailable(let detail): state = .unavailable(detail)
                }
            } else { state = .disabled }
        } catch {
            errorMessage = error.localizedDescription
            isEnabled = false
            state = .disabled
        }
    }

#if DEBUG
    /// XCTest hosts must not inherit the signed user's Keychain lock flag.
    /// Production builds do not contain this path.
    func initializeForAutomatedTests() {
        isEnabled = false
        privacyMaskVisible = false
        errorMessage = nil
        state = .disabled
    }
#endif

    func enable() async {
        errorMessage = nil
        switch authenticator.availability() {
        case .unavailable(let detail): state = .unavailable(detail); return
        case .available: break
        }
        state = .authenticating
        switch await authenticator.authenticate(reason: String(localized: "lock.enable.reason")) {
        case .success:
            do {
                try secureStore.write(true)
                isEnabled = true; state = .unlocked
                NotificationCenter.default.post(name: .nexusNotificationSettingsChanged, object: nil)
            } catch { errorMessage = error.localizedDescription; isEnabled = false; state = .disabled }
        case .failure(let error):
            errorMessage = error.localizedDescription
            isEnabled = false; state = .disabled
        }
    }

    func unlock() async {
        guard isEnabled else { state = .disabled; return }
        switch authenticator.availability() {
        case .unavailable(let detail): state = .unavailable(detail); return
        case .available: break
        }
        state = .authenticating
        switch await authenticator.authenticate(reason: String(localized: "lock.unlock.reason")) {
        case .success: state = .unlocked; errorMessage = nil
        case .failure(let error): state = .locked; errorMessage = error.localizedDescription
        }
    }

    func disable() {
        do {
            try secureStore.write(false)
            isEnabled = false; state = .disabled; errorMessage = nil
            NotificationCenter.default.post(name: .nexusNotificationSettingsChanged, object: nil)
        } catch { errorMessage = error.localizedDescription }
    }

    func becameInactive(at date: Date, timeoutSeconds: Int? = nil) {
        inactiveAt = date
        privacyMaskVisible = defaults.object(forKey: "security.privacyMask") as? Bool ?? true
        backgroundLockTask?.cancel()
        guard isEnabled, let timeoutSeconds else { return }
        let bounded = max(timeoutSeconds, 0)
        backgroundLockTask = Task { @MainActor [weak self] in
            if bounded > 0 { try? await Task.sleep(for: .seconds(bounded)) }
            guard let self, !Task.isCancelled, self.inactiveAt == date, self.isEnabled else { return }
            switch self.authenticator.availability() {
            case .available: self.state = .locked
            case .unavailable(let detail): self.state = .unavailable(detail)
            }
        }
    }

    func becameActive(at date: Date, timeoutSeconds: Int) {
        backgroundLockTask?.cancel()
        backgroundLockTask = nil
        privacyMaskVisible = false
        guard isEnabled else { return }
        if let inactiveAt, date.timeIntervalSince(inactiveAt) >= TimeInterval(max(timeoutSeconds, 0)) {
            switch authenticator.availability() {
            case .available: state = .locked
            case .unavailable(let detail): state = .unavailable(detail)
            }
        }
        inactiveAt = nil
    }

    func lockNow() {
        guard isEnabled else { return }
        state = .locked
    }
}
