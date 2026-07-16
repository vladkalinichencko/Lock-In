#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
EXECUTABLE_NAME="LockIn"
APP_DISPLAY_NAME="Lock In"
BUNDLE_ID="com.local.LockIn"
MIN_SYSTEM_VERSION="14.0"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_PACKAGE="$ROOT_DIR/Assets/AppIcon.icon"
ICON_NAME="AppIcon"
ACTOOL="/Applications/Xcode.app/Contents/Developer/usr/bin/actool"
DIST_DIR="${LOCKIN_DIST_DIR:-/private/tmp/LockInBuild}"
APP_BUNDLE="$DIST_DIR/$APP_DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$EXECUTABLE_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
GUARDIAN_LABEL="$BUNDLE_ID.guardian"
GUARDIAN_PLIST="$HOME/Library/LaunchAgents/$GUARDIAN_LABEL.plist"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/lockin-clang-cache}"
export SWIFTPM_CACHE_PATH="${SWIFTPM_CACHE_PATH:-/private/tmp/lockin-swiftpm-cache}"

stop_running_app() {
  launchctl bootout "gui/$(id -u)" "$GUARDIAN_PLIST" >/dev/null 2>&1 || true
  pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true
  pkill -x "LockInGuardian" >/dev/null 2>&1 || true
}

stop_running_app

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$EXECUTABLE_NAME"
GUARDIAN_BINARY="$(swift build --show-bin-path)/LockInGuardian"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$GUARDIAN_BINARY" "$APP_MACOS/LockInGuardian"
chmod +x "$APP_BINARY"
chmod +x "$APP_MACOS/LockInGuardian"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_NAME</string>
  <key>CFBundleIconName</key>
  <string>$ICON_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundleName</key>
  <string>$APP_DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Lock In reads the active browser tab URL to count focused time on blocked websites.</string>
</dict>
</plist>
PLIST

if [ ! -d "$ICON_PACKAGE" ]; then
  echo "error: missing icon package: $ICON_PACKAGE" >&2
  exit 1
fi

if [ ! -x "$ACTOOL" ]; then
  echo "error: missing actool: $ACTOOL" >&2
  exit 1
fi

ACTOOL_TMP="$(mktemp -d)"
"$ACTOOL" "$ICON_PACKAGE" \
  --app-icon "$ICON_NAME" \
  --compile "$ACTOOL_TMP" \
  --output-partial-info-plist "$ACTOOL_TMP/actool_info.plist" \
  --minimum-deployment-target "$MIN_SYSTEM_VERSION" \
  --platform macosx \
  --target-device mac >/dev/null
cp "$ACTOOL_TMP/$ICON_NAME.icns" "$APP_RESOURCES/$ICON_NAME.icns"
cp "$ACTOOL_TMP/Assets.car" "$APP_RESOURCES/Assets.car"
rm -rf "$ACTOOL_TMP"

write_block_page() {
  local path="$1"
  local message="$2"
  cat >"$path" <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Blocked</title>
  <style>
    html, body {
      height: 100%;
      margin: 0;
      font: 16px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      color: #1d1d1f;
      background: #f5f5f7;
      color-scheme: light dark;
    }
    @media (prefers-color-scheme: dark) {
      html, body {
        color: #f5f5f7;
        background: #1c1c1e;
      }
    }
    body {
      display: grid;
      place-items: center;
    }
    main {
      max-width: 420px;
      padding: 32px;
      text-align: center;
    }
    h1 {
      margin: 0 0 10px;
      font-size: 24px;
      font-weight: 650;
    }
    p {
      margin: 0;
      color: #6e6e73;
      line-height: 1.45;
    }
  </style>
</head>
<body>
  <main>
    <h1>$message</h1>
  </main>
</body>
</html>
HTML
}

write_block_page "$APP_RESOURCES/blocked-until-break-ends.html" "Blocked until the break ends."
write_block_page "$APP_RESOURCES/blocked-until-next-day.html" "Blocked until your next day."

/usr/bin/xattr -cr "$APP_BUNDLE"
/usr/bin/xattr -d com.apple.FinderInfo "$APP_BUNDLE" >/dev/null 2>&1 || true
/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"

INSTALLED_APP="/Applications/$APP_DISPLAY_NAME.app"
OLD_APP="/Applications/LockIn.app"

install_app() {
  stop_running_app
  rm -rf "$INSTALLED_APP"
  cp -R "$APP_BUNDLE" "$INSTALLED_APP"
  /usr/bin/xattr -cr "$INSTALLED_APP"
  rm -rf "$OLD_APP"
  stop_running_app
}

open_app() {
  /usr/bin/open "${1:-$APP_BUNDLE}"
}

case "$MODE" in
  --stage|stage)
    ;;
  run)
    open_app
    ;;
  --install|install)
    install_app
    open_app "$INSTALLED_APP"
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$EXECUTABLE_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$EXECUTABLE_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--install|--stage|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
