import Foundation

struct DayWindow: Equatable {
    var startHour: Int
    var startMinute: Int
    var calendar: Calendar = .current

    func currentStart(for date: Date = Date()) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = startHour
        components.minute = startMinute
        components.second = 0

        let todayStart = calendar.date(from: components) ?? date
        if date >= todayStart {
            return todayStart
        }

        return calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
    }

    func nextStart(after date: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: 1, to: currentStart(for: date)) ?? date
    }
}
