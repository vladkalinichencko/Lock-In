import AppKit
import SwiftUI

@main
struct LockInApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var runtime: AppRuntime?
    private var statusItem: NSStatusItem?

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
        let runtime = AppRuntime()
        self.runtime = runtime

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "Lock In")
            button.image?.isTemplate = true
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        let menuItem = NSMenuItem()
        let menuView = NSHostingView(rootView: MenuBarView(store: runtime.store))
        menuView.frame.size = menuView.fittingSize
        menuItem.view = menuView
        menu.addItem(menuItem)
        statusItem.menu = menu
        self.statusItem = statusItem
    }
}
