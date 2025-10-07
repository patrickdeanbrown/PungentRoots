#!/bin/bash
set -euo pipefail

# Allow overriding from the environment while defaulting to an available simulator.
DEST="${DEST:-platform=iOS Simulator,OS=18.6,name=iPhone 16 Pro}"

echo "Running tests on $DEST"
xcodebuild test -scheme PungentRoots -destination "$DEST"

# Ensure simulators are not left running to conserve resources
xcrun simctl shutdown all
