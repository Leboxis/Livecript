#!/bin/bash
set -euo pipefail
DEVICE=$(xcrun simctl list devices available -j | python3 -c 'import sys,json; d=json.load(sys.stdin); print(next(v["udid"] for k,vs in d["devices"].items() if "iOS-26" in k for v in vs if "iPhone" in v["name"]))')
xcodebuild test -project Livecript.xcodeproj -scheme Livecript -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath build -resultBundlePath build/Tests.xcresult CODE_SIGNING_ALLOWED=NO
