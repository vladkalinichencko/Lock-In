import Foundation

enum GuardianStatus: Equatable {
    case unknown
    case installed
    case notInstalled
    case failed(String)
}

@MainActor
final class GuardianService {
    private let label = "com.local.LockIn.guardian"
    private let bundleID = "com.local.LockIn"
    private let processName = "LockIn"

    var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/LaunchAgents/\(label).plist")
    }

    func status() -> GuardianStatus {
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            return .notInstalled
        }

        guard let appBundleURL = appBundleURL(),
              let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let arguments = plist["ProgramArguments"] as? [String],
              arguments.contains(appBundleURL.path) else {
            return .notInstalled
        }

        guard isLoaded() else {
            return .notInstalled
        }

        return .installed
    }

    func install() throws {
        guard let appBundleURL = appBundleURL(),
              let guardianURL = guardianURL(in: appBundleURL) else {
            throw NSError(
                domain: "LockIn.GuardianService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Run Lock In from its .app bundle before installing persistence."]
            )
        }

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [
                guardianURL.path,
                "--app-bundle",
                appBundleURL.path,
                "--bundle-id",
                bundleID,
                "--process-name",
                processName
            ],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ThrottleInterval": 2,
            "StandardOutPath": logURL(named: "guardian.out.log").path,
            "StandardErrorPath": logURL(named: "guardian.err.log").path
        ]

        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: logURL(named: "guardian.out.log").deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL, options: [.atomic])

        _ = try? runLaunchctl(arguments: ["bootout", "gui/\(getuid())", plistURL.path])
        try runLaunchctl(arguments: ["bootstrap", "gui/\(getuid())", plistURL.path])
        try runLaunchctl(arguments: ["enable", "gui/\(getuid())/\(label)"])
        try runLaunchctl(arguments: ["kickstart", "-k", "gui/\(getuid())/\(label)"])
    }

    private func appBundleURL() -> URL? {
        let bundleURL = Bundle.main.bundleURL
        return bundleURL.pathExtension == "app" ? bundleURL : nil
    }

    private func guardianURL(in appBundleURL: URL) -> URL? {
        let url = appBundleURL
            .appending(path: "Contents/MacOS/LockInGuardian")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    private func logURL(named name: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Logs/LockIn/\(name)")
    }

    private func isLoaded() -> Bool {
        (try? runLaunchctl(arguments: ["print", "gui/\(getuid())/\(label)"])) != nil
    }

    @discardableResult
    private func runLaunchctl(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "LockIn.GuardianService",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: error.isEmpty ? output : error]
            )
        }

        return output
    }
}
