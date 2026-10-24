import XCTest
@testable import LockIn

final class DayWindowTests: XCTestCase {
    func testDowntimeBoundariesAndOvernightRange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let interval = ClockInterval(start: 22 * 60, end: 8 * 60)
        for (hour, minute, expected) in [(21, 59, false), (22, 0, true), (0, 0, true), (7, 59, true), (8, 0, false)] {
            let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: hour, minute: minute))!
            XCTAssertEqual(interval.contains(date, calendar: calendar), expected)
        }
    }

    func testSameDayAndAllDayDowntime() {
        let date = Date()
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        XCTAssertTrue(ClockInterval(start: 9 * 60, end: 17 * 60).contains(noon))
        XCTAssertFalse(ClockInterval(start: 13 * 60, end: 17 * 60).contains(noon))
        XCTAssertTrue(ClockInterval(start: 0, end: 0).contains(noon))
    }

    func testDowntimeEndAcrossDaylightSavingChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 22)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 8)))
        XCTAssertEqual(calendar.component(.hour, from: end), 8)
        XCTAssertEqual(end.timeIntervalSince(start), 9 * 3600)
        XCTAssertTrue(ClockInterval().contains(start, calendar: calendar))
        XCTAssertTrue(ClockInterval().contains(end.addingTimeInterval(-1), calendar: calendar))
        XCTAssertFalse(ClockInterval().contains(end, calendar: calendar))
    }

    func testWarningWindowAndDisabledResidualReset() {
        let date = Date()
        XCTAssertEqual(TimeRestrictions().warningMinutes(for: 3), 2)
        XCTAssertNil(TimeRestrictions(warningMinutes: 0).residualReset(lastUsedAt: date, secondsUsed: 1799, sessionMinutes: 30, breakMinutes: 60))
        XCTAssertNil(TimeRestrictions().residualReset(lastUsedAt: date, secondsUsed: 1800, sessionMinutes: 30, breakMinutes: 60))
        XCTAssertNil(TimeRestrictions().residualReset(lastUsedAt: nil, secondsUsed: 1500, sessionMinutes: 30, breakMinutes: 60))
    }

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
