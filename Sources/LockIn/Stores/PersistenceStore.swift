import Foundation

struct AppSnapshot: Codable {
    var rules: [BlockRule]
    var applicationRules: [ApplicationRule]
    var records: [UsageRecord]
    var activeRuleIDs: [UUID]
    var sessionLimitMinutes: Int
    var sessionCountLimit: Int
    var cooldownMinutes: Int
    var resetHour: Int
    var resetMinute: Int
    var cooldownUntil: Date?
    var completedSessionCount: Int
    var cumulativeSecondsUsed: Int

    enum CodingKeys: String, CodingKey {
        case rules
        case applicationRules
        case records
        case activeRuleIDs
        case sessionLimitMinutes
        case sessionCountLimit
        case cooldownMinutes
        case resetHour
        case resetMinute
        case cooldownUntil
        case completedSessionCount
        case cumulativeSecondsUsed
        case dailyAllowanceMinutes
        case dayStartHour
        case dayStartMinute
    }

    init(
        rules: [BlockRule],
        applicationRules: [ApplicationRule] = [],
        records: [UsageRecord],
        activeRuleIDs: [UUID] = [],
        sessionLimitMinutes: Int,
        sessionCountLimit: Int = 1,
        cooldownMinutes: Int,
        resetHour: Int,
        resetMinute: Int,
        cooldownUntil: Date? = nil,
        completedSessionCount: Int = 0,
        cumulativeSecondsUsed: Int = 0
    ) {
        self.rules = rules
        self.applicationRules = applicationRules
        self.records = records
        self.activeRuleIDs = activeRuleIDs
        self.sessionLimitMinutes = sessionLimitMinutes
        self.sessionCountLimit = sessionCountLimit
        self.cooldownMinutes = cooldownMinutes
        self.resetHour = resetHour
        self.resetMinute = resetMinute
        self.cooldownUntil = cooldownUntil
        self.completedSessionCount = completedSessionCount
        self.cumulativeSecondsUsed = cumulativeSecondsUsed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rules = try container.decode([BlockRule].self, forKey: .rules)
        applicationRules = try container.decodeIfPresent([ApplicationRule].self, forKey: .applicationRules) ?? []
        records = try container.decode([UsageRecord].self, forKey: .records)
        activeRuleIDs = try container.decodeIfPresent([UUID].self, forKey: .activeRuleIDs) ?? []
        sessionLimitMinutes = try container.decodeIfPresent(Int.self, forKey: .sessionLimitMinutes)
            ?? container.decodeIfPresent(Int.self, forKey: .dailyAllowanceMinutes)
            ?? 30
        sessionCountLimit = try container.decodeIfPresent(Int.self, forKey: .sessionCountLimit) ?? 1
        cooldownMinutes = try container.decodeIfPresent(Int.self, forKey: .cooldownMinutes) ?? 60
        resetHour = try container.decodeIfPresent(Int.self, forKey: .resetHour)
            ?? container.decodeIfPresent(Int.self, forKey: .dayStartHour)
            ?? 6
        resetMinute = try container.decodeIfPresent(Int.self, forKey: .resetMinute)
            ?? container.decodeIfPresent(Int.self, forKey: .dayStartMinute)
            ?? 0
        cooldownUntil = try container.decodeIfPresent(Date.self, forKey: .cooldownUntil)
        completedSessionCount = try container.decodeIfPresent(Int.self, forKey: .completedSessionCount) ?? 0
        cumulativeSecondsUsed = try container.decodeIfPresent(Int.self, forKey: .cumulativeSecondsUsed)
            ?? records.reduce(0) { $0 + $1.secondsUsed }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rules, forKey: .rules)
        try container.encode(applicationRules, forKey: .applicationRules)
        try container.encode(records, forKey: .records)
        try container.encode(activeRuleIDs, forKey: .activeRuleIDs)
        try container.encode(sessionLimitMinutes, forKey: .sessionLimitMinutes)
        try container.encode(sessionCountLimit, forKey: .sessionCountLimit)
        try container.encode(cooldownMinutes, forKey: .cooldownMinutes)
        try container.encode(resetHour, forKey: .resetHour)
        try container.encode(resetMinute, forKey: .resetMinute)
        try container.encodeIfPresent(cooldownUntil, forKey: .cooldownUntil)
        try container.encode(completedSessionCount, forKey: .completedSessionCount)
        try container.encode(cumulativeSecondsUsed, forKey: .cumulativeSecondsUsed)
    }
}

struct PersistenceStore {
    private let customFileURL: URL?

    init(fileURL: URL? = nil) {
        self.customFileURL = fileURL
    }

    var fileURL: URL {
        if let customFileURL {
            return customFileURL
        }
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL.appending(path: "LockIn/state.json")
    }

    var hasSavedState: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    func load() throws -> AppSnapshot {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(AppSnapshot.self, from: data)
    }

    func save(_ snapshot: AppSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }
}
