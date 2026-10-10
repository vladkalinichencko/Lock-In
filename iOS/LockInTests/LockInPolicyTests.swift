import XCTest
@testable import LockIn

final class LockInPolicyTests: XCTestCase {
    func testFocusBlocksUntilItsDeadlineAndPreservesCooldown() throws {
        let start = Date(timeIntervalSince1970: 1000)
        let end = start.addingTimeInterval(1500)
        var snapshot = LockInSnapshot(focusMinutes: 25, focusUntil: end)
        XCTAssertTrue(snapshot.isFocusing(at: start))
        XCTAssertTrue(snapshot.isBlocking(at: start))
        XCTAssertFalse(snapshot.isBlocking(at: end))

        snapshot.cooldownUntil = end.addingTimeInterval(600)
        XCTAssertFalse(snapshot.isFocusing(at: end))
        XCTAssertTrue(snapshot.isBlocking(at: end))

        let restored = try JSONDecoder().decode(LockInSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(restored.focusUntil, end)
        XCTAssertEqual(restored.focusMinutes, 25)
    }

    func testLegacySnapshotLoadsWithoutFocusSettings() throws {
        let snapshot = LockInSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        let restored = try JSONDecoder().decode(LockInSnapshot.self, from: data)
        XCTAssertNil(restored.focusUntil)
        XCTAssertNil(restored.focusMinutes)
        XCTAssertFalse(restored.isFocusing())
    }

    func testPolicyValuesAreClamped() {
        let snapshot = LockInSnapshot(
            sessionLimitMinutes: 0,
            sessionCountLimit: 0,
            breakMinutes: 0,
            resetHour: -1,
            resetMinute: -1,
            completedSessionCount: -1,
            cumulativeSecondsUsed: -1,
            currentSessionSecondsUsed: -1
        )

        XCTAssertEqual(snapshot.sessionLimitMinutes, 1)
        XCTAssertEqual(snapshot.sessionCountLimit, 1)
        XCTAssertEqual(snapshot.breakMinutes, 1)
        XCTAssertEqual(snapshot.resetHour, 0)
        XCTAssertEqual(snapshot.resetMinute, 0)
        XCTAssertEqual(snapshot.completedSessionCount, 0)
        XCTAssertEqual(snapshot.cumulativeSecondsUsed, 0)
        XCTAssertEqual(snapshot.currentSessionSecondsUsed, 0)
    }

    func testPolicyUpperBoundsAreClamped() {
        let snapshot = LockInSnapshot(
            sessionLimitMinutes: 481,
            sessionCountLimit: 25,
            breakMinutes: 1441,
            resetHour: 24,
            resetMinute: 60
        )

        XCTAssertEqual(snapshot.sessionLimitMinutes, 480)
        XCTAssertEqual(snapshot.sessionCountLimit, 24)
        XCTAssertEqual(snapshot.breakMinutes, 1440)
        XCTAssertEqual(snapshot.resetHour, 23)
        XCTAssertEqual(snapshot.resetMinute, 59)
    }

    func testTotalAllowedUsesSessionTimesSessions() {
        let snapshot = LockInSnapshot(sessionLimitMinutes: 20, sessionCountLimit: 3)

        XCTAssertEqual(snapshot.totalSecondsAllowed, 60 * 60)
    }

    func testEditLockAfterUsage() {
        XCTAssertTrue(LockInSnapshot().canEditPolicy)
        XCTAssertFalse(LockInSnapshot(cumulativeSecondsUsed: 1).canEditPolicy)
        XCTAssertFalse(LockInSnapshot(completedSessionCount: 1).canEditPolicy)
        XCTAssertFalse(LockInSnapshot(cooldownUntil: Date()).canEditPolicy)
    }
}

