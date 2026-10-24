# Lock In

## Current state

Mac and iPhone share the warning window and daily downtime range through TimeRestrictions in LockInPolicy.swift. TimeRestrictionsView uses native steppers, a toggle, and time pickers inside the original Mac menu and iPhone List. The time rows remain visible when disabled, so toggling downtime keeps the menu's dimensions stable. A zero-minute warning disables both the notification and residual-session expiry. Downtime applies to every selected app and website, including overnight, independently of the daily reset and focus timer.

Leaving a selected app or site with at most the warning window remaining completes that session after a full break without activity. An earlier exit retains the residual allowance. Returning during the break restarts the inactivity interval. The next session receives its full allowance; completing the last session keeps the selection blocked until daily reset. Actual usage remains in the daily total; discarded allowance is not counted as use. Mac lastUsedAt survives relaunch. iPhone records minute thresholds and waits one additional minute before residual expiry, because Screen Time does not report app-exit events. Device Activity event names include a session identifier, so callbacks from completed sessions cannot affect a new one.

iPhone app and extensions update one shared snapshot under a file lock and write it atomically. LockInSnapshot.reconcile owns daily reset, residual expiry, break expiry, and focus expiry. Starting or restarting Device Activity within the same day preserves the day's usage. The end of any one restriction reconciles the remaining restrictions before clearing the shield. Short breaks reuse the existing dated schedule with its start at least 15 minutes before its end; short downtime ranges monitor the complementary availability interval to keep Device Activity's minimum interval.

Focus has a duration field, native Start focus button, and pause/resume control. Pause freezes the countdown while selected apps and websites remain blocked. focusPausedAt is persisted alongside focusUntil; resume shifts the deadline by the paused duration. Focus and downtime do not spend the normal usage allowance. The Mac retains its original NSStatusItem and NSMenu. Its status icon is hand.raised.fill when idle, timer during focus, and pause.circle on pause. Blocking is derived from current restrictions rather than stored in a second state or per-rule flag.

## Standing correction

1. The user rejected "полностью поменял вообще весь дизайн" and requested "Верни точно дизайн, который был". Preserve the original system menu, background, layout, and control styles from 41e837a. Requested features belong inside that layout; do not replace the presentation with a new window, grouped Form, or custom visual treatment.
2. The user rejected live menu resizing as "рамка в рамке" and requested a stable layout. Use the original NSHostingView. The focus field and button stay in place; a countdown overlays the button label while focus disables both controls. Break and removal controls stay visible and become disabled. Errors and the break countdown occupy the existing usage label's bounds in the header. Clicking Error opens a native alert with the full message. The menu ends at Reset time with ordinary outer padding.
3. The user reported that the menu exceeded its content size and requested "не делай эти значения хардкоженными". MenuBarView uses fixedSize() to report its natural dimensions, including natural rule-list height. NSMenuDelegate.menuWillOpen fits the hosting view to that content before presentation. Focus transitions keep the same layout; rule-list edits are reflected in the menu's dimensions at the next opening.
4. Launch must create only the status-bar item. The Mac entry point runs NSApplication with its existing AppDelegate; SwiftUI is used only for menu content. An empty Settings scene creates a real settings window and has no role in this app. LLDB inspection of the preceding installed build found com_apple_SwiftUI_Settings_window among NSApplication.shared.windows. After installing 0c0dd57 and restarting, the window inventory contained only NSStatusBarWindow; the settings window was absent. All 25 Mac tests passed.

Dia URL reads and redirects use the focused tab in the front window's active profile, including pinned tabs. The installed Dia scripting dictionary exposes isFocused. The original youtube.com/shorts rule matches Shorts and excludes ordinary watch pages. On 2026-10-24 the running /Applications build was still the October 10 binary. Its logs showed the old active-tab read failure. Installing the current build restored detection: the persisted Shorts usage increased from 911 to 1015 seconds after installation, with the existing rules and policy preserved. Live read-only queries also returned valid URLs from installed Chrome and Safari. The controller regression exercises matching, allowance consumption, and redirect; a live Shorts redirect at the actual limit has not been forced.

BrowserActivityMonitor treats an absent URL as no browser activity, reports actual AppleScript failures, and shows Automation guidance only for error -1743. The permission message gives the full path from the Apple menu to System Settings → Privacy & Security → Automation and tells the user to expand Lock In and enable the browser. This handling is included in the installed build.

StartFocusIntent is available to Shortcuts on both platforms. An omitted duration uses the value saved in the app. The user will choose the system Focus mode later. No Focus automation has been configured.

iPhone focus uses a separate one-shot Device Activity schedule and reconciles its shield with existing cooldowns. Duration is 15–1440 minutes, because Device Activity requires a minimum 15-minute interval. Pause saves its state before stopping focus monitoring, keeping the shield active. Resume schedules an interval ending at the new deadline with the original duration, allowing the current interval to cover a remainder under 15 minutes. Schedule end components round up to a whole second so the expiry callback runs after the saved deadline. Mac duration is 1–1440 minutes. Mobile configuration requires Screen Time authorization and a selection. The shield displays the focus end time or paused state.

