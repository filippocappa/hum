#!/bin/bash
# Packages the release binary into a proper Hush.app agent bundle.
set -euo pipefail
cd "$(dirname "$0")"

APP="Hush.app"
swift build -c release

# Render the icon and pack it into an .icns.
swift Tools/make-icon.swift
iconutil -c icns build/Hush.iconset -o build/Hush.icns

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Hush "$APP/Contents/MacOS/Hush"
cp Sources/Hush/Resources/Info.plist "$APP/Contents/Info.plist"
cp build/Hush.icns "$APP/Contents/Resources/Hush.icns"

# Ad-hoc signature keeps Gatekeeper and the audio subsystem happy on Apple silicon.
codesign --force --sign - "$APP"

echo "Built $APP — run: open $APP   (install: mv $APP /Applications)"
