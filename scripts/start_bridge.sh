#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/build/First Vision Camera Bridge.app"
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CameraBridge</string>
<key>CFBundleIdentifier</key><string>com.example.FirstVisionCameraBridge</string>
<key>CFBundleName</key><string>First Vision Camera Bridge</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSCameraUsageDescription</key><string>Send live camera frames locally to the First Vision iOS simulator for Core ML object detection.</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
swiftc CameraBridge/main.swift -o "$APP/Contents/MacOS/CameraBridge" -framework Cocoa -framework AVFoundation -framework Network
codesign --force --sign - "$APP"
open "$APP"
