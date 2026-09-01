#!/bin/bash
# Packages the release binary into a proper Hum.app agent bundle.
set -euo pipefail
cd "$(dirname "$0")"

APP="Hum.app"
swift build -c release

# Render the icon and pack it into an .icns.
swift Tools/make-icon.swift
iconutil -c icns build/Hum.iconset -o build/Hum.icns

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Hum "$APP/Contents/MacOS/Hum"
cp Sources/Hum/Resources/Info.plist "$APP/Contents/Info.plist"
cp build/Hum.icns "$APP/Contents/Resources/Hum.icns"

# Ad-hoc signature keeps Gatekeeper and the audio subsystem happy on Apple silicon.
codesign --force --deep --sign - "$APP"

# An ad-hoc signature produces a new cdhash on every build, and TCC keys
# Accessibility trust on that hash. macOS therefore silently invalidates the
# grant while still listing a stale, apparently-enabled entry in System
# Settings — the shortcut looks permitted but never fires. Clearing the entry
# forces a clean prompt against the newly signed binary.
# Set HUM_KEEP_TCC=1 to skip when you know the signature has not changed.
if [ "${HUM_KEEP_TCC:-0}" != "1" ]; then
  tccutil reset Accessibility com.local.Hum >/dev/null 2>&1 || true
  echo "Reset Accessibility trust — re-grant it on next launch."
fi

echo "Built $APP — run: open $APP   (install: mv $APP /Applications)"
