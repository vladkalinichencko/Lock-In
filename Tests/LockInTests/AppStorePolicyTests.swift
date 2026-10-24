import XCTest
@testable import LockIn

@MainActor
final class AppStorePolicyTests: XCTestCase {
    func testResidualResetsAfterBreakAndSurvivesRelaunch() throws {
        let persistence = PersistenceStore(fileURL: FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString).appending(path: "state.json"))
        let store = AppStore(persistence: persistence)
        store.updateSessionCountLimit(3)
        let start = store.dayWindow.currentStart(for: Date()).addingTimeInterval(3600)
        store.recordUsage(ruleID: store.rules[0].id, seconds: 26 * 60, now: start)
        let restored = AppStore(persistence: persistence)
        restored.resetResidualIfNeeded(now: start.addingTimeInterval(3599))
        XCTAssertEqual(restored.sessionSecondsUsed, 26 * 60)
        restored.resetResidualIfNeeded(now: start.addingTimeInterval(3600))
        XCTAssertEqual(restored.sessionSecondsUsed, 0)
        XCTAssertEqual(restored.completedSessionCount, 1)
        XCTAssertEqual(restored.totalSecondsUsed, 26 * 60)
        XCTAssertNil(restored.cooldownUntil)
        XCTAssertNil(restored.lastUsedAt)
        let saved = try persistence.load()
        XCTAssertEqual(saved.completedSessionCount, 1)
        XCTAssertEqual(saved.cumulativeSecondsUsed, 26 * 60)
    }

    func testResidualOfLastSessionBlocksUntilDailyReset() {
        let store = AppStore(persistence: PersistenceStore(fileURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)))
        let start = store.dayWindow.currentStart(for: Date()).addingTimeInterval(3600)
        store.recordUsage(ruleID: store.rules[0].id, seconds: 25 * 60, now: start)
        store.resetResidualIfNeeded(now: start.addingTimeInterval(3600))
        XCTAssertEqual(store.completedSessionCount, 1)
        XCTAssertTrue(store.isBlocking(now: start.addingTimeInterval(3600)))
        XCTAssertEqual(store.cooldownUntil, store.dayWindow.nextStart(after: start))
        store.resetResidualIfNeeded(now: start.addingTimeInterval(7200))
        XCTAssertEqual(store.completedSessionCount, 1)
    }

    func testEarlyExitRetainsAllowanceAndReturningRestartsInactivity() {
        let store = AppStore(persistence: PersistenceStore(fileURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)))
        store.updateSessionCountLimit(3)
        let start = store.dayWindow.currentStart(for: Date()).addingTimeInterval(3600)
        store.recordUsage(ruleID: store.rules[0].id, seconds: 24 * 60, now: start)
        store.resetResidualIfNeeded(now: start.addingTimeInterval(3600))
        XCTAssertEqual(store.completedSessionCount, 0)
        store.recordUsage(ruleID: store.rules[0].id, seconds: 60, now: start.addingTimeInterval(3600))
        store.recordUsage(ruleID: store.rules[0].id, seconds: 1, now: start.addingTimeInterval(5400))
        store.resetResidualIfNeeded(now: start.addingTimeInterval(7200))
        XCTAssertEqual(store.sessionSecondsUsed, 25 * 60 + 1)
        store.resetResidualIfNeeded(now: start.addingTimeInterval(9000))
        XCTAssertEqual(store.completedSessionCount, 1)
        XCTAssertEqual(store.sessionSecondsUsed, 0)
    }

    func testDailyResetKeepsDowntimeAndPausedFocus() {
        let store = AppStore(persistence: PersistenceStore(fileURL: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)))
        store.timeRestrictions = TimeRestrictions(warningMinutes: 3, downtime: ClockInterval(start: 0, end: 0))
        let start = Date()
        store.startFocus(minutes: 25, now: start)
        store.toggleFocusPause(now: start.addingTimeInterval(60))
        store.resetIfNeeded(now: start.addingTimeInterval(86400))
        XCTAssertTrue(store.isBlocking(now: start.addingTimeInterval(86400)))
        XCTAssertNotNil(store.focusPausedAt)
        XCTAssertEqual(store.timeRestrictions.warningMinutes, 3)
        XCTAssertFalse(store.canEditPolicy)
    }

    func testPausedFocusSurvivesReloadAndResumesWithSameRemainingTime() throws {
        let persistence = PersistenceStore(fileURL: FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString).appending(path: "state.json"))
        let store = AppStore(persistence: persistence)
        let start = Date()
        store.startFocus(minutes: 1, now: start)
        XCTAssertEqual(store.statusSymbolName, "timer")
        store.toggleFocusPause(now: start.addingTimeInterval(20))
        let restored = AppStore(persistence: persistence)
        XCTAssertEqual(restored.focusPausedAt, start.addingTimeInterval(20))
        XCTAssertEqual(restored.statusSymbolName, "pause.circle")
        restored.expireFocusIfNeeded(now: start.addingTimeInterval(120))
        XCTAssertTrue(restored.isBlocking(now: start.addingTimeInterval(120)))
        XCTAssertFalse(restored.canEditPolicy)

        restored.toggleFocusPause(now: start.addingTimeInterval(120))
        XCTAssertNil(restored.focusPausedAt)
        XCTAssertEqual(try XCTUnwrap(restored.focusUntil).timeIntervalSince(start), 160, accuracy: 0.001)
        XCTAssertEqual(restored.statusSymbolName, "timer")
        restored.expireFocusIfNeeded(now: start.addingTimeInterval(160))
        XCTAssertFalse(restored.isFocusing(now: start.addingTimeInterval(160)))
        XCTAssertEqual(restored.statusSymbolName, "hand.raised.fill")
        restored.toggleFocusPause(now: start.addingTimeInterval(180))
        XCTAssertNil(restored.focusPausedAt)
    }

    func testPolicyValuesAreClamped() {
        let store = AppStore(
            persistence: PersistenceStore(
                fileURL: FileManager.default.temporaryDirectory
                    .appending(path: UUID().uuidString)
                    .appending(path: "state.json")
            )
        )

        store.updateSessionLimitMinutes(0)
        store.updateSessionCountLimit(0)
        store.updateCooldownMinutes(0)
        store.updateResetHour(-1)
        store.updateResetMinute(-1)
        XCTAssertEqual(store.sessionLimitMinutes, 1)
        XCTAssertEqual(store.sessionCountLimit, 1)
        XCTAssertEqual(store.cooldownMinutes, 1)
        XCTAssertEqual(store.resetHour, 0)
        XCTAssertEqual(store.resetMinute, 0)

        store.updateSessionLimitMinutes(481)
        store.updateSessionCountLimit(25)
        store.updateCooldownMinutes(1441)
        store.updateResetHour(24)
        store.updateResetMinute(60)
        XCTAssertEqual(store.sessionLimitMinutes, 480)
        XCTAssertEqual(store.sessionCountLimit, 24)
        XCTAssertEqual(store.cooldownMinutes, 1440)
        XCTAssertEqual(store.resetHour, 23)
        XCTAssertEqual(store.resetMinute, 59)
    }

    func testPolicyEditsLockAfterAnyUsageToday() {
        let store = AppStore(
            persistence: PersistenceStore(
                fileURL: FileManager.default.temporaryDirectory
                    .appending(path: UUID().uuidString)
                    .appending(path: "state.json")
            )
        )
        let rule = store.rules[0]

        XCTAssertTrue(store.canEditPolicy)
        store.recordUsage(ruleID: rule.id, seconds: 1)

        XCTAssertFalse(store.canEditPolicy)
        store.updateSessionLimitMinutes(120)
        store.updateSessionCountLimit(8)
        store.updateCooldownMinutes(120)
        store.updateResetHour(9)
        XCTAssertEqual(store.sessionLimitMinutes, 30)
        XCTAssertEqual(store.sessionCountLimit, 1)
        XCTAssertEqual(store.cooldownMinutes, 60)
        XCTAssertEqual(store.resetHour, 6)
        XCTAssertFalse(store.canRemove(rule: rule))
    }
}
