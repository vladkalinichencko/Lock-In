import Foundation
import Observation

@Observable
@MainActor
final class AppStore {
    var rules: [BlockRule] = []
    var applicationRules: [ApplicationRule] = []
    var records: [UUID: UsageRecord] = [:]
    var sessionLimitMinutes: Int = 30
    var sessionCountLimit: Int = 1
    var cooldownMinutes: Int = 60
    var resetHour: Int = 6
    var resetMinute: Int = 0
    var cooldownUntil: Date?
    var completedSessionCount: Int = 0
    var cumulativeSecondsUsed: Int = 0
    var currentActivity: BrowserActivity?
    var currentApplicationActivity: ApplicationActivity?
    var currentRuleID: UUID?
    var currentRuleSeenAt: Date?
    var activeRuleIDs: Set<UUID> = []
    var blockerState: BlockerState = .idle
    var guardianStatus: GuardianStatus = .unknown
    var lastError: String?
    var now: Date = Date()

    private let persistence: PersistenceStore
    private let guardian = GuardianService()
    private var attemptedAutomaticInstall = false

    init(persistence: PersistenceStore = PersistenceStore()) {
        self.persistence = persistence
        load()
    }

    var dayWindow: DayWindow {
        DayWindow(startHour: resetHour, startMinute: resetMinute)
    }

    func load() {
        guard persistence.hasSavedState else {
            rules = [
                BlockRule(domain: "x.com")
            ]
            lastError = nil
            return
        }

        do {
            let snapshot = try persistence.load()
            rules = snapshot.rules
            applicationRules = snapshot.applicationRules
            records = Dictionary(uniqueKeysWithValues: snapshot.records.map { ($0.ruleID, $0) })
            activeRuleIDs = Set(snapshot.activeRuleIDs)
            sessionLimitMinutes = snapshot.sessionLimitMinutes
            sessionCountLimit = snapshot.sessionCountLimit
            cooldownMinutes = snapshot.cooldownMinutes
            resetHour = snapshot.resetHour
            resetMinute = snapshot.resetMinute
            cooldownUntil = snapshot.cooldownUntil
            completedSessionCount = snapshot.completedSessionCount
            cumulativeSecondsUsed = snapshot.cumulativeSecondsUsed
        } catch {
            lastError = error.localizedDescription
            rules = [
                BlockRule(domain: "x.com")
            ]
        }
    }

