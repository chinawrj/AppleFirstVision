#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${SIMULATOR_ID:-}"
if [[ -z "$DEVICE" ]]; then
  DEVICE=$(xcrun simctl list devices available -j | python3 -c '
import json, os, sys
phones = [d for runtime, devices in json.load(sys.stdin)["devices"].items()
          if ".iOS-" in runtime for d in devices if d["name"].startswith("iPhone")]
preferred = os.environ.get("SIMULATOR_NAME", "iPhone 17 Pro Max")
selected = next((d for d in phones if d["name"] == preferred), phones[0] if phones else None)
if selected is None:
    sys.exit("No available iPhone simulator. Install an iOS runtime in Xcode.")
print(selected["udid"])
')
fi
xcodegen generate
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
xcodebuild -project AppleFirstVision.xcodeproj -scheme AppleFirstVision -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath build/DerivedData build CODE_SIGNING_ALLOWED=NO
xcrun simctl install "$DEVICE" build/DerivedData/Build/Products/Debug-iphonesimulator/AppleFirstVision.app
xcrun simctl launch "$DEVICE" com.example.AppleFirstVision
open -a Simulator
