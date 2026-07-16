import Foundation

enum LockInSharedStoreError: LocalizedError {
    case missingAppGroup(String)

    var errorDescription: String? {
        switch self {
        case .missingAppGroup(let identifier):
            "App Group is not available: \(identifier)"
        }
    }
}

struct LockInSharedStore {
    var fileURL: URL {
        get throws {
            guard let baseURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: LockInConstants.appGroupID
            ) else {
                throw LockInSharedStoreError.missingAppGroup(LockInConstants.appGroupID)
            }
            return baseURL.appending(path: LockInConstants.stateFileName)
        }
    }

    func load() throws -> LockInSnapshot {
        let url = try fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return LockInSnapshot()
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(LockInSnapshot.self, from: data)
    }

    func save(_ snapshot: LockInSnapshot) throws {
        let url = try fileURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: [.atomic])
    }
}

