import XCTest
@testable import LockIn

final class LockInScheduleTests: XCTestCase {
    func testResumedFocusScheduleUsesCurrentIntervalForShortRemainder() throws {
        let end = Date().addingTimeInterval(90.5)
        let schedule = LockInSchedule.focusSchedule(from: end.addingTimeInterval(-900), until: end)
        let interval = try XCTUnwrap(schedule.nextInterval)
        XCTAssertLessThanOrEqual(interval.start, Date())
        XCTAssertGreaterThanOrEqual(interval.duration, 900)
        XCTAssertGreaterThanOrEqual(interval.end, end)
        XCTAssertLessThan(interval.end.timeIntervalSince(end), 1)
    }

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

    func testEventsTrackMinutesAndKeepTheConfiguredWarningWindow() {
        var snapshot = LockInSnapshot(sessionLimitMinutes: 30)
        snapshot.timeRestrictions = TimeRestrictions(warningMinutes: 3)
        snapshot.sessionID = UUID()
        let events = LockInSchedule.events(for: snapshot)
        XCTAssertEqual(events.count, 30)
        let warning = LockInSchedule.eventName(minutes: 27, snapshot: snapshot)
        XCTAssertEqual(events[warning]?.threshold.minute, 27)
        XCTAssertEqual(LockInSchedule.thresholdMinutes(warning, snapshot: snapshot), 27)
        snapshot.sessionID = UUID()
        XCTAssertNil(LockInSchedule.thresholdMinutes(warning, snapshot: snapshot))
    }

    func testRestartedMonitoringCountsOnlyRemainingUsage() {
        let snapshot = LockInSnapshot(currentSessionSecondsUsed: 12 * 60)
        let events = LockInSchedule.events(for: snapshot)
        XCTAssertEqual(events.count, 18)
        XCTAssertEqual(events[LockInSchedule.eventName(minutes: 13, snapshot: snapshot)]?.threshold.minute, 1)
        XCTAssertEqual(events[LockInSchedule.eventName(minutes: 30, snapshot: snapshot)]?.threshold.minute, 18)
        XCTAssertTrue(events.values.allSatisfy { !$0.includesPastActivity })
    }

    func testDowntimeScheduleKeepsOvernightBoundaries() {
        let schedule = LockInSchedule.downtimeSchedule(for: ClockInterval())
        XCTAssertEqual(schedule.intervalStart.hour, 22)
        XCTAssertEqual(schedule.intervalEnd.hour, 8)
        XCTAssertTrue(schedule.repeats)
    }

    func testShortDowntimeMonitorsAvailabilityToKeepLegalInterval() {
        let schedule = LockInSchedule.downtimeSchedule(for: ClockInterval(start: 600, end: 605))
        XCTAssertEqual(schedule.intervalStart.hour, 10)
        XCTAssertEqual(schedule.intervalStart.minute, 5)
        XCTAssertEqual(schedule.intervalEnd.hour, 10)
        XCTAssertEqual(schedule.intervalEnd.minute, 0)
    }
}

