#!/usr/bin/env bash

set -euo pipefail

FIREBASE_LOG="${FIREBASE_LOG:-/tmp/firebase-emulators.log}"
CHROMEDRIVER_LOG="${CHROMEDRIVER_LOG:-/tmp/chromedriver.log}"
FLUTTER_DRIVE_TIMEOUT="${FLUTTER_DRIVE_TIMEOUT:-600}"

find_chrome() {
  if [[ -n "${CHROME_EXECUTABLE:-}" && -x "$CHROME_EXECUTABLE" ]]; then
    printf '%s\n' "$CHROME_EXECUTABLE"
    return
  fi

  for candidate in \
    google-chrome \
    google-chrome-stable \
    chromium \
    chromium-browser \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return
    fi

    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  return 1
}

cleanup() {
  local exit_code=$?

  jobs -p | xargs -r kill 2>/dev/null || true
  wait 2>/dev/null || true
  pkill -f "cloud-firestore-emulator.*--project_id myappv4" 2>/dev/null || true

  if [[ $exit_code -ne 0 ]]; then
    echo
    echo "=== Firebase emulator log ==="
    tail -n 200 "$FIREBASE_LOG" 2>/dev/null || true
    echo
    echo "=== ChromeDriver log ==="
    tail -n 200 "$CHROMEDRIVER_LOG" 2>/dev/null || true
  fi

  exit "$exit_code"
}

trap cleanup EXIT

CHROME_EXECUTABLE="$(find_chrome)" || {
  echo "Google Chrome/Chromium was not found."
  echo "Install Chrome or set CHROME_EXECUTABLE to the browser binary path."
  exit 1
}
export CHROME_EXECUTABLE

echo "Chrome version:"
"$CHROME_EXECUTABLE" --version
echo "ChromeDriver version:"
chromedriver --version

echo "Starting Firebase emulators..."
firebase emulators:start --only auth,firestore --project myappv4 \
  >"$FIREBASE_LOG" 2>&1 &

for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:9099/ >/dev/null 2>&1 && \
     curl -fsS http://127.0.0.1:8081/ >/dev/null 2>&1; then
    echo "Firebase emulators ready"
    break
  fi

  if [[ $i -eq 30 ]]; then
    echo "Firebase emulators failed to start"
    exit 1
  fi

  echo "Waiting for emulators... ($i/30)"
  sleep 2
done

echo "Starting ChromeDriver..."
chromedriver --port=4444 --allowed-ips='' >"$CHROMEDRIVER_LOG" 2>&1 &

for i in $(seq 1 15); do
  if curl -fsS http://127.0.0.1:4444/status >/dev/null 2>&1; then
    echo "ChromeDriver ready"
    break
  fi

  if [[ $i -eq 15 ]]; then
    echo "ChromeDriver failed to start"
    exit 1
  fi

  echo "Waiting for ChromeDriver... ($i/15)"
  sleep 1
done

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d web-server \
  --timeout="$FLUTTER_DRIVE_TIMEOUT" \
  --browser-name=chrome \
  --web-browser-flag=--headless=new \
  --web-browser-flag=--disable-search-engine-choice-screen \
  --web-browser-flag=--disable-dev-shm-usage \
  --web-browser-flag=--no-sandbox \
  "$@"
