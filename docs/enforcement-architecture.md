# Serious Enforcement Architecture

The current Mac prototype uses browser Automation for Safari and Chromium-family
browsers, plus frontmost-application observation for selected Mac apps. It does
not install DNS resolvers, edit `/etc/hosts`, or run a DNS daemon.

That is the right implementation family for focused-tab timing, because browser
Automation can answer "what URL is the user actually looking at right now?"

## What Can Be Made Browser Agnostic

Blocking can be browser/app agnostic if the enforcement happens below the app:

- `NEFilterDataProvider` / `NEFilterControlProvider` content filter.
- `NEDNSProxyProvider` DNS proxy.
- A managed DNS or web content filter profile installed by MDM.

These see network traffic or name resolution regardless of whether the request
comes from Arc, Safari, Chrome, a native app, or a command-line tool.

## What Network Enforcement Cannot Know

Network traffic alone cannot reliably mean "the user is actively looking at the
site." Background tabs, prefetching, notifications, embedded media, and native
apps can all generate traffic while the user is focused somewhere else.

So there are two possible product semantics:

- Strict network budget: count matching network activity from any app.
- Focused-use budget: count only when a tracked browser/app is frontmost.

The first is app agnostic. The second is closer to the original request, and it
requires foreground-app observation plus per-browser integration.

## "Cannot Disable"

No app controlled by the same administrator user can honestly be impossible to
disable. An admin can kill processes, unload launch daemons, remove profiles,
boot to recovery, or change system settings.

The practical serious options are:

- Screen Time managed by a different Apple ID/passcode.
- A standard non-admin daily account, with another person holding admin access.
- MDM/supervision with a configuration profile that the daily user cannot remove.
- A signed Network Extension content filter with Apple entitlements.
- A root-owned LaunchDaemon/helper that relaunches the UI and enforcement helper.

The LaunchDaemon makes force-quitting the menu bar app insufficient, but it is
still removable by an administrator. MDM or a separate admin is what changes the
trust boundary.

## Current Build Direction

The menu bar app should be only the control surface:

- Add/remove sites.
- Show used minutes over the shared daily limit.
- Configure start of day.

The current enforcement loop should:

- Read the active tab URL from each supported browser once per second.
- Observe the frontmost Mac application and match it by bundle identifier.
- Count one shared allowance when the active URL matches any configured domain
  or subdomain, or when the frontmost app is selected.
- Redirect the active matching tab to the bundled block page after the allowance
  is used.
- Terminate a selected frontmost app after the allowance is used.
- Avoid VPN DNS interaction completely.

The iPhone and iPad targets use Family Controls, Device Activity, and Managed
Settings instead. These frameworks are unavailable to native macOS apps, so a
shared product can reuse policy semantics and persistence shapes, but enforcement
must remain behind platform-specific adapters.

A future harder enforcement process would be separate:

- Installed as a privileged helper or system extension.
- Reads a root-owned policy file.
- Applies Network Extension content filter rules.
- Refuses same-day policy weakening after usage has started.
- Resets policy mutability only at the configured start of day.
