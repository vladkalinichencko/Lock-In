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
        if let downtime = snapshot.restrictions.downtime {
            try activityCenter.startMonitoring(
                LockInConstants.downtimeActivityName,
                during: LockInSchedule.downtimeSchedule(for: downtime)
            )
        } else {
            activityCenter.stopMonitoring([LockInConstants.downtimeActivityName])
        }
    }

    func stopMonitoring() {
        activityCenter.stopMonitoring([LockInConstants.activityName, LockInConstants.breakActivityName, LockInConstants.focusActivityName, LockInConstants.downtimeActivityName])
    }

    func startFocusMonitoring(from start: Date, until end: Date) throws {
        try activityCenter.startMonitoring(
            LockInConstants.focusActivityName,
            during: LockInSchedule.focusSchedule(from: start, until: end)
        )
    }

    func stopFocusMonitoring() {
        activityCenter.stopMonitoring([LockInConstants.focusActivityName])
    }

    func reconcileShield(snapshot: LockInSnapshot, at date: Date = Date()) {
        if snapshot.isBlocking(at: date) {
            applyShield(selection: snapshot.selection)
        } else {
            clearShield()
        }
    }

    func startBreakMonitoring(from start: Date, until end: Date, calendar: Calendar = .current) throws {
        let schedule = LockInSchedule.focusSchedule(from: min(start, end.addingTimeInterval(-900)), until: end, calendar: calendar)
        guard activityCenter.schedule(for: LockInConstants.breakActivityName)?.intervalEnd != schedule.intervalEnd else { return }
        try activityCenter.startMonitoring(
            LockInConstants.breakActivityName,
            during: schedule
        )
    }

    func scheduleSessionEnd(snapshot: LockInSnapshot, at date: Date) throws {
        let end = snapshot.cooldownUntil ?? snapshot.restrictions.residualReset(
            lastUsedAt: snapshot.lastUsedAt, secondsUsed: snapshot.currentSessionSecondsUsed,
            sessionMinutes: snapshot.sessionLimitMinutes, breakMinutes: snapshot.breakMinutes
        )?.addingTimeInterval(60)
        if let end, end > date {
            try startBreakMonitoring(from: date, until: end)
        } else {
            activityCenter.stopMonitoring([LockInConstants.breakActivityName])
        }
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
