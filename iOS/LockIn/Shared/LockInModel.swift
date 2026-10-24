import FamilyControls
import Foundation

struct LockInSnapshot: Codable, Equatable {
    var selection: FamilyActivitySelection
    var sessionLimitMinutes: Int
    var sessionCountLimit: Int
    var breakMinutes: Int
    var resetHour: Int
    var resetMinute: Int
    var completedSessionCount: Int
    var cumulativeSecondsUsed: Int
    var currentSessionSecondsUsed: Int
    var cooldownUntil: Date?
    var warningSentForSession: Bool
    var focusMinutes: Int?
    var focusUntil: Date?
    var focusPausedAt: Date?
    var timeRestrictions: TimeRestrictions?
    var lastUsedAt: Date?
    var windowStart: Date?
    var sessionID: UUID?

    var restrictions: TimeRestrictions { timeRestrictions ?? TimeRestrictions() }

    init(
        selection: FamilyActivitySelection = FamilyActivitySelection(),
        sessionLimitMinutes: Int = 30,
        sessionCountLimit: Int = 1,
        breakMinutes: Int = 60,
        resetHour: Int = 6,
        resetMinute: Int = 0,
        completedSessionCount: Int = 0,
        cumulativeSecondsUsed: Int = 0,
        currentSessionSecondsUsed: Int = 0,
        cooldownUntil: Date? = nil,
        warningSentForSession: Bool = false,
        focusMinutes: Int? = nil,
        focusUntil: Date? = nil,
        focusPausedAt: Date? = nil
    ) {
        self.selection = selection
        self.sessionLimitMinutes = LockInPolicy.clamp(sessionLimitMinutes, min: 1, max: 480)
        self.sessionCountLimit = LockInPolicy.clamp(sessionCountLimit, min: 1, max: 24)
        self.breakMinutes = LockInPolicy.clamp(breakMinutes, min: 1, max: 1440)
        self.resetHour = LockInPolicy.clamp(resetHour, min: 0, max: 23)
        self.resetMinute = LockInPolicy.clamp(resetMinute, min: 0, max: 59)
        self.completedSessionCount = max(0, completedSessionCount)
        self.cumulativeSecondsUsed = max(0, cumulativeSecondsUsed)
        self.currentSessionSecondsUsed = max(0, currentSessionSecondsUsed)
        self.cooldownUntil = cooldownUntil
        self.warningSentForSession = warningSentForSession
        self.focusMinutes = focusMinutes
        self.focusUntil = focusUntil
        self.focusPausedAt = focusPausedAt
    }

    var totalSecondsAllowed: Int {
        LockInPolicy.totalSecondsAllowed(
            sessionMinutes: sessionLimitMinutes,
            sessionCount: sessionCountLimit
        )
    }

    var canEditPolicy: Bool {
        !isFocusing() && LockInPolicy.canEdit(
            cumulativeSecondsUsed: cumulativeSecondsUsed,
            completedSessionCount: completedSessionCount,
            cooldownUntil: cooldownUntil
        )
    }

    func isFocusing(at date: Date = Date()) -> Bool {
        focusUntil.map { (focusPausedAt ?? date) < $0 } ?? false
    }

    mutating func toggleFocusPause(at date: Date = Date()) {
        guard isFocusing(at: date), let focusUntil else { return }
        if let pausedAt = focusPausedAt {
            self.focusUntil = focusUntil.addingTimeInterval(date.timeIntervalSince(pausedAt))
            focusPausedAt = nil
        } else {
            focusPausedAt = date
        }
    }

    func isBlocking(at date: Date = Date()) -> Bool {
        restrictions.downtime?.contains(date) == true || isFocusing(at: date)
            || completedSessionCount >= sessionCountLimit || (cooldownUntil.map { date < $0 } ?? false)
    }

    mutating func reconcile(at date: Date, calendar: Calendar = .current) {
        let start = LockInSchedule.dayWindowStart(for: date, snapshot: self, calendar: calendar)
        if windowStart == nil {
            windowStart = start
            sessionID = UUID()
        } else if windowStart != start {
            windowStart = start
            completedSessionCount = 0
            cumulativeSecondsUsed = 0
            clearSession()
        } else if cooldownUntil == nil, let lastUsedAt,
                  let deadline = restrictions.residualReset(
                    lastUsedAt: lastUsedAt, secondsUsed: currentSessionSecondsUsed,
                    sessionMinutes: sessionLimitMinutes, breakMinutes: breakMinutes
                  ), date >= deadline.addingTimeInterval(60) {
            finishSession(at: lastUsedAt.addingTimeInterval(60), calendar: calendar)
        }
        if let end = cooldownUntil, date >= end, completedSessionCount < sessionCountLimit {
            clearSession()
        }
        if focusPausedAt == nil, let end = focusUntil, date >= end {
            focusUntil = nil
        }
    }

    mutating func recordThreshold(minutes: Int, at date: Date) {
        guard cooldownUntil == nil, completedSessionCount < sessionCountLimit,
              minutes * 60 > currentSessionSecondsUsed else { return }
        cumulativeSecondsUsed += minutes * 60 - currentSessionSecondsUsed
        currentSessionSecondsUsed = minutes * 60
        lastUsedAt = date
        if minutes >= sessionLimitMinutes { finishSession(at: date) }
    }

    private mutating func finishSession(at date: Date, calendar: Calendar = .current) {
        completedSessionCount += 1
        cooldownUntil = completedSessionCount >= sessionCountLimit
            ? LockInSchedule.nextReset(after: date, snapshot: self, calendar: calendar)
            : date.addingTimeInterval(TimeInterval(breakMinutes * 60))
    }

    private mutating func clearSession() {
        currentSessionSecondsUsed = 0
        cooldownUntil = nil
        warningSentForSession = false
        lastUsedAt = nil
        sessionID = UUID()
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty ||
        !selection.categoryTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty
    }
}
