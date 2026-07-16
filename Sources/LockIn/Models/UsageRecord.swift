import Foundation

struct UsageRecord: Codable, Equatable {
    var ruleID: UUID
    var windowStart: Date
    var secondsUsed: Int
    var warningSent: Bool
    var isBlocked: Bool
}
