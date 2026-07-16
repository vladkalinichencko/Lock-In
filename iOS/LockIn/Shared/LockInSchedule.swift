import DeviceActivity
import Foundation

enum LockInSchedule {
    static func dayWindowStart(for date: Date, snapshot: LockInSnapshot, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = snapshot.resetHour
        components.minute = snapshot.resetMinute
        components.second = 0
        let start = calendar.date(from: components) ?? date
        if date >= start {
            return start
        }
        return calendar.date(byAdding: .day, value: -1, to: start) ?? start
    }

    static func nextReset(after date: Date, snapshot: LockInSnapshot, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: dayWindowStart(for: date, snapshot: snapshot, calendar: calendar)) ?? date
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