## Verification and deployment

- 2026-10-10: The attached menu screenshot exposed the hidden two-line footer's empty space. The offscreen native NSDatePicker measurement reproduced a 45-point bottom gap with a 24-point control height. After removing the footer, the bottom gap measures the ordinary 12-point outer padding. MenuSizingTests checks this distance from the last visible control, plus constant fitting height through focus start, pause, resume, expiry, errors, policy changes, invalid duration, and cooldown. Adding a long rule increases natural width and height; removing it restores both, and menuWillOpen matches the view frame to fittingSize. The preceding pause validation passed 12 iOS tests and the unsigned device build. Pause tests cover persistence, blocking after the original deadline, resuming with the same remaining time, and a short resumed iOS interval. Environment: Xcode 27, macOS 27, iPhone 17 simulator with iOS 27.
- swiftlint passed for the new focus views and intent. Periphery found no unused code in the SwiftPM index. SwiftFormat reported range-spacing and conditional-compilation indentation preferences; repository formatting was preserved.
- On 2026-10-24 all 37 Mac tests and 24 iOS tests passed. The unsigned physical-device build and signed simulator build succeeded. Tests cover downtime boundaries, daylight saving time, residual expiry after relaunch, daily quotas, configured warnings, duplicate and stale iOS events, concurrent shared-store writes, legacy persistence, and stable menu dimensions. SwiftLint passed for the shared policy, shared view, iOS model, schedule, storage, and monitor extension. SwiftFormat requests range spacing and multiline-body changes that differ from the repository's existing style; formatting was preserved. A fresh Periphery build found existing unused metadata and display fields; the unused blocking flags and stale-rule state in the touched flow were removed.
- Mac tests save a native menu render to /private/tmp/lockin-ui/macos.png. The actual signed iPhone 17 simulator screenshot is /private/tmp/lockin-ui/iphone.png. The simulator retains Downtime at 22:00–08:00; Screen Time access is not granted. Its App Group reads and writes work with Xcode's simulated entitlements. Physical-device shield enforcement and callback delivery remain unverified.
- /Applications/Lock In.app was replaced with the current build and restarted through script/build_and_run.sh --install. The user's website list and usage policy were preserved.
- Physical iPhone and iPad were unavailable. Screen Time enforcement on a physical device and Focus-triggered Shortcuts execution remain unverified. Xcode reported an SSU archive error after extracting valid intent metadata; both iOS builds completed successfully.
- The user requested cancellation of the running focus. focusUntil was cleared from the live state; the four website rules, 120 seconds of usage, and the existing session policy were preserved.
- The preceding Dia and focus changes are on origin/main. The current schedule and residual-reset work is local; do not infer a push from an installed app.

## Commands

Mac tests in the Codex sandbox:

```sh
swift test --disable-sandbox
```

Install and restart the Mac app, including its guardian and Shortcuts metadata:

```sh
./script/build_and_run.sh --install
```

The install command needs host access for /Applications, LaunchAgents, and process control. It preserves Library/Application Support/LockIn/state.json. For read-only macOS diagnostics denied by the sandbox, retry with explicit escalation.

Inspect this app's window classes at startup, with debugger access, then detach:

```sh
xcrun lldb --batch -n LockIn -o 'expr -l swift -- import AppKit' -o 'expr -l swift -- NSApplication.shared.windows.map { (String(describing: type(of: $0)), $0.identifier?.rawValue ?? "nil", $0.isVisible) }' -o 'detach'
```

iOS build and tests, with host access to CoreSimulator:

```sh
xcodebuild -project iOS/LockIn.xcodeproj -scheme LockIn -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/LockIn-iOS-device-build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project iOS/LockIn.xcodeproj -scheme LockIn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/LockIn-iOS-signed CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

The Mac build script extracts App Intents metadata from SwiftPM's compiler-generated StartFocusIntent.swiftconstvalues in .build. If the SwiftPM build layout changes, check that the installed Contents/Resources/Metadata.appintents/extract.actionsdata contains StartFocusIntent before claiming Shortcuts support.

For simulator UI work, use Xcode's simulator signing command above. CODE_SIGNING_ALLOWED=NO omits the simulated App Group entitlements, so the app can show “App Group is not available” despite a successful build. A manual codesign invocation is not equivalent to Xcode's simulated-entitlement processing. Wait until xcodebuild tests finish before opening the simulator UI; the test runner can shut down its destination during cleanup. T3 device_open plus its returned agent-device command is the current simulator control route. Native macOS computer use returned timeoutReached twice in this session; the menu image comes from the actual NSHostingView in MenuSizingTests with a system background.
