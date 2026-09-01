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
codesign --force --sign - "$APP"

echo "Built $APP — run: open $APP   (install: mv $APP /Applications)"
