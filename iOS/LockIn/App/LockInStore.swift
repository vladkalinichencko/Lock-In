import FamilyControls
import Foundation
import Observation
import UserNotifications

@Observable
@MainActor
final class LockInStore {
    static let shared = LockInStore()
    var snapshot = LockInSnapshot()
    var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    var isPickerPresented = false
    var errorMessage: String?
    var notificationErrorMessage: String?
    var notificationStatus: UNAuthorizationStatus = .notDetermined

    private let storage = LockInSharedStore()
    private let enforcer = LockInEnforcer()

    var focusMinutes: Int {
        get { snapshot.focusMinutes ?? 25 }
        set {
            snapshot.focusMinutes = newValue
            do {
                try storage.save(snapshot)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func startFocus(minutes: Int, now: Date = Date()) throws {
        snapshot = try storage.load()
        refreshAuthorizationStatus()
        guard isAuthorized else { throw LockInStoreError.screenTimeRequired }
        guard snapshot.hasSelection else { throw LockInStoreError.selectionRequired }
        guard (15...1440).contains(minutes) else { throw LockInStoreError.invalidFocusDuration }
        guard !snapshot.isFocusing(at: now) else { return }
        let end = Date(timeIntervalSince1970: (now.timeIntervalSince1970 + Double(minutes * 60)).rounded(.up))
        try enforcer.startFocusMonitoring(from: now, until: end)
        snapshot.focusMinutes = minutes
        snapshot.focusUntil = end
        try storage.save(snapshot)
        enforcer.reconcileShield(snapshot: snapshot, at: now)
        errorMessage = nil
    }

    func refreshState() {
        do {
            snapshot = try storage.load()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        guard isAuthorized else { return }
        if let end = snapshot.focusUntil, end <= Date() {
            snapshot.focusUntil = nil
            do {
                try storage.save(snapshot)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        enforcer.reconcileShield(snapshot: snapshot)
    }

    init() {
        refreshAuthorizationStatus()
        load()
    }

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .approved, .approvedWithDataAccess:
            true
        default:
            false
        }
    }

    var isNotificationAuthorized: Bool {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            true
        default:
            false
        }
    }

    func load() {
        do {
            snapshot = try storage.load()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            try applyPolicy()
            errorMessage = nil
        } catch {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            errorMessage = error.localizedDescription
        }
    }

    func requestNotificationAuthorizationOnLaunch() async {
        do {
            try await requestNotificationAuthorization()
            notificationErrorMessage = nil
        } catch {
            notificationErrorMessage = error.localizedDescription
        }
        await refreshNotificationStatus()
    }

    func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func saveSelection(_ selection: FamilyActivitySelection) {
        guard snapshot.canEditPolicy else { return }
        snapshot.selection = selection
        saveAndApply()
    }

    func updateSessionLimitMinutes(_ value: Int) {
        guard snapshot.canEditPolicy else {
            return
        }
        snapshot.sessionLimitMinutes = LockInSnapshot.clamp(value, min: 1, max: 480)
        saveAndApply()
    }

    func updateSessionCountLimit(_ value: Int) {
        guard snapshot.canEditPolicy else {
            return
        }
        snapshot.sessionCountLimit = LockInSnapshot.clamp(value, min: 1, max: 24)
        saveAndApply()
    }

    func updateBreakMinutes(_ value: Int) {
        guard snapshot.canEditPolicy else {
            return
        }
        snapshot.breakMinutes = LockInSnapshot.clamp(value, min: 1, max: 1440)
        saveAndApply()
    }

    func updateResetTime(_ date: Date) {
        guard snapshot.canEditPolicy else {
            return
        }
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        snapshot.resetHour = LockInSnapshot.clamp(components.hour ?? snapshot.resetHour, min: 0, max: 23)
        snapshot.resetMinute = LockInSnapshot.clamp(components.minute ?? snapshot.resetMinute, min: 0, max: 59)
        saveAndApply()
    }

    private func saveAndApply() {
        do {
            try storage.save(snapshot)
            try applyPolicy()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyPolicy() throws {
        guard isAuthorized else {
            enforcer.stopMonitoring()
            return
        }
        guard snapshot.hasSelection else {
            enforcer.stopMonitoring()
            enforcer.clearShield()
            return
        }
        try enforcer.startMonitoring(snapshot: snapshot)
        enforcer.reconcileShield(snapshot: snapshot)
    }

    private func requestNotificationAuthorization() async throws {
        await refreshNotificationStatus()
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return
        case .denied:
            throw LockInStoreError.notificationsDenied
        case .notDetermined:
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            guard granted else {
                throw LockInStoreError.notificationsDenied
            }
         default:
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            guard granted else {
                throw LockInStoreError.notificationsDenied
            }
        }
    }
}

enum LockInStoreError: LocalizedError {
    case notificationsDenied
    case screenTimeRequired
    case selectionRequired
    case invalidFocusDuration

    var errorDescription: String? {
        switch self {
        case .notificationsDenied:
            "Notification permission is required for the 5-minute warning."
        case .screenTimeRequired:
            "Allow Screen Time access to start focus."
        case .selectionRequired:
            "Select apps or websites to start focus."
        case .invalidFocusDuration:
            "Focus must last between 15 and 1440 minutes."
        }
    }
}
