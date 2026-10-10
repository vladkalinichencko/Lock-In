# Lock In

## Current state

Mac and iPhone have a focus duration field and a native Start focus button. During focus, all selected websites and apps are blocked until the saved absolute deadline. Focus blocks do not spend the normal usage allowance. Daily resets, existing breaks, and focus expiry preserve each other's restrictions. The Mac uses a SwiftUI MenuBarExtra window and a grouped Form; both platforms use the shared FocusView.

Dia URL reads and redirects use the focused tab in the front window's active profile, including pinned tabs. The installed Dia scripting dictionary exposes isFocused. Historical Lock In logs contained failed active-tab reads; the original rule matched youtube.com/shorts correctly. The focused-tab query returned the current URL in a live read-only check. Actual Shorts playback and redirect still need a user check; the regression test exercises matching, allowance consumption, and redirect through the controller.

StartFocusIntent is available to Shortcuts on both platforms. An omitted duration uses the value saved in the app. The user will choose the system Focus mode later. No Focus automation has been configured.

iPhone focus uses a separate one-shot Device Activity schedule and reconciles its shield with existing cooldowns. Duration is 15–1440 minutes, because Device Activity requires a minimum 15-minute interval. Mac duration is 1–1440 minutes. Mobile configuration requires Screen Time authorization and a selection. The shield displays the focus end time.

## Verification and deployment

- 2026-10-10: 22 Mac tests and 10 iOS tests passed with Xcode 27, macOS 27, and the iPhone 17 simulator on iOS 27. The unsigned iOS device build also succeeded.
- swiftlint passed for the new focus views and intent. Periphery found no unused code in the SwiftPM index. SwiftFormat reported range-spacing and conditional-compilation indentation preferences; repository formatting was preserved.
- /Applications/Lock In.app was replaced with the current build and restarted through script/build_and_run.sh --install. The user's website list and usage policy were preserved.
- Physical iPhone and iPad were unavailable. Screen Time enforcement on a physical device and Focus-triggered Shortcuts execution remain unverified. Xcode reported an SSU archive error after extracting valid intent metadata; both iOS builds completed successfully.
- Commits f05b6bb and 6f4e3ad were pushed to origin/main.

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
