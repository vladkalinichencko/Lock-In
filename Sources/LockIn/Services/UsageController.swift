import Foundation

@MainActor
final class UsageController {
    private let store: AppStore
    private let browserMonitor: BrowserActivityMonitoring
    private let applicationMonitor: ApplicationActivityMonitoring
    private let notifications: UserNotifying
    private let suppliedBlockPageURL: URL?
    private var timer: Timer?

    init(
        store: AppStore,
        browserMonitor: BrowserActivityMonitoring = BrowserActivityMonitor(),
        applicationMonitor: ApplicationActivityMonitoring = ApplicationActivityMonitor(),
        notifications: UserNotifying = NotificationService(),
        blockPageURL: URL? = nil
    ) {
        self.store = store
        self.browserMonitor = browserMonitor
        self.applicationMonitor = applicationMonitor
        self.notifications = notifications
        self.suppliedBlockPageURL = blockPageURL
    }

    func start() {
        notifications.requestAuthorization()
        store.resetIfNeeded()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func tick() async {
        store.now = Date()
        store.reloadUsageFromDisk()
        store.resetIfNeeded(now: store.now)
        store.expireCooldownIfNeeded(now: store.now)
        recordCurrentUseIfNeeded()
        await reconcileLimits()
        blockCurrentBrowserTabIfNeeded()
        blockCurrentApplicationIfNeeded()
    }

    private func recordCurrentUseIfNeeded() {
        let browserActivity = browserMonitor.currentActivity()
        let applicationActivity = applicationMonitor.currentActivity()
        let websiteRule = browserActivity.flatMap { activity in
            store.rules.first(where: { DomainMatcher.url(activity.url, matchesDomain: $0.domain) })
        }
        let applicationRule = applicationActivity.flatMap { activity in
            store.applicationRules.first(where: { $0.bundleIdentifier == activity.bundleIdentifier })
        }

        store.currentActivity = browserActivity
        store.currentApplicationActivity = applicationActivity

        let activeRuleIDs = Set([websiteRule?.id, applicationRule?.id].compactMap { $0 })
        guard let ruleID = websiteRule?.id ?? applicationRule?.id else {
            store.currentRuleID = nil
            store.currentRuleSeenAt = nil
            store.setActiveRuleIDs([])
            return
        }

        store.setActiveRuleIDs(activeRuleIDs)

        guard !store.isCoolingDown(now: store.now),
              store.sessionSecondsUsed < store.sessionLimitMinutes * 60 else {
            return
        }

        store.recordUsage(ruleID: ruleID, seconds: 1, now: store.now)
    }

    private func reconcileLimits() async {
        let limitSeconds = store.sessionLimitMinutes * 60
        let sessionSeconds = store.sessionSecondsUsed
        let warningSeconds = max(0, limitSeconds - 5 * 60)
        let warningAlreadySent = store.records.values.contains(where: \.warningSent)

        if sessionSeconds >= warningSeconds && !warningAlreadySent && limitSeconds > 5 * 60 {
            notifications.sendWarning(domain: "Selected websites and apps", minutesRemaining: 5)
            for ruleID in store.allRuleIDs {
                if var record = store.records[ruleID] {
                    record.warningSent = true
                    store.records[ruleID] = record
                }
            }
        }

        if sessionSeconds >= limitSeconds && !store.isCoolingDown(now: store.now) {
            store.startCooldown(now: store.now)
        }

        store.blockerState = store.isCoolingDown(now: store.now) ? .active(store.allRuleIDs.count) : .idle
        store.save()
    }

    private func blockCurrentBrowserTabIfNeeded() {
        guard store.isCoolingDown(now: store.now),
              let activity = store.currentActivity,
              store.rules.contains(where: { DomainMatcher.url(activity.url, matchesDomain: $0.domain) }),
              let blockPageURL else {
            return
        }

        browserMonitor.redirectActiveTab(in: activity, to: blockPageURL)
    }

    private func blockCurrentApplicationIfNeeded() {
        guard store.isCoolingDown(now: store.now),
              let activity = store.currentApplicationActivity,
              store.applicationRules.contains(where: { $0.bundleIdentifier == activity.bundleIdentifier }) else {
            return
        }

        applicationMonitor.block(activity)
    }

    private var blockPageURL: URL? {
        if let suppliedBlockPageURL {
            return suppliedBlockPageURL
        }

        let pageName = store.completedSessionCount >= store.sessionCountLimit
            ? "blocked-until-next-day.html"
            : "blocked-until-break-ends.html"

        if let resourceURL = Bundle.main.resourceURL?.appending(path: pageName),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            return resourceURL
        }

        store.lastError = "Missing bundled block page."
        return nil
    }
}
