import Darwin
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
    private let customFileURL: URL?

    init(fileURL: URL? = nil) {
        customFileURL = fileURL
    }

    func update(_ change: (inout LockInSnapshot) throws -> Void) throws -> LockInSnapshot {
        let lockURL = try fileURL.appendingPathExtension("lock")
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
        defer { flock(descriptor, LOCK_UN) }
        var snapshot = try load()
        let before = snapshot
        try change(&snapshot)
        if snapshot != before { try save(snapshot) }
        return snapshot
    }

    var fileURL: URL {
        get throws {
            if let customFileURL { return customFileURL }
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

    private func save(_ snapshot: LockInSnapshot) throws {
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
