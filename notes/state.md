# Lock In

## Current state

Mac and iPhone have a focus duration field, a native Start focus button, and a pause/resume button beside it. Pause freezes the countdown while all selected websites and apps remain blocked. focusPausedAt is persisted alongside focusUntil; resuming shifts the deadline by the paused duration. Focus blocks do not spend the normal usage allowance. Daily resets, existing breaks, and focus expiry preserve each other's restrictions. The Mac uses the original NSStatusItem and NSMenu, sized to the natural content dimensions before opening. Its status icon is hand.raised.fill when idle, timer during focus, and pause.circle on pause. Focus controls follow the existing field and button styles. The iPhone retains its original List and usage header.

## Standing correction

1. The user rejected "полностью поменял вообще весь дизайн" and requested "Верни точно дизайн, который был". Preserve the original system menu, background, layout, and control styles from 41e837a. Requested features belong inside that layout; do not replace the presentation with a new window, grouped Form, or custom visual treatment.
2. The user rejected live menu resizing as "рамка в рамке" and requested a stable layout with reserved space for states. Use the original NSHostingView. The focus field and button stay in place; a countdown overlays the button label while focus disables both controls. Break and removal controls stay visible and become disabled. A two-line footer holds errors or break status.
3. The user reported that the menu exceeded its content size and requested "не делай эти значения хардкоженными". MenuBarView uses fixedSize() to report its natural dimensions, including natural rule-list height. NSMenuDelegate.menuWillOpen fits the hosting view to that content before presentation. Focus transitions keep the same layout; rule-list edits are reflected in the menu's dimensions at the next opening.
4. Launch must create only the status-bar item. The Mac entry point runs NSApplication with its existing AppDelegate; SwiftUI is used only for menu content. An empty Settings scene creates a real settings window and has no role in this app. LLDB inspection of the preceding installed build found com_apple_SwiftUI_Settings_window among NSApplication.shared.windows. After installing 0c0dd57 and restarting, the window inventory contained only NSStatusBarWindow; the settings window was absent. All 25 Mac tests passed.

Dia URL reads and redirects use the focused tab in the front window's active profile, including pinned tabs. The installed Dia scripting dictionary exposes isFocused. Historical Lock In logs contained failed active-tab reads; the original rule matched youtube.com/shorts correctly. The focused-tab query returned the current URL in a live read-only check. Actual Shorts playback and redirect still need a user check; the regression test exercises matching, allowance consumption, and redirect through the controller.

StartFocusIntent is available to Shortcuts on both platforms. An omitted duration uses the value saved in the app. The user will choose the system Focus mode later. No Focus automation has been configured.

iPhone focus uses a separate one-shot Device Activity schedule and reconciles its shield with existing cooldowns. Duration is 15–1440 minutes, because Device Activity requires a minimum 15-minute interval. Pause saves its state before stopping focus monitoring, keeping the shield active. Resume schedules an interval ending at the new deadline with the original duration, allowing the current interval to cover a remainder under 15 minutes. Schedule end components round up to a whole second so the expiry callback runs after the saved deadline. Mac duration is 1–1440 minutes. Mobile configuration requires Screen Time authorization and a selection. The shield displays the focus end time or paused state.

## Verification and deployment

- 2026-10-10: 25 Mac tests passed after content-sizing changes; the preceding pause validation passed 12 iOS tests and the unsigned device build. Pause tests cover persistence, blocking after the original deadline, resuming with the same remaining time, and a short resumed iOS interval. MenuSizingTests checks constant fitting height through focus start, pause, resume, expiry, errors, policy changes, invalid duration, and cooldown. Adding a long rule increases natural width and height; removing it restores both, and menuWillOpen matches the view frame to fittingSize. These checks use an offscreen AppKit container and verify native status symbols. Environment: Xcode 27, macOS 27, iPhone 17 simulator with iOS 27.
- swiftlint passed for the new focus views and intent. Periphery found no unused code in the SwiftPM index. SwiftFormat reported range-spacing and conditional-compilation indentation preferences; repository formatting was preserved.
- /Applications/Lock In.app was replaced with the current build and restarted through script/build_and_run.sh --install. The user's website list and usage policy were preserved.
- Physical iPhone and iPad were unavailable. Screen Time enforcement on a physical device and Focus-triggered Shortcuts execution remain unverified. Xcode reported an SSU archive error after extracting valid intent metadata; both iOS builds completed successfully.
- The user requested cancellation of the running focus. focusUntil was cleared from the live state; the four website rules, 120 seconds of usage, and the existing session policy were preserved.
- Dia, focus, and the stable original-menu layout are committed and pushed to origin/main.

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
xcodebuild -project iOS/LockIn.xcodeproj -scheme LockIn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/LockIn-iOS-build CODE_SIGNING_ALLOWED=NO test
```

The Mac build script extracts App Intents metadata from SwiftPM's compiler-generated StartFocusIntent.swiftconstvalues in .build. If the SwiftPM build layout changes, check that the installed Contents/Resources/Metadata.appintents/extract.actionsdata contains StartFocusIntent before claiming Shortcuts support.
