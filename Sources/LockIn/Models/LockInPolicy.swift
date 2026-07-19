import Foundation

enum LockInPolicy {
    static func clamp(_ value: Int, min minimum: Int, max maximum: Int) -> Int {
        Swift.min(Swift.max(value, minimum), maximum)
    }

    static func totalSecondsAllowed(sessionMinutes: Int, sessionCount: Int) -> Int {
        sessionMinutes * sessionCount * 60
    }

    static func canEdit(cumulativeSecondsUsed: Int, completedSessionCount: Int, cooldownUntil: Date?) -> Bool {
        cumulativeSecondsUsed == 0 && completedSessionCount == 0 && cooldownUntil == nil
    }

    static func dayWindowStart(
        for date: Date,
        resetHour: Int,
        resetMinute: Int,
        calendar: Calendar = .current
    ) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = resetHour
        components.minute = resetMinute
        components.second = 0
        let start = calendar.date(from: components) ?? date
        return date >= start ? start : calendar.date(byAdding: .day, value: -1, to: start) ?? start
    }

    static func nextReset(
        after date: Date,
        resetHour: Int,
        resetMinute: Int,
        calendar: Calendar = .current
    ) -> Date {
        let start = dayWindowStart(
            for: date,
            resetHour: resetHour,
            resetMinute: resetMinute,
            calendar: calendar
        )
        return calendar.date(byAdding: .day, value: 1, to: start) ?? date
    }
}
