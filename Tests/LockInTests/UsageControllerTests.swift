import Foundation
import XCTest
@testable import LockIn

@MainActor
final class UsageControllerTests: XCTestCase {
    func testTickCountsMatchingActiveBrowserTabEverySecond() async {
        let store = AppStore(persistence: temporaryPersistence())
        let rule = store.rules[0]
        let browserMonitor = FakeBrowserActivityMonitor(
            activity: BrowserActivity(
                appName: "Arc",
                bundleIdentifier: "company.thebrowser.Browser",
                url: URL(string: "https://x.com/home")!
            )
        )
        let controller = UsageController(
            store: store,
            browserMonitor: browserMonitor,
            notifications: FakeNotificationService(),
            blockPageURL: URL(string: "file:///blocked.html")
        )

        await controller.tick()
        await controller.tick()
        await controller.tick()

        XCTAssertEqual(store.totalSecondsUsed, 3)
        XCTAssertEqual(store.activeRuleIDs, Set([rule.id]))
        XCTAssertNil(browserMonitor.redirectedURL)
    }

    func testTickDoesNotCountNonMatchingActiveBrowserTab() async {
        let store = AppStore(persistence: temporaryPersistence())
        let browserMonitor = FakeBrowserActivityMonitor(
            activity: BrowserActivity(
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                url: URL(string: "https://apple.com")!
            )
        )
        let controller = UsageController(
            store: store,
            browserMonitor: browserMonitor,
            notifications: FakeNotificationService(),
            blockPageURL: URL(string: "file:///blocked.html")
        )

        await controller.tick()

        XCTAssertEqual(store.totalSecondsUsed, 0)
        XCTAssertTrue(store.activeRuleIDs.isEmpty)
    }

    func testTickRedirectsMatchingActiveTabWhenSessionLimitIsUsed() async {
        let store = AppStore(persistence: temporaryPersistence())
        store.updateSessionLimitMinutes(1)
        let rule = store.rules[0]
        store.recordUsage(ruleID: rule.id, seconds: 59)
        let browserMonitor = FakeBrowserActivityMonitor(
            activity: BrowserActivity(
                appName: "Google Chrome",
                bundleIdentifier: "com.google.Chrome",
                url: URL(string: "https://mobile.x.com/home")!
            )
        )
        let notifications = FakeNotificationService()
        let controller = UsageController(
            store: store,
            browserMonitor: browserMonitor,
            notifications: notifications,
            blockPageURL: URL(string: "file:///blocked.html")
        )

        await controller.tick()

        XCTAssertEqual(store.totalSecondsUsed, 60)
        XCTAssertEqual(store.sessionSecondsUsed, 60)
        XCTAssertEqual(store.activeRuleIDs, Set([rule.id]))
        XCTAssertNotNil(store.cooldownUntil)
        XCTAssertEqual(store.completedSessionCount, 1)
        XCTAssertNotNil(browserMonitor.redirectedURL)
    }

    func testTickSendsWarningAtFiveMinutesRemaining() async {
        let store = AppStore(persistence: temporaryPersistence())
        let rule = store.rules[0]
        store.recordUsage(ruleID: rule.id, seconds: 24 * 60 + 59)
        let browserMonitor = FakeBrowserActivityMonitor(
            activity: BrowserActivity(
                appName: "Arc",
                bundleIdentifier: "company.thebrowser.Browser",
                url: URL(string: "https://x.com/home")!
            )
        )
        let notifications = FakeNotificationService()
        let controller = UsageController(
            store: store,
            browserMonitor: browserMonitor,
            notifications: notifications,
            blockPageURL: URL(string: "file:///blocked.html")
        )

        await controller.tick()

        XCTAssertEqual(store.totalSecondsUsed, 25 * 60)
        XCTAssertEqual(store.sessionSecondsUsed, 25 * 60)
        XCTAssertEqual(notifications.warningDomains, ["Selected websites"])
        XCTAssertTrue(store.records.values.allSatisfy(\.warningSent))
    }

