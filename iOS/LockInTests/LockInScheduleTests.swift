import XCTest
@testable import LockIn

final class LockInScheduleTests: XCTestCase {
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

