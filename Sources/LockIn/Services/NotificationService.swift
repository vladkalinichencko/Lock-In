import Foundation
import os
import UserNotifications

protocol UserNotifying {
    func requestAuthorization()
    func sendWarning(domain: String, minutesRemaining: Int)
}

final class NotificationService: NSObject, UserNotifying, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.local.LockIn", category: "notifications")

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [logger] granted, error in
            if let error {
                logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.info("Notification authorization granted: \(granted, privacy: .public)")
            }
        }
    }

    func sendWarning(domain: String, minutesRemaining: Int) {
        send(
            identifier: "warning-\(domain)",
            title: "Blocking soon",
            body: "\(domain) will be blocked in \(minutesRemaining) minutes."
        )
    }

    private func send(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error {
                logger.error("Notification failed for \(identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
