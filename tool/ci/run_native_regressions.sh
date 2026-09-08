#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
evidence="${NATIVE_REGRESSION_OUTPUT_DIR:-$PWD/build/implementation-evidence/native}"
mkdir -p "$evidence"
xcrun swift --version > "$evidence/swift-version.txt"
xcrun swift test --package-path ios --scratch-path "$evidence/swift-build" \
  2>&1 | tee "$evidence/swift-tests.log"
