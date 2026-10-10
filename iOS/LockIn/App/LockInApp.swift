import SwiftUI

@main
struct LockInApp: App {
    @State private var store = LockInStore.shared

    var body: some Scene {
        WindowGroup {
            LockInView(store: store)
        }
    }
}