    func testTickDoesNotSendWarningTwice() async {
        let store = AppStore(persistence: temporaryPersistence())
        let rule = store.rules[0]
        store.recordUsage(ruleID: rule.id, seconds: 25 * 60)
        store.records[rule.id]?.warningSent = true
        store.save()
        let browserMonitor = FakeBrowserActivityMonitor(
            activity: BrowserActivity(
                appName: "Arc",
                bundleIdentifier: "company.thebrowser.Browser",
                url: URL(string: "https://x.com/home")!
            )
        )
        let notifications = FakeNotificationService()
        let controller = UsageController(
            store: store,
            browserMonitor: browserMonitor,
            notifications: notifications,
            blockPageURL: URL(string: "file:///blocked.html")
        )

        await controller.tick()

        XCTAssertTrue(notifications.warningDomains.isEmpty)
    }

    func testLeavingBeforeSessionLimitCanContinueWithoutBreak() async {
        let store = AppStore(persistence: temporaryPersistence())
        store.updateSessionLimitMinutes(1)
        let rule = store.rules[0]
        store.recordUsage(ruleID: rule.id, seconds: 20)
        let browserMonitor = FakeBrowserActivityMonitor(activity: nil)
        let controller = UsageController(
            store: store,
            browserMonitor: browserMonitor,
            notifications: FakeNotificationService(),
            blockPageURL: URL(string: "file:///blocked.html")
        )

        await controller.tick()
        browserMonitor.activity = BrowserActivity(
            appName: "Arc",
            bundleIdentifier: "company.thebrowser.Browser",
            url: URL(string: "https://x.com/home")!
        )
        await controller.tick()

        XCTAssertEqual(store.totalSecondsUsed, 21)
        XCTAssertEqual(store.sessionSecondsUsed, 21)
        XCTAssertNil(store.cooldownUntil)
        XCTAssertNil(browserMonitor.redirectedURL)
    }

    func testCooldownExpiryStartsFreshSession() async {
        let store = AppStore(persistence: temporaryPersistence())
        store.updateSessionLimitMinutes(1)
        store.updateCooldownMinutes(1)
        let rule = store.rules[0]
        store.recordUsage(ruleID: rule.id, seconds: 60)
        store.startCooldown(now: Date(timeIntervalSince1970: 100))
        let browserMonitor = FakeBrowserActivityMonitor(
            activity: BrowserActivity(
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                url: URL(string: "https://x.com/home")!
            )
        )
        let controller = UsageController(
            store: store,
            browserMonitor: browserMonitor,
            notifications: FakeNotificationService(),
            blockPageURL: URL(string: "file:///blocked.html")
        )

        store.now = Date(timeIntervalSince1970: 161)
        store.expireCooldownIfNeeded(now: store.now)
        await controller.tick()

        XCTAssertEqual(store.sessionSecondsUsed, 1)
        XCTAssertEqual(store.totalSecondsUsed, 61)
        XCTAssertNil(store.cooldownUntil)
    }

    func testLastSessionBlocksUntilNextResetTime() async {
        let store = AppStore(persistence: temporaryPersistence())
        store.updateSessionCountLimit(2)
        store.updateResetHour(6)
        store.updateResetMinute(0)
        store.completedSessionCount = 1
        let now = Date(timeIntervalSince1970: 200)

        store.startCooldown(now: now)

        XCTAssertEqual(store.completedSessionCount, 2)
        XCTAssertEqual(store.cooldownUntil, store.dayWindow.nextStart(after: now))
    }

    private func temporaryPersistence() -> PersistenceStore {
        PersistenceStore(
            fileURL: FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString)
                .appending(path: "state.json")
        )
    }
}

@MainActor
private final class FakeBrowserActivityMonitor: BrowserActivityMonitoring {
    var activity: BrowserActivity?
    var redirectedURL: URL?

    init(activity: BrowserActivity?) {
        self.activity = activity
    }

    func currentActivity() -> BrowserActivity? {
        activity
    }

    func redirectActiveTab(in activity: BrowserActivity, to url: URL) {
        redirectedURL = url
    }
}

private final class FakeNotificationService: UserNotifying {
    var warningDomains: [String] = []

    func requestAuthorization() {}

    func sendWarning(domain: String, minutesRemaining: Int) {
        warningDomains.append(domain)
    }

}
