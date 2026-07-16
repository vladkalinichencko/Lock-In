import ManagedSettings
import ManagedSettingsUI
import os
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let logger = Logger(subsystem: "com.local.LockIn", category: "ShieldConfiguration")

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        configuration()
    }

    private func configuration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            title: ShieldConfiguration.Label(text: "Locked In", color: .label),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: .secondaryLabel)
        )
    }

    private var subtitle: String {
        do {
            let snapshot = try LockInSharedStore().load()
            guard let cooldownUntil = snapshot.cooldownUntil else {
                return "Blocked until your next day."
            }
            let nextReset = LockInSchedule.nextReset(after: Date(), snapshot: snapshot)
            if abs(cooldownUntil.timeIntervalSince(nextReset)) < 1 {
                return "Blocked until your next day."
            }
            return "Blocked until the break ends."
        } catch {
            logger.error("Shield configuration failed: \(error.localizedDescription, privacy: .public)")
            return "Lock In cannot read settings."
        }
    }
}
