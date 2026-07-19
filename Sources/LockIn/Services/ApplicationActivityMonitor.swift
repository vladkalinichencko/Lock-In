import AppKit

struct ApplicationActivity: Equatable {
    var name: String
    var bundleIdentifier: String
    var processIdentifier: pid_t
}

@MainActor
protocol ApplicationActivityMonitoring {
    func currentActivity() -> ApplicationActivity?
    func block(_ activity: ApplicationActivity)
}

@MainActor
final class ApplicationActivityMonitor: ApplicationActivityMonitoring {
    func currentActivity() -> ApplicationActivity? {
        guard let application = NSWorkspace.shared.frontmostApplication,
            let bundleIdentifier = application.bundleIdentifier
        else {
            return nil
        }

        return ApplicationActivity(
            name: application.localizedName ?? bundleIdentifier,
            bundleIdentifier: bundleIdentifier,
            processIdentifier: application.processIdentifier
        )
    }

    func block(_ activity: ApplicationActivity) {
        NSRunningApplication(processIdentifier: activity.processIdentifier)?.terminate()
    }
}
