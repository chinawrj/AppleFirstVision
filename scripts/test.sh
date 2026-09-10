#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
mkdir -p artifacts
xcodebuild -project AppleFirstVision.xcodeproj -scheme AppleFirstVision -destination "platform=iOS Simulator,name=${SIMULATOR_NAME:-iPhone 17 Pro Max}" -derivedDataPath build/DerivedData -resultBundlePath "artifacts/Tests-$(date +%Y%m%d-%H%M%S).xcresult" test CODE_SIGNING_ALLOWED=NO
