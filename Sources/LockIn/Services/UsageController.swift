import Foundation

@MainActor
final class UsageController {
    private let store: AppStore
    private let browserMonitor: BrowserActivityMonitoring
    private let notifications: UserNotifying
    private let suppliedBlockPageURL: URL?
    private var timer: Timer?

    init(
        store: AppStore,
        browserMonitor: BrowserActivityMonitoring = BrowserActivityMonitor(),
        notifications: UserNotifying = NotificationService(),
        blockPageURL: URL? = nil
    ) {
        self.store = store
        self.browserMonitor = browserMonitor
        self.notifications = notifications
        self.suppliedBlockPageURL = blockPageURL
    }

    func start() {
        notifications.requestAuthorization()
        store.resetIfNeeded()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.tick()
            }
        }
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
        recordCurrentBrowserUseIfNeeded()
        await reconcileLimits()
        blockCurrentBrowserTabIfNeeded()
    }

    private func recordCurrentBrowserUseIfNeeded() {
        let activity = browserMonitor.currentActivity()
        store.currentActivity = activity

        guard let activity,
              let rule = store.rules.first(where: { DomainMatcher.url(activity.url, matchesDomain: $0.domain) }) else {
            store.currentRuleID = nil
            store.currentRuleSeenAt = nil
            store.setActiveRuleIDs([])
            return
        }

        store.setActiveRuleIDs([rule.id])

        guard !store.isCoolingDown(now: store.now),
              store.sessionSecondsUsed < store.sessionLimitMinutes * 60 else {
            return
        }

        store.recordUsage(ruleID: rule.id, seconds: 1, now: store.now)
    }

    private func reconcileLimits() async {
        let limitSeconds = store.sessionLimitMinutes * 60
        let sessionSeconds = store.sessionSecondsUsed
        let warningSeconds = max(0, limitSeconds - 5 * 60)
        let warningAlreadySent = store.records.values.contains(where: \.warningSent)

        if sessionSeconds >= warningSeconds && !warningAlreadySent && limitSeconds > 5 * 60 {
            notifications.sendWarning(domain: "Selected websites", minutesRemaining: 5)
            for rule in store.rules {
                if var record = store.records[rule.id] {
                    record.warningSent = true
                    store.records[rule.id] = record
                }
            }
        }

        if sessionSeconds >= limitSeconds && !store.isCoolingDown(now: store.now) {
            store.startCooldown(now: store.now)
        }

        store.blockerState = store.isCoolingDown(now: store.now) ? .active(store.rules.count) : .idle
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
