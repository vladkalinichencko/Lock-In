import DeviceActivity
import Foundation

enum LockInSchedule {
    static func focusSchedule(
        from start: Date, until end: Date, calendar: Calendar = .current
    ) -> DeviceActivitySchedule {
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let end = Date(timeIntervalSince1970: end.timeIntervalSince1970.rounded(.up))
        return DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: start),
            intervalEnd: calendar.dateComponents(components, from: end),
            repeats: false
        )
    }

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
        Dictionary(uniqueKeysWithValues: (1...snapshot.sessionLimitMinutes)
            .filter { $0 * 60 > snapshot.currentSessionSecondsUsed }.map { minute in
                (eventName(minutes: minute, snapshot: snapshot), DeviceActivityEvent(
                    applications: snapshot.selection.applicationTokens,
                    categories: snapshot.selection.categoryTokens,
                    webDomains: snapshot.selection.webDomainTokens,
                    threshold: DateComponents(minute: minute - snapshot.currentSessionSecondsUsed / 60),
                    includesPastActivity: false
                ))
            })
    }

    static func eventName(minutes: Int, snapshot: LockInSnapshot) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("\(snapshot.sessionID?.uuidString ?? "initial"):\(minutes)")
    }

    static func thresholdMinutes(_ event: DeviceActivityEvent.Name, snapshot: LockInSnapshot) -> Int? {
        let parts = event.rawValue.split(separator: ":")
        guard parts.count == 2, parts[0] == (snapshot.sessionID?.uuidString ?? "initial") else { return nil }
        return Int(parts[1])
    }

    static func downtimeSchedule(for interval: ClockInterval) -> DeviceActivitySchedule {
        let duration = (interval.end - interval.start + 1440) % 1440
        let reverse = duration > 0 && duration < 15
        let start = reverse ? interval.end : interval.start
        let end = reverse ? interval.start : interval.end
        return DeviceActivitySchedule(
            intervalStart: DateComponents(hour: start / 60, minute: start % 60),
            intervalEnd: DateComponents(hour: end / 60, minute: end % 60),
            repeats: true
        )
    }
}
