import Foundation

struct TimeRestrictions: Codable, Equatable {
    var warningMinutes = 5
    var downtime: ClockInterval?

    func warningMinutes(for sessionMinutes: Int) -> Int {
        min(warningMinutes, max(0, sessionMinutes - 1))
    }

    func residualReset(lastUsedAt: Date?, secondsUsed: Int, sessionMinutes: Int, breakMinutes: Int) -> Date? {
        let remaining = sessionMinutes * 60 - secondsUsed
        guard let lastUsedAt, secondsUsed > 0, remaining > 0,
              remaining <= warningMinutes(for: sessionMinutes) * 60 else { return nil }
        return lastUsedAt.addingTimeInterval(TimeInterval(breakMinutes * 60))
    }
}

struct ClockInterval: Codable, Equatable {
    var start = 22 * 60
    var end = 8 * 60

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        return start < end ? (start..<end).contains(minute) : minute >= start || minute < end
    }
}

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
