import XCTest
@testable import LockIn

final class DayWindowTests: XCTestCase {
    func testCurrentStartUsesPreviousDayBeforeConfiguredStart() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let window = DayWindow(startHour: 6, startMinute: 0, calendar: calendar)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 3)))
        let start = window.currentStart(for: date)
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: start)
        XCTAssertEqual(components.day, 8)
        XCTAssertEqual(components.hour, 6)
    }

    func testCurrentStartUsesSameDayAfterConfiguredStart() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let window = DayWindow(startHour: 6, startMinute: 0, calendar: calendar)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 9, hour: 7)))
        let start = window.currentStart(for: date)
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: start)
        XCTAssertEqual(components.day, 9)
        XCTAssertEqual(components.hour, 6)
    }
}
