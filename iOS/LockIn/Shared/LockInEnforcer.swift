import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

struct LockInEnforcer {
    private let managedStore = ManagedSettingsStore(named: LockInConstants.storeName)
    private let activityCenter = DeviceActivityCenter()

    func startMonitoring(snapshot: LockInSnapshot) throws {
        try activityCenter.startMonitoring(
            LockInConstants.activityName,
            during: LockInSchedule.deviceActivitySchedule(for: snapshot),
            events: LockInSchedule.events(for: snapshot)
        )
    }

    func stopMonitoring() {
        activityCenter.stopMonitoring([LockInConstants.activityName, LockInConstants.breakActivityName, LockInConstants.focusActivityName])
    }

    func startFocusMonitoring(from start: Date, until end: Date) throws {
        try activityCenter.startMonitoring(
            LockInConstants.focusActivityName,
            during: LockInSchedule.focusSchedule(from: start, until: end)
        )
    }

    func reconcileShield(snapshot: LockInSnapshot, at date: Date = Date()) {
        if snapshot.isBlocking(at: date) {
            applyShield(selection: snapshot.selection)
        } else {
            clearShield()
        }
    }

    func startBreakMonitoring(from start: Date, until end: Date, calendar: Calendar = .current) throws {
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: end)
        try activityCenter.startMonitoring(
            LockInConstants.breakActivityName,
            during: DeviceActivitySchedule(
                intervalStart: startComponents,
                intervalEnd: endComponents,
                repeats: false
            )
        )
    }

    func applyShield(selection: FamilyActivitySelection) {
        managedStore.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        managedStore.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        managedStore.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        managedStore.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
    }

    func clearShield() {
        managedStore.clearAllSettings()
    }
}
