import XCTest

@testable import LockIn

final class PersistenceStoreTests: XCTestCase {
    func testSavesAndLoadsSettingsRulesAndUsage() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "state.json")
        let store = PersistenceStore(fileURL: fileURL)
        let rule = BlockRule(domain: "x.com")
        let applicationRule = ApplicationRule(name: "TV", bundleIdentifier: "com.apple.TV")
        let snapshot = AppSnapshot(
            rules: [rule],
            applicationRules: [applicationRule],
            records: [
                UsageRecord(
                    ruleID: rule.id,
                    windowStart: Date(timeIntervalSince1970: 100),
                    secondsUsed: 123,
                    warningSent: true,
                    isBlocked: false
                )
            ],
            sessionLimitMinutes: 45,
            sessionCountLimit: 4,
            cooldownMinutes: 90,
            resetHour: 7,
            resetMinute: 30,
            cooldownUntil: Date(timeIntervalSince1970: 500),
            completedSessionCount: 2,
            cumulativeSecondsUsed: 2700
        )

        try store.save(snapshot)
        let loaded = try store.load()

        XCTAssertEqual(loaded.rules, snapshot.rules)
        XCTAssertEqual(loaded.applicationRules, [applicationRule])
        XCTAssertEqual(loaded.records, snapshot.records)
        XCTAssertEqual(loaded.sessionLimitMinutes, 45)
        XCTAssertEqual(loaded.sessionCountLimit, 4)
        XCTAssertEqual(loaded.cooldownMinutes, 90)
        XCTAssertEqual(loaded.resetHour, 7)
        XCTAssertEqual(loaded.resetMinute, 30)
        XCTAssertEqual(loaded.cooldownUntil, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(loaded.completedSessionCount, 2)
        XCTAssertEqual(loaded.cumulativeSecondsUsed, 2700)
    }

    func testLoadsLegacyDailySettingsAsSessionSettings() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "state.json")
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        {
          "activeRuleIDs" : [],
          "dailyAllowanceMinutes" : 45,
          "dayStartHour" : 7,
          "dayStartMinute" : 30,
          "records" : [],
          "rules" : []
        }
        """.data(using: .utf8)!.write(to: fileURL)

        let loaded = try PersistenceStore(fileURL: fileURL).load()

        XCTAssertEqual(loaded.sessionLimitMinutes, 45)
        XCTAssertEqual(loaded.sessionCountLimit, 1)
        XCTAssertEqual(loaded.cooldownMinutes, 60)
        XCTAssertEqual(loaded.resetHour, 7)
        XCTAssertEqual(loaded.resetMinute, 30)
        XCTAssertEqual(loaded.cumulativeSecondsUsed, 0)
    }
}
