import AppKit
import SwiftUI
import XCTest
@testable import LockIn

@MainActor
final class MenuSizingTests: XCTestCase {
    func testMenuFitsContentAfterFocusAndPolicyChanges() async throws {
        let store = AppStore(persistence: PersistenceStore(
            fileURL: FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString)
                .appending(path: "state.json")
        ))
        let view = MenuHostingView(rootView: MenuBarView(store: store))
        view.frame.size = view.fittingSize
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView?.addSubview(view)
        let initialHeight = view.frame.height

        store.startFocus(minutes: 25)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertLessThan(view.frame.height, initialHeight)
        XCTAssertEqual(view.frame.height, view.fittingSize.height, accuracy: 1)

        store.expireFocusIfNeeded(now: Date().addingTimeInterval(1501))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(view.frame.height, initialHeight, accuracy: 1)

        store.sessionCountLimit = 3
        store.browserError = "Browser unavailable"
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertGreaterThan(view.frame.height, initialHeight)
        XCTAssertEqual(view.frame.height, view.fittingSize.height, accuracy: 1)

        store.sessionCountLimit = 1
        store.browserError = nil
        store.addRule(domain: "youtube.com/shorts")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertGreaterThan(view.frame.height, initialHeight)
        XCTAssertEqual(view.frame.height, view.fittingSize.height, accuracy: 1)

        store.remove(rule: try XCTUnwrap(store.rules.last))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(view.frame.height, initialHeight, accuracy: 1)
        withExtendedLifetime(window) {}
    }
}
