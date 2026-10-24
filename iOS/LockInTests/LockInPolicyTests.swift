import XCTest
@testable import LockIn

final class LockInPolicyTests: XCTestCase {
    func testSharedStoreSerializesUpdatesAndPersistsRestrictions() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
        let storage = LockInSharedStore(fileURL: url)
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("lock"))
        }
        _ = try storage.update {
            $0.timeRestrictions = TimeRestrictions(warningMinutes: 3, downtime: ClockInterval())
        }
        DispatchQueue.concurrentPerform(iterations: 20) { _ in
            _ = try! LockInSharedStore(fileURL: url).update { $0.cumulativeSecondsUsed += 1 }
        }
        let restored = try storage.load()
        XCTAssertEqual(restored.cumulativeSecondsUsed, 20)
        XCTAssertEqual(restored.restrictions.warningMinutes, 3)
        XCTAssertEqual(restored.restrictions.downtime, ClockInterval())
    }

    func testCorruptSharedStateFailsWithoutReplacingIt() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
        let data = Data("corrupt".utf8)
        try data.write(to: url)
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("lock"))
        }
        XCTAssertThrowsError(try LockInSharedStore(fileURL: url).update { $0.cumulativeSecondsUsed = 0 })
        XCTAssertEqual(try Data(contentsOf: url), data)
    }

    func testMonitoringRestartDoesNotResetDailyUsage() {
        let now = daytime()
        var snapshot = LockInSnapshot(completedSessionCount: 1, cumulativeSecondsUsed: 1800)
        snapshot.reconcile(at: now)
        let sessionID = snapshot.sessionID
        snapshot.reconcile(at: now.addingTimeInterval(60))
        XCTAssertEqual(snapshot.completedSessionCount, 1)
        XCTAssertEqual(snapshot.cumulativeSecondsUsed, 1800)
        XCTAssertEqual(snapshot.sessionID, sessionID)
    }

    func testResidualResetsAfterInactivityWithoutSpendingUnusedMinutes() throws {
        let now = daytime()
        var snapshot = LockInSnapshot(sessionCountLimit: 3)
        snapshot.reconcile(at: now)
        snapshot.recordThreshold(minutes: 26, at: now)
        let sessionID = snapshot.sessionID
        let data = try JSONEncoder().encode(snapshot)
        snapshot = try JSONDecoder().decode(LockInSnapshot.self, from: data)
        snapshot.reconcile(at: now.addingTimeInterval(3659))
        XCTAssertEqual(snapshot.currentSessionSecondsUsed, 26 * 60)
        snapshot.reconcile(at: now.addingTimeInterval(3660))
        XCTAssertEqual(snapshot.completedSessionCount, 1)
        XCTAssertEqual(snapshot.cumulativeSecondsUsed, 26 * 60)
        XCTAssertEqual(snapshot.currentSessionSecondsUsed, 0)
        XCTAssertNil(snapshot.cooldownUntil)
        XCTAssertNotEqual(snapshot.sessionID, sessionID)
        snapshot.reconcile(at: now.addingTimeInterval(7200))
        XCTAssertEqual(snapshot.completedSessionCount, 1)
    }

    func testReturningWithinBreakKeepsResidualAllowance() {
        let now = daytime()
        var snapshot = LockInSnapshot(sessionCountLimit: 3)
        snapshot.reconcile(at: now)
        snapshot.recordThreshold(minutes: 25, at: now)
        snapshot.recordThreshold(minutes: 26, at: now.addingTimeInterval(1800))
        snapshot.reconcile(at: now.addingTimeInterval(3660))
        XCTAssertEqual(snapshot.currentSessionSecondsUsed, 26 * 60)
        XCTAssertEqual(snapshot.completedSessionCount, 0)
        snapshot.reconcile(at: now.addingTimeInterval(5460))
        XCTAssertEqual(snapshot.completedSessionCount, 1)
    }

    func testLastResidualSessionRemainsBlockedUntilReset() {
        let now = daytime()
        var snapshot = LockInSnapshot()
        snapshot.reconcile(at: now)
        snapshot.recordThreshold(minutes: 25, at: now)
        snapshot.reconcile(at: now.addingTimeInterval(3660))
        XCTAssertTrue(snapshot.isBlocking(at: now.addingTimeInterval(3660)))
        XCTAssertEqual(snapshot.completedSessionCount, 1)
        snapshot.reconcile(at: now.addingTimeInterval(86400))
        XCTAssertEqual(snapshot.completedSessionCount, 0)
        XCTAssertFalse(snapshot.isBlocking(at: now.addingTimeInterval(86400)))
    }

    func testDuplicateAndOutOfOrderThresholdsCannotCountSessionTwice() {
        let now = daytime()
        var snapshot = LockInSnapshot(sessionCountLimit: 3)
        snapshot.reconcile(at: now)
        snapshot.recordThreshold(minutes: 26, at: now)
        snapshot.recordThreshold(minutes: 25, at: now.addingTimeInterval(60))
        XCTAssertEqual(snapshot.lastUsedAt, now)
        snapshot.recordThreshold(minutes: 30, at: now.addingTimeInterval(240))
        snapshot.recordThreshold(minutes: 30, at: now.addingTimeInterval(241))
        XCTAssertEqual(snapshot.cumulativeSecondsUsed, 1800)
        XCTAssertEqual(snapshot.completedSessionCount, 1)
        XCTAssertTrue(snapshot.isBlocking(at: now.addingTimeInterval(300)))
    }

    func testCooldownExpiryAndDayResetKeepDowntimeAndPausedFocus() {
        let now = daytime()
        var snapshot = LockInSnapshot(sessionCountLimit: 3, focusUntil: now.addingTimeInterval(1500), focusPausedAt: now)
        snapshot.timeRestrictions = TimeRestrictions(warningMinutes: 2, downtime: ClockInterval(start: 0, end: 0))
        snapshot.reconcile(at: now)
        snapshot.recordThreshold(minutes: 30, at: now)
        snapshot.reconcile(at: now.addingTimeInterval(3600))
        XCTAssertNil(snapshot.cooldownUntil)
        XCTAssertTrue(snapshot.isBlocking(at: now.addingTimeInterval(3600)))
        snapshot.reconcile(at: now.addingTimeInterval(86400))
        XCTAssertEqual(snapshot.completedSessionCount, 0)
        XCTAssertNotNil(snapshot.focusPausedAt)
        XCTAssertTrue(snapshot.isBlocking(at: now.addingTimeInterval(86400)))
        XCTAssertEqual(snapshot.restrictions.warningMinutes, 2)
    }

    func testOldSnapshotDecodesNewRestrictionDefaults() throws {
        let data = try JSONEncoder().encode(LockInSnapshot())
        let snapshot = try JSONDecoder().decode(LockInSnapshot.self, from: data)
        XCTAssertEqual(snapshot.restrictions.warningMinutes, 5)
        XCTAssertNil(snapshot.restrictions.downtime)
        XCTAssertNil(snapshot.lastUsedAt)
        XCTAssertNil(snapshot.windowStart)
    }

    private func daytime() -> Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    }

    func testPausePreservesBlockingAndRemainingTimeAfterReload() throws {
        let start = Date(timeIntervalSince1970: 1000)
        var snapshot = LockInSnapshot(focusMinutes: 15, focusUntil: start.addingTimeInterval(900))
        snapshot.toggleFocusPause(at: start.addingTimeInterval(810))
        snapshot = try JSONDecoder().decode(LockInSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(snapshot.focusPausedAt, start.addingTimeInterval(810))
        XCTAssertTrue(snapshot.isBlocking(at: start.addingTimeInterval(3600)))
        snapshot.toggleFocusPause(at: start.addingTimeInterval(3600))
        XCTAssertNil(snapshot.focusPausedAt)
        XCTAssertEqual(snapshot.focusUntil, start.addingTimeInterval(3690))
        XCTAssertTrue(snapshot.isBlocking(at: start.addingTimeInterval(3689)))
        XCTAssertFalse(snapshot.isBlocking(at: start.addingTimeInterval(3690)))
    }

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
        XCTAssertNil(restored.focusPausedAt)
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

