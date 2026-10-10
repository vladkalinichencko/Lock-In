import AppKit
import SwiftUI

@main
struct LockInApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var runtime = AppRuntime()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: runtime.store)
        } label: {
            Label("Lock In", systemImage: runtime.store.isFocusing(now: runtime.store.now) ? "lock.fill" : "hand.raised.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let duplicate = NSWorkspace.shared.runningApplications.contains { application in
            application.bundleIdentifier == Bundle.main.bundleIdentifier &&
            application.processIdentifier != currentPID
        }

        if duplicate {
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
