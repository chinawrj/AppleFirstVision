#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEVICE_ID:?Set DEVICE_ID to the iPhone UDID from xcrun xctrace list devices}"
: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your Apple developer Team ID}"
xcodegen generate
xcodebuild -project AppleFirstVision.xcodeproj -scheme AppleFirstVision \
  -destination "id=$DEVICE_ID" -derivedDataPath build/SignedDevice \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" build
xcrun devicectl device install app --device "$DEVICE_ID" build/SignedDevice/Build/Products/Debug-iphoneos/AppleFirstVision.app
xcrun devicectl device process launch --device "$DEVICE_ID" com.example.AppleFirstVision
