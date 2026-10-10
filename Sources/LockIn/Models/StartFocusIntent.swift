import AppIntents

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Start focus"
    static let description = IntentDescription("Block selected apps and websites for your focus duration.")
    static let openAppWhenRun = true

    @Parameter(title: "Minutes")
    var minutes: Int?

    @MainActor
    func perform() async throws -> some IntentResult {
        #if os(macOS)
        let store = AppStore.shared
        store.reloadUsageFromDisk()
        let duration = minutes ?? store.focusMinutes
        guard (1...1440).contains(duration) else {
            throw $minutes.needsValueError("Choose between 1 and 1440 minutes.")
        }
        guard !store.allRuleIDs.isEmpty else {
            throw FocusIntentError.selectionRequired
        }
        store.startFocus(minutes: duration)
        if let error = store.lastError {
            throw FocusIntentError.persistence(error)
        }
        #else
        let store = LockInStore.shared
        try store.startFocus(minutes: minutes ?? store.focusMinutes)
        #endif
        return .result()
    }
}

private enum FocusIntentError: Error, CustomLocalizedStringResourceConvertible {
    case selectionRequired
    case persistence(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .selectionRequired: "Select apps or websites in Lock In."
        case .persistence(let message): "\(message)"
        }
    }
}

struct LockInShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: ["Start focus with \(.applicationName)"],
            shortTitle: "Start focus",
            systemImageName: "lock.fill"
        )
    }
}
