import Foundation
import Observation

@Observable
@MainActor
final class AppRuntime {
    let store: AppStore
    private let controller: UsageController

    init() {
        let store = AppStore()
        self.store = store
        self.controller = UsageController(store: store)
        controller.start()
        Task { @MainActor in
            store.ensureProtectionInstalled()
        }
    }
}
