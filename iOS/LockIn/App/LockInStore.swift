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
            do {
                snapshot = try storage.update { $0.focusMinutes = newValue }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func startFocus(minutes: Int, now: Date = Date()) throws {
        refreshAuthorizationStatus()
        guard isAuthorized else { throw LockInStoreError.screenTimeRequired }
        guard (15...1440).contains(minutes) else { throw LockInStoreError.invalidFocusDuration }
        snapshot = try storage.update { snapshot in
            snapshot.reconcile(at: now)
            guard snapshot.hasSelection else { throw LockInStoreError.selectionRequired }
            guard !snapshot.isFocusing(at: now) else { return }
            let end = Date(timeIntervalSince1970: (now.timeIntervalSince1970 + Double(minutes * 60)).rounded(.up))
            try enforcer.startFocusMonitoring(from: now, until: end)
            snapshot.focusMinutes = minutes
            snapshot.focusUntil = end
            snapshot.focusPausedAt = nil
        }
        enforcer.reconcileShield(snapshot: snapshot, at: now)
        errorMessage = nil
    }

    func refreshState() {
        do {
            let previousSessionID = snapshot.sessionID
            snapshot = try storage.update { $0.reconcile(at: Date()) }
            if isAuthorized, snapshot.hasSelection, previousSessionID != snapshot.sessionID {
                try enforcer.startMonitoring(snapshot: snapshot)
                try enforcer.scheduleSessionEnd(snapshot: snapshot, at: Date())
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        guard isAuthorized else { return }
        enforcer.reconcileShield(snapshot: snapshot)
    }

    func toggleFocusPause(now: Date = Date()) throws {
        snapshot = try storage.update { updated in
            guard updated.isFocusing(at: now) else { return }
            updated.toggleFocusPause(at: now)
            if updated.focusPausedAt == nil, let end = updated.focusUntil {
                let duration = TimeInterval((updated.focusMinutes ?? 25) * 60)
                try enforcer.startFocusMonitoring(from: end.addingTimeInterval(-duration), until: end)
            }
        }
        if snapshot.focusPausedAt != nil {
            enforcer.stopFocusMonitoring()
        }
        enforcer.reconcileShield(snapshot: snapshot, at: now)
        errorMessage = nil
    }

    init() {
        refreshAuthorizationStatus()
        refreshState()
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
        updatePolicy { $0.selection = selection }
    }

    func updateSessionLimitMinutes(_ value: Int) {
        updatePolicy { $0.sessionLimitMinutes = LockInPolicy.clamp(value, min: 1, max: 480) }
    }

    func updateSessionCountLimit(_ value: Int) {
        updatePolicy { $0.sessionCountLimit = LockInPolicy.clamp(value, min: 1, max: 24) }
    }

    func updateBreakMinutes(_ value: Int) {
        updatePolicy { $0.breakMinutes = LockInPolicy.clamp(value, min: 1, max: 1440) }
    }

    func updateResetTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        updatePolicy { snapshot in
            snapshot.resetHour = components.hour ?? snapshot.resetHour
            snapshot.resetMinute = components.minute ?? snapshot.resetMinute
            snapshot.windowStart = LockInSchedule.dayWindowStart(for: Date(), snapshot: snapshot)
        }
    }

    func updateTimeRestrictions(_ value: TimeRestrictions) {
        updatePolicy { $0.timeRestrictions = value }
    }

    private func updatePolicy(_ change: (inout LockInSnapshot) -> Void) {
        do {
            snapshot = try storage.update { snapshot in
                snapshot.reconcile(at: Date())
                if snapshot.canEditPolicy { change(&snapshot) }
            }
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
        try enforcer.scheduleSessionEnd(snapshot: snapshot, at: Date())
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
            "Allow notifications in Settings to receive the limit warning."
        case .screenTimeRequired:
            "Allow Screen Time access to start focus."
        case .selectionRequired:
            "Select apps or websites to start focus."
        case .invalidFocusDuration:
            "Focus must last between 15 and 1440 minutes."
        }
    }
}
