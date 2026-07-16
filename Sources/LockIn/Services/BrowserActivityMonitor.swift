import AppKit
import Foundation
import os

struct BrowserActivity: Equatable {
    var appName: String
    var bundleIdentifier: String
    var url: URL
}

@MainActor
protocol BrowserActivityMonitoring {
    func currentActivity() -> BrowserActivity?
    func redirectActiveTab(in activity: BrowserActivity, to url: URL)
}

@MainActor
final class BrowserActivityMonitor: BrowserActivityMonitoring {
    private let logger = Logger(subsystem: "com.local.LockIn", category: "browser")

    private let supportedBrowsers: [String: BrowserScript] = [
        "com.apple.Safari": .safari,
        "com.google.Chrome": .chromium(appName: "Google Chrome"),
        "company.thebrowser.Browser": .chromium(appName: "Arc")
    ]

    func currentActivity() -> BrowserActivity? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = application.bundleIdentifier else {
            logger.debug("No frontmost bundle identifier")
            return nil
        }

        guard let script = supportedBrowsers[bundleIdentifier] else {
            return nil
        }

        guard let url = script.activeTabURL(logger: logger) else {
            logger.warning("Could not read active tab URL for \(bundleIdentifier, privacy: .public)")
            return nil
        }

        return BrowserActivity(
            appName: application.localizedName ?? script.displayName,
            bundleIdentifier: bundleIdentifier,
            url: url
        )
    }

    func redirectActiveTab(in activity: BrowserActivity, to url: URL) {
        guard let script = supportedBrowsers[activity.bundleIdentifier] else {
            return
        }
        script.redirectActiveTab(to: url, logger: logger)
    }
}

private enum BrowserScript {
    case safari
    case chromium(appName: String)

    var displayName: String {
        switch self {
        case .safari:
            return "Safari"
        case .chromium(let appName):
            return appName
        }
    }

    func activeTabURL(logger: Logger) -> URL? {
        let source: String
        switch self {
        case .safari:
            source = """
            tell application "Safari"
                if not (exists front document) then return ""
                return URL of front document
            end tell
            """
        case .chromium(let appName):
            source = """
            tell application "\(appName)"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """
        }

        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            logger.warning("Could not compile browser AppleScript")
            return nil
        }

        let descriptor = script.executeAndReturnError(&error)
        if let error {
            logger.warning("Browser AppleScript failed: \(String(describing: error), privacy: .public)")
            return nil
        }

        guard let output = descriptor.stringValue,
              let url = URL(string: output) else {
            logger.debug("Browser AppleScript returned empty or invalid URL")
            return nil
        }
        return url
    }

    func redirectActiveTab(to url: URL, logger: Logger) {
        let source: String
        let escapedURL = url.absoluteString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        switch self {
        case .safari:
            source = """
            tell application "Safari"
                if not (exists front document) then return
                set URL of front document to "\(escapedURL)"
            end tell
            """
        case .chromium(let appName):
            source = """
            tell application "\(appName)"
                if (count of windows) is 0 then return ""
                set URL of active tab of front window to "\(escapedURL)"
            end tell
            """
        }

        runScript(source, logger: logger)
    }

    private func runScript(_ source: String, logger: Logger) {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            logger.warning("Could not compile browser redirect AppleScript")
            return
        }

        _ = script.executeAndReturnError(&error)
        if let error {
            logger.warning("Browser redirect AppleScript failed: \(String(describing: error), privacy: .public)")
        }
    }
}
