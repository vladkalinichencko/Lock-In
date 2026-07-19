import Foundation

struct DayWindow: Equatable {
    var startHour: Int
    var startMinute: Int
    var calendar: Calendar = .current

    func currentStart(for date: Date = Date()) -> Date {
        LockInPolicy.dayWindowStart(
            for: date,
            resetHour: startHour,
            resetMinute: startMinute,
            calendar: calendar
        )
    }

    func nextStart(after date: Date = Date()) -> Date {
        LockInPolicy.nextReset(
            after: date,
            resetHour: startHour,
            resetMinute: startMinute,
            calendar: calendar
        )
    }
}
