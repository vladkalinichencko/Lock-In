import Foundation

struct GuardianConfig {
    var appBundlePath: String
    var bundleIdentifier: String
    var processName: String
    var intervalSeconds: UInt32 = 2
}

func parseConfig() -> GuardianConfig? {
    let arguments = CommandLine.arguments
    guard let appIndex = arguments.firstIndex(of: "--app-bundle"),
          arguments.indices.contains(appIndex + 1),
          let bundleIndex = arguments.firstIndex(of: "--bundle-id"),
          arguments.indices.contains(bundleIndex + 1),
          let processIndex = arguments.firstIndex(of: "--process-name"),
          arguments.indices.contains(processIndex + 1) else {
        return nil
    }

    return GuardianConfig(
        appBundlePath: arguments[appIndex + 1],
        bundleIdentifier: arguments[bundleIndex + 1],
        processName: arguments[processIndex + 1]
    )
}

func isAppRunning(processName: String) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    process.arguments = ["-x", processName]
    process.standardOutput = Pipe()
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}

func launchApp(at path: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [path]
    process.standardOutput = Pipe()
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        FileHandle.standardError.write(Data("Failed to launch app: \(error)\n".utf8))
    }
}

guard let config = parseConfig() else {
    FileHandle.standardError.write(Data("usage: LockInGuardian --app-bundle PATH --bundle-id ID --process-name NAME\n".utf8))
    exit(2)
}

while true {
    if !isAppRunning(processName: config.processName) {
        launchApp(at: config.appBundlePath)
    }
    sleep(config.intervalSeconds)
}
