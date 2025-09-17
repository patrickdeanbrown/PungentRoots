#!/bin/bash
set -euo pipefail

DEST="platform=iOS Simulator,OS=18.5,name=iPhone 16 Pro"

echo "Running tests on $DEST"
xcodebuild test -scheme PungentRoots -destination "$DEST"

# Ensure simulators are not left running to conserve resources
xcrun simctl shutdown all
