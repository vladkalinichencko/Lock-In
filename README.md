# Lock In

<p align="center">
  <img src="Assets/AppIcon.icon/Assets/Vector.svg" alt="Lock In hand icon" width="52">
</p>

I built this for the moment when one quick visit or one episode turns into a
session I did not choose. Lock In tracks focused time on the websites and Mac
apps you select, then blocks them when that session is over. The same session,
break, and daily-reset model is also available on iPhone and iPad. On Mac, its
controls live in the standard menu opened from the menu bar icon.

```mermaid
flowchart LR
    A[Focused supported browser tab or Mac app] --> B{Matches a rule?}
    B -->|no| C[Do not count time]
    B -->|yes| D[Count active seconds]
    D --> E{Session complete?}
    E -->|no| D
    E -->|yes| F[Redirect the tab or close the app]
    F --> G[Break or next-day reset]
```

## How it works

Add domains and installed applications, then choose the session length, number of sessions, break length, and daily reset time. Only a focused matching tab or frontmost selected app adds time. Choose how many minutes before the limit to receive a warning, or set it to zero to turn the warning off. At the limit, Lock In redirects matching tabs and closes selected Mac apps.

Sessions can have breaks between them. If you leave a selected site or app during the warning window and stay away for a full break, Lock In discards the remaining allowance and completes that session. The next visit gets a full session if one remains. The final session stays blocked until the daily reset. iPhone usage updates arrive in whole minutes, so residual resets include one extra minute before they take effect.

Downtime blocks all selected sites and apps during a daily time range, including overnight. It has its own start and end times. A daily reset or the end of a focus session keeps downtime in effect until its scheduled end.

## Things to expect

The Mac app reads and redirects browser tabs through AppleScript Automation.
macOS will ask for permission for each browser. Supported browsers are Safari,
Google Chrome, Arc, Dia, Brave, Microsoft Edge, Vivaldi, Opera, and Chromium.
Firefox does not expose its active tab URL through AppleScript, so it is not in
the focused-tab list. Lock In does not alter DNS, `/etc/hosts`, or a VPN.

App blocking on Mac uses normal workspace/process APIs, including for system
apps such as TV. It works in the current ad-hoc-signed build and needs no Screen
Time entitlement, but an administrator can still quit or remove the blocker.

On iPhone and iPad, app and website selection uses Apple's Family Controls,
Device Activity, and Managed Settings frameworks. Those APIs require the Family
Controls entitlement and a provisioning profile signed by an Apple Developer
team; an unsigned device build cannot enforce Screen Time restrictions. Apple
does not make those frameworks available to native macOS apps, so the platform
UIs and enforcement adapters remain separate even though they follow the same
policy model.

This is a commitment aid, not an unbreakable restriction for the same Mac
administrator who installed it. The source includes notes on the stronger
managed and system-level approaches in `docs/enforcement-architecture.md`.

## Install and run

The Mac app requires macOS 14 or newer and Xcode command-line tools.

```sh
git clone https://github.com/vladkalinichencko/Lock-In.git
cd 'Lock In'
./script/build_and_run.sh --install
```

The build creates the menu bar app and its guardian, then installs and launches
the app. Build and test without installing it with:

```sh
swift build
swift test
```

## Status

This is a source-available prototype while I test the idea in real life. It has
no license grant yet, and a future product version may use different terms.
