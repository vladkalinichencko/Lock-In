import AppKit
import SwiftUI
import XCTest
@testable import LockIn

@MainActor
final class MenuSizingTests: XCTestCase {
    func testMenuKeepsItsContentSizeAcrossStates() async throws {
        let store = AppStore(persistence: PersistenceStore(
            fileURL: FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString)
                .appending(path: "state.json")
        ))
        let view = NSHostingView(rootView: MenuBarView(store: store))
        view.frame.size = view.fittingSize
        let menu = NSMenu()
        let item = NSMenuItem()
        item.view = view
        menu.addItem(item)
        let delegate = AppDelegate()
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView?.addSubview(view)
        let initialHeight = view.frame.height
        let initialWidth = view.frame.width
        try await Task.sleep(for: .milliseconds(100))
        let resetPicker = try XCTUnwrap(descendant(of: NSDatePicker.self, in: view))
        let pickerFrame = view.convert(resetPicker.bounds, from: resetPicker)
        let bottomGap = view.isFlipped ? view.bounds.maxY - pickerFrame.maxY : pickerFrame.minY - view.bounds.minY
        XCTAssertEqual(bottomGap, 12, accuracy: 1, "Only the menu's outer padding should remain below Reset time")

        store.startFocus(minutes: 25)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(view.fittingSize.height, initialHeight, accuracy: 1)

        store.toggleFocusPause()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(view.fittingSize.height, initialHeight, accuracy: 1)
        XCTAssertNotNil(NSImage(systemSymbolName: store.statusSymbolName, accessibilityDescription: nil))
        store.toggleFocusPause()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(view.fittingSize.height, initialHeight, accuracy: 1)
        XCTAssertNotNil(NSImage(systemSymbolName: store.statusSymbolName, accessibilityDescription: nil))

        store.expireFocusIfNeeded(now: Date().addingTimeInterval(1501))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(view.fittingSize.height, initialHeight, accuracy: 1)

        store.sessionCountLimit = 3
        store.browserError = "Browser unavailable"
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(view.fittingSize.height, initialHeight, accuracy: 1)

        store.sessionCountLimit = 1
        store.browserError = nil
        store.addRule(domain: "a-very-long-website-name.example.com/longer-path")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertGreaterThan(view.fittingSize.height, initialHeight)
        XCTAssertGreaterThan(view.fittingSize.width, initialWidth)
        delegate.menuWillOpen(menu)
        XCTAssertEqual(view.frame.size, view.fittingSize)

        store.remove(rule: try XCTUnwrap(store.rules.last))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(view.fittingSize.height, initialHeight, accuracy: 1)
        XCTAssertEqual(view.fittingSize.width, initialWidth, accuracy: 1)
        delegate.menuWillOpen(menu)
        XCTAssertEqual(view.frame.size, view.fittingSize)

        store.focusMinutes = 0
        store.cooldownUntil = Date().addingTimeInterval(60)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(view.fittingSize.height, initialHeight, accuracy: 1)
        withExtendedLifetime(window) {}
    }

    private func descendant<T: NSView>(of type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        return view.subviews.lazy.compactMap { self.descendant(of: type, in: $0) }.first
    }
}
