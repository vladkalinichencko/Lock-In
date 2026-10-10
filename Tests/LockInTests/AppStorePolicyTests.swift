import XCTest
@testable import LockIn

@MainActor
final class AppStorePolicyTests: XCTestCase {
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
