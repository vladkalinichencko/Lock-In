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
        warningSentForSession: Bool = false
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
    }

    var totalSecondsAllowed: Int {
        LockInPolicy.totalSecondsAllowed(
            sessionMinutes: sessionLimitMinutes,
            sessionCount: sessionCountLimit
        )
    }

    var canEditPolicy: Bool {
        LockInPolicy.canEdit(
            cumulativeSecondsUsed: cumulativeSecondsUsed,
            completedSessionCount: completedSessionCount,
            cooldownUntil: cooldownUntil
        )
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty ||
        !selection.categoryTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty
    }

    static func clamp(_ value: Int, min minimum: Int, max maximum: Int) -> Int {
        LockInPolicy.clamp(value, min: minimum, max: maximum)
    }
}
