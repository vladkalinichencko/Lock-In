# Lock In

## Current state

Mac and iPhone have a focus duration field and a native Start focus button. During focus, all selected websites and apps are blocked until the saved absolute deadline. Focus blocks do not spend the normal usage allowance. Daily resets, existing breaks, and focus expiry preserve each other's restrictions. The Mac uses the original NSStatusItem and NSMenu with its original 280-point layout. Focus controls follow the existing field and button styles. The iPhone retains its original List and usage header.

## Standing correction

1. The user rejected "полностью поменял вообще весь дизайн" and requested "Верни точно дизайн, который был". Preserve the original system menu, background, dimensions, layout, and control styles from 41e837a. Requested features belong inside that layout; do not replace the presentation with a new window, grouped Form, or custom visual treatment.
2. The user rejected live menu resizing as "рамка в рамке" and requested a stable layout with reserved space for states. Use the original NSHostingView. The focus field and button stay in place; a countdown overlays the button label while focus disables both controls. Break and removal controls stay visible and become disabled. A two-line footer holds errors or break status. The rule list scrolls inside a viewport sized to the initial selection, keeping state changes and selection edits from moving the surrounding controls.

Dia URL reads and redirects use the focused tab in the front window's active profile, including pinned tabs. The installed Dia scripting dictionary exposes isFocused. Historical Lock In logs contained failed active-tab reads; the original rule matched youtube.com/shorts correctly. The focused-tab query returned the current URL in a live read-only check. Actual Shorts playback and redirect still need a user check; the regression test exercises matching, allowance consumption, and redirect through the controller.

StartFocusIntent is available to Shortcuts on both platforms. An omitted duration uses the value saved in the app. The user will choose the system Focus mode later. No Focus automation has been configured.

iPhone focus uses a separate one-shot Device Activity schedule and reconciles its shield with existing cooldowns. Duration is 15–1440 minutes, because Device Activity requires a minimum 15-minute interval. Mac duration is 1–1440 minutes. Mobile configuration requires Screen Time authorization and a selection. The shield displays the focus end time.

## Verification and deployment

- 2026-10-10: 23 Mac tests passed. MenuSizingTests checks that the actual fitting height stays constant across focus start/expiry, errors, policy changes, rule addition/removal, invalid duration, and cooldown, using an offscreen AppKit container. The shared focus control also compiles for iOS. The preceding iOS validation passed 10 tests on the iPhone 17 simulator with iOS 27 and the unsigned device build. Environment: Xcode 27, macOS 27.
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

iOS build and tests, with host access to CoreSimulator:

```sh
xcodebuild -project iOS/LockIn.xcodeproj -scheme LockIn -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/LockIn-iOS-device-build CODE_SIGNING_ALLOWED=NO build
xcodebuild -project iOS/LockIn.xcodeproj -scheme LockIn -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/LockIn-iOS-build CODE_SIGNING_ALLOWED=NO test
```

The Mac build script extracts App Intents metadata from SwiftPM's compiler-generated StartFocusIntent.swiftconstvalues in .build. If the SwiftPM build layout changes, check that the installed Contents/Resources/Metadata.appintents/extract.actionsdata contains StartFocusIntent before claiming Shortcuts support.
