import XCTest
@testable import LockIn

final class LockInScheduleTests: XCTestCase {
    func testFocusScheduleKeepsExactDatesAcrossMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 23, minute: 50)))
        let end = start.addingTimeInterval(25 * 60)
        let schedule = LockInSchedule.focusSchedule(from: start, until: end, calendar: calendar)
        XCTAssertEqual(calendar.date(from: schedule.intervalStart), start)
        XCTAssertEqual(calendar.date(from: schedule.intervalEnd), end)
        XCTAssertFalse(schedule.repeats)
    }

    func testDayWindowUsesPreviousDayBeforeResetTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let snapshot = LockInSnapshot(resetHour: 6, resetMinute: 0)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 19, hour: 5)))

        let start = LockInSchedule.dayWindowStart(for: date, snapshot: snapshot, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: start)

        XCTAssertEqual(components.day, 18)
        XCTAssertEqual(components.hour, 6)
    }

    func testDayWindowUsesSameDayAfterResetTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let snapshot = LockInSnapshot(resetHour: 6, resetMinute: 0)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 19, hour: 7)))

        let start = LockInSchedule.dayWindowStart(for: date, snapshot: snapshot, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: start)

        XCTAssertEqual(components.day, 19)
        XCTAssertEqual(components.hour, 6)
    }

    func testEventsIncludeWarningOnlyForSessionsLongerThanFiveMinutes() {
        XCTAssertNil(LockInSchedule.events(for: LockInSnapshot(sessionLimitMinutes: 5))[LockInConstants.warningEventName])
        XCTAssertNotNil(LockInSchedule.events(for: LockInSnapshot(sessionLimitMinutes: 6))[LockInConstants.warningEventName])
    }
}

