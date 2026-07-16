import SwiftUI

@main
struct LockInApp: App {
    @State private var store = LockInStore()

    var body: some Scene {
        WindowGroup {
            LockInView(store: store)
        }
    }
}