    func save() {
        do {
            try persistence.save(
                AppSnapshot(
                    rules: rules,
                    applicationRules: applicationRules,
                    records: Array(records.values),
                    activeRuleIDs: Array(activeRuleIDs),
                    sessionLimitMinutes: sessionLimitMinutes,
                    sessionCountLimit: sessionCountLimit,
                    cooldownMinutes: cooldownMinutes,
                    resetHour: resetHour,
                    resetMinute: resetMinute,
                    cooldownUntil: cooldownUntil,
                    completedSessionCount: completedSessionCount,
                    cumulativeSecondsUsed: cumulativeSecondsUsed
                )
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    var totalSecondsUsed: Int {
        cumulativeSecondsUsed
    }

    var sessionSecondsUsed: Int {
        records.values.reduce(0) { $0 + $1.secondsUsed }
    }

    var totalSecondsAllowed: Int {
        LockInPolicy.totalSecondsAllowed(
            sessionMinutes: sessionLimitMinutes,
            sessionCount: sessionCountLimit
        )
    }

    var isCoolingDown: Bool {
        isCoolingDown(now: Date())
    }

    var canEditList: Bool {
        canEditPolicy
    }

    var canEditPolicy: Bool {
        LockInPolicy.canEdit(
            cumulativeSecondsUsed: totalSecondsUsed,
            completedSessionCount: completedSessionCount,
            cooldownUntil: cooldownUntil
        )
    }

    func refreshGuardianStatus() {
        guardianStatus = guardian.status()
    }

    func installGuardian() {
        do {
            try guardian.install()
            guardianStatus = .installed
            lastError = nil
        } catch {
            guardianStatus = .failed(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    func ensureProtectionInstalled() {
        guard !attemptedAutomaticInstall else {
            return
        }
        attemptedAutomaticInstall = true

        refreshGuardianStatus()

        if guardianStatus != .installed {
            installGuardian()
        }
    }

    @discardableResult
    func addRule(domain: String) -> Bool {
        guard let domain = DomainMatcher.normalizedDomain(domain) else {
            return false
        }
        guard !rules.contains(where: { $0.domain == domain }) else {
            return true
        }
        rules.append(BlockRule(domain: domain))
        save()
        return true
    }

    func canRemove(rule: BlockRule) -> Bool {
        canEditPolicy && (records[rule.id]?.secondsUsed ?? 0) == 0
    }

    func remove(rule: BlockRule) {
        guard canRemove(rule: rule), let index = rules.firstIndex(where: { $0.id == rule.id }) else {
            return
        }
        rules.remove(at: index)
        records.removeValue(forKey: rule.id)
        save()
    }

    @discardableResult
    func addApplication(url: URL) -> Bool {
        guard canEditPolicy,
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier,
              bundleIdentifier != Bundle.main.bundleIdentifier else {
            return false
        }
        guard !applicationRules.contains(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return true
        }
        applicationRules.append(ApplicationRule(
            name: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent,
            bundleIdentifier: bundleIdentifier
        ))
        save()
        return true
    }

    func canRemove(applicationRule: ApplicationRule) -> Bool {
        canEditPolicy && (records[applicationRule.id]?.secondsUsed ?? 0) == 0
    }

    func remove(applicationRule: ApplicationRule) {
        guard canRemove(applicationRule: applicationRule),
              let index = applicationRules.firstIndex(where: { $0.id == applicationRule.id }) else {
            return
        }
        applicationRules.remove(at: index)
        records.removeValue(forKey: applicationRule.id)
        save()
    }

    func updateSessionLimitMinutes(_ value: Int) {
        guard canEditPolicy else {
            return
        }
        sessionLimitMinutes = LockInPolicy.clamp(value, min: 1, max: 480)
        save()
    }

    func updateSessionCountLimit(_ value: Int) {
        guard canEditPolicy else {
            return
        }
        sessionCountLimit = LockInPolicy.clamp(value, min: 1, max: 24)
        save()
    }

    func updateCooldownMinutes(_ value: Int) {
        guard canEditPolicy else {
            return
        }
        cooldownMinutes = LockInPolicy.clamp(value, min: 1, max: 1440)
        save()
    }

    func updateResetHour(_ value: Int) {
        guard canEditPolicy else {
            return
        }
        resetHour = LockInPolicy.clamp(value, min: 0, max: 23)
        save()
    }

    func updateResetMinute(_ value: Int) {
        guard canEditPolicy else {
            return
        }
        resetMinute = LockInPolicy.clamp(value, min: 0, max: 59)
        save()
    }

    func resetIfNeeded(now: Date = Date()) {
        let windowStart = dayWindow.currentStart(for: now)
        var didReset = false
        for ruleID in allRuleIDs {
            if records[ruleID]?.windowStart != windowStart {
                records[ruleID] = UsageRecord(
                    ruleID: ruleID,
                    windowStart: windowStart,
                    secondsUsed: 0,
                    warningSent: false,
                    isBlocked: false
                )
                didReset = true
            }
        }
        if didReset {
            cooldownUntil = nil
            completedSessionCount = 0
            cumulativeSecondsUsed = 0
            blockerState = .idle
            save()
        }
    }

    func recordUsage(ruleID: UUID, seconds: Int, now: Date = Date()) {
        resetIfNeeded(now: now)
        guard var record = records[ruleID] else {
            return
        }
        currentRuleID = ruleID
        currentRuleSeenAt = now
        record.secondsUsed += seconds
        cumulativeSecondsUsed += seconds
        records[ruleID] = record
        save()
    }

    func startCooldown(now: Date = Date()) {
        guard cooldownUntil == nil else {
            return
        }
        completedSessionCount += 1
        if completedSessionCount >= sessionCountLimit {
            cooldownUntil = dayWindow.nextStart(after: now)
        } else {
            cooldownUntil = now.addingTimeInterval(TimeInterval(cooldownMinutes * 60))
        }
        for ruleID in allRuleIDs {
            if var record = records[ruleID] {
                record.isBlocked = true
                records[ruleID] = record
            }
        }
        blockerState = .active(allRuleIDs.count)
        save()
    }

    func expireCooldownIfNeeded(now: Date = Date()) {
        guard let cooldownUntil, now >= cooldownUntil else {
            return
        }
        clearSession(now: now)
    }

    func isCoolingDown(now: Date = Date()) -> Bool {
        guard let cooldownUntil else {
            return false
        }
        return now < cooldownUntil
    }

    private func clearSession(now: Date) {
        let windowStart = dayWindow.currentStart(for: now)
        for ruleID in allRuleIDs {
            records[ruleID] = UsageRecord(
                ruleID: ruleID,
                windowStart: windowStart,
                secondsUsed: 0,
                warningSent: false,
                isBlocked: false
            )
        }
        cooldownUntil = nil
        blockerState = .idle
        save()
    }

    func setActiveRuleIDs(_ ruleIDs: Set<UUID>) {
        guard activeRuleIDs != ruleIDs else {
            return
        }
        activeRuleIDs = ruleIDs
        save()
    }

    func clearCurrentRuleIfStale(now: Date = Date()) {
        guard let currentRuleSeenAt else {
            currentRuleID = nil
            return
        }
        if now.timeIntervalSince(currentRuleSeenAt) > 10 {
            currentRuleID = nil
        }
    }

    func reloadUsageFromDisk() {
        guard persistence.hasSavedState else {
            return
        }

        do {
            let snapshot = try persistence.load()
            records = Dictionary(uniqueKeysWithValues: snapshot.records.map { ($0.ruleID, $0) })
            activeRuleIDs = Set(snapshot.activeRuleIDs)
            cooldownUntil = snapshot.cooldownUntil
            completedSessionCount = snapshot.completedSessionCount
            cumulativeSecondsUsed = snapshot.cumulativeSecondsUsed
            currentRuleID = snapshot.activeRuleIDs.first
            currentRuleSeenAt = snapshot.activeRuleIDs.isEmpty ? nil : Date()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    var allRuleIDs: [UUID] {
        rules.map(\.id) + applicationRules.map(\.id)
    }
}
