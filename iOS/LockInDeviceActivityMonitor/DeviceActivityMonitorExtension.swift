import DeviceActivity
import Foundation
import os
import UserNotifications

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let storage = LockInSharedStore()
    private let enforcer = LockInEnforcer()
    private let logger = Logger(subsystem: "com.local.LockIn", category: "DeviceActivityMonitor")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        if activity == LockInConstants.activityName {
            resetDailyState()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        if activity == LockInConstants.breakActivityName {
            finishBreak()
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        if event == LockInConstants.warningEventName {
            sendWarning()
        }

        if event == LockInConstants.sessionLimitEventName {
            startBlock()
        }
    }

    private func resetDailyState() {
        do {
            var snapshot = try storage.load()
            snapshot.completedSessionCount = 0
            snapshot.cumulativeSecondsUsed = 0
            snapshot.currentSessionSecondsUsed = 0
            snapshot.cooldownUntil = nil
            snapshot.warningSentForSession = false
            try storage.save(snapshot)
            enforcer.clearShield()
        } catch {
            logger.error("Daily reset failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func sendWarning() {
        do {
            var snapshot = try storage.load()
            guard !snapshot.warningSentForSession else {
                return
            }
            snapshot.warningSentForSession = true
            try storage.save(snapshot)

            let content = UNMutableNotificationContent()
            content.title = "Blocking soon"
            content.body = "Selected apps and websites will lock in 5 minutes."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "lockin.warning", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Warning notification failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func startBlock() {
        do {
            var snapshot = try storage.load()
            let now = Date()
            snapshot.completedSessionCount += 1
            snapshot.currentSessionSecondsUsed = snapshot.sessionLimitMinutes * 60
            snapshot.cumulativeSecondsUsed += snapshot.sessionLimitMinutes * 60
            snapshot.warningSentForSession = false
            enforcer.applyShield(selection: snapshot.selection)

            if snapshot.completedSessionCount >= snapshot.sessionCountLimit {
                snapshot.cooldownUntil = LockInSchedule.nextReset(after: now, snapshot: snapshot)
            } else {
                let end = now.addingTimeInterval(TimeInterval(snapshot.breakMinutes * 60))
                snapshot.cooldownUntil = end
                try enforcer.startBreakMonitoring(from: now, until: end)
            }

            try storage.save(snapshot)
        } catch {
            logger.error("Session block failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func finishBreak() {
        do {
            var snapshot = try storage.load()
            snapshot.currentSessionSecondsUsed = 0
            snapshot.cooldownUntil = nil
            snapshot.warningSentForSession = false
            try storage.save(snapshot)
            enforcer.clearShield()
            if snapshot.hasSelection {
                try enforcer.startMonitoring(snapshot: snapshot)
            }
        } catch {
            logger.error("Break finish failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
