import DeviceActivity
import Foundation

enum LockInSchedule {
    static func dayWindowStart(for date: Date, snapshot: LockInSnapshot, calendar: Calendar = .current) -> Date {
        LockInPolicy.dayWindowStart(
            for: date,
            resetHour: snapshot.resetHour,
            resetMinute: snapshot.resetMinute,
            calendar: calendar
        )
    }

    static func nextReset(after date: Date, snapshot: LockInSnapshot, calendar: Calendar = .current) -> Date {
        LockInPolicy.nextReset(
            after: date,
            resetHour: snapshot.resetHour,
            resetMinute: snapshot.resetMinute,
            calendar: calendar
        )
    }

    static func deviceActivitySchedule(for snapshot: LockInSnapshot) -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: snapshot.resetHour, minute: snapshot.resetMinute),
            intervalEnd: DateComponents(hour: snapshot.resetHour, minute: snapshot.resetMinute),
            repeats: true
        )
    }

    static func events(for snapshot: LockInSnapshot) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            LockInConstants.sessionLimitEventName: DeviceActivityEvent(
                applications: snapshot.selection.applicationTokens,
                categories: snapshot.selection.categoryTokens,
                webDomains: snapshot.selection.webDomainTokens,
                threshold: DateComponents(minute: snapshot.sessionLimitMinutes),
                includesPastActivity: false
            )
        ]

        if snapshot.sessionLimitMinutes > 5 {
            events[LockInConstants.warningEventName] = DeviceActivityEvent(
                applications: snapshot.selection.applicationTokens,
                categories: snapshot.selection.categoryTokens,
                webDomains: snapshot.selection.webDomainTokens,
                threshold: DateComponents(minute: snapshot.sessionLimitMinutes - 5),
                includesPastActivity: false
            )
        }

        return events
    }
}
