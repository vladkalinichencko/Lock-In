import DeviceActivity
import Foundation
import ManagedSettings

enum LockInConstants {
    static let appGroupID = "group.com.local.LockIn"
    nonisolated(unsafe) static let activityName = DeviceActivityName("lockin.daily")
    nonisolated(unsafe) static let breakActivityName = DeviceActivityName("lockin.break")
    nonisolated(unsafe) static let warningEventName = DeviceActivityEvent.Name("lockin.warning")
    nonisolated(unsafe) static let sessionLimitEventName = DeviceActivityEvent.Name("lockin.sessionLimit")
    nonisolated(unsafe) static let storeName = ManagedSettingsStore.Name("lockin")
    static let stateFileName = "state.json"
}
