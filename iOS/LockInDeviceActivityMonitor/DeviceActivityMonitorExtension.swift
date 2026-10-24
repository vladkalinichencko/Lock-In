import DeviceActivity
import Foundation
import os
import UserNotifications

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let storage = LockInSharedStore()
    private let enforcer = LockInEnforcer()
    private let logger = Logger(subsystem: "com.local.LockIn", category: "DeviceActivityMonitor")

    override func intervalDidStart(for activity: DeviceActivityName) {
        reconcile()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        reconcile()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        guard activity == LockInConstants.activityName else { return }
        reconcile(event: event)
    }

    private func reconcile(event: DeviceActivityEvent.Name? = nil) {
        do {
            let now = Date()
            var restartSession = false
            var warning = 0
            let snapshot = try storage.update { snapshot in
                let sessionID = snapshot.sessionID
                snapshot.reconcile(at: now)
                restartSession = sessionID != snapshot.sessionID
                guard let event, !snapshot.isBlocking(at: now),
                      let minutes = LockInSchedule.thresholdMinutes(event, snapshot: snapshot),
                      minutes > 0, minutes <= snapshot.sessionLimitMinutes else { return }
                snapshot.recordThreshold(minutes: minutes, at: now)
                let remaining = snapshot.sessionLimitMinutes - minutes
                if remaining > 0, remaining <= snapshot.restrictions.warningMinutes(for: snapshot.sessionLimitMinutes),
                   !snapshot.warningSentForSession {
                    snapshot.warningSentForSession = true
                    warning = remaining
                }
            }
            enforcer.reconcileShield(snapshot: snapshot, at: now)
            if restartSession, snapshot.hasSelection {
                try enforcer.startMonitoring(snapshot: snapshot)
            }
            try enforcer.scheduleSessionEnd(snapshot: snapshot, at: now)
            if warning > 0 { sendWarning(minutes: warning) }
        } catch {
            logger.error("Restriction update failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func sendWarning(minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Blocking soon"
        content.body = "Selected apps and websites will lock in \(minutes) minutes."
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: "lockin.warning", content: content, trigger: nil
        ))
    }
}
