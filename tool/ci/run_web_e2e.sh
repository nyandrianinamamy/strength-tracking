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

chrome_version() {
  "$1" --version | sed -E 's/.* ([0-9]+(\.[0-9]+){3}).*/\1/'
}

driver_major() {
  "$1" --version 2>/dev/null | sed -E 's/.* ([0-9]+)\..*/\1/'
}

chrome_for_testing_platform() {
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) printf '%s\n' "mac-arm64" ;;
    Darwin-x86_64) printf '%s\n' "mac-x64" ;;
    Linux-x86_64) printf '%s\n' "linux64" ;;
    *)
      echo "Unsupported ChromeDriver auto-download platform: $(uname -s)-$(uname -m)" >&2
      return 1
      ;;
  esac
}

download_matching_chromedriver() {
  local chrome_version="$1"
  local platform="$2"
  local cache_root="${CHROMEDRIVER_CACHE_DIR:-$PWD/.dart_tool/chromedriver}"
  local cache_dir="$cache_root/$chrome_version/$platform"
  local driver_bin="$cache_dir/chromedriver"
  local zip_path="$cache_dir/chromedriver.zip"
  local driver_url

  if [[ -x "$driver_bin" ]]; then
    printf '%s\n' "$driver_bin"
    return
  fi

  mkdir -p "$cache_dir"

  driver_url="$(
    CHROME_VERSION="$chrome_version" CHROMEDRIVER_PLATFORM="$platform" python3 - <<'PY'
import json
import os
import sys
import urllib.request

chrome_version = os.environ["CHROME_VERSION"]
platform = os.environ["CHROMEDRIVER_PLATFORM"]
major = chrome_version.split(".", 1)[0]
url = "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json"

with urllib.request.urlopen(url, timeout=30) as response:
    data = json.load(response)

matches = []
for entry in data["versions"]:
    version = entry["version"]
    if version == chrome_version or version.split(".", 1)[0] == major:
        for download in entry.get("downloads", {}).get("chromedriver", []):
            if download["platform"] == platform:
                matches.append((version == chrome_version, version, download["url"]))

if not matches:
    sys.exit(f"No ChromeDriver download found for Chrome {chrome_version} on {platform}")

matches.sort(key=lambda item: (item[0], item[1]), reverse=True)
print(matches[0][2])
PY
  )"

  curl -fsSL "$driver_url" -o "$zip_path"
  python3 - "$zip_path" "$cache_dir" <<'PY'
import os
import shutil
import sys
import zipfile

zip_path, cache_dir = sys.argv[1], sys.argv[2]
target = os.path.join(cache_dir, "chromedriver")

with zipfile.ZipFile(zip_path) as archive:
    driver_members = [
        member for member in archive.namelist()
        if member.endswith("/chromedriver") or member == "chromedriver"
    ]
    if not driver_members:
        raise SystemExit("Downloaded ChromeDriver archive did not contain chromedriver")
    with archive.open(driver_members[0]) as src, open(target, "wb") as dst:
        shutil.copyfileobj(src, dst)

os.chmod(target, 0o755)
PY

  printf '%s\n' "$driver_bin"
}

find_chromedriver() {
  local chrome_binary="$1"
  local version
  local chrome_major
  local existing_driver
  local existing_major
  local platform

  version="$(chrome_version "$chrome_binary")"
  chrome_major="${version%%.*}"

  if existing_driver="$(command -v chromedriver 2>/dev/null)"; then
    existing_major="$(driver_major "$existing_driver" || true)"
    if [[ "$existing_major" == "$chrome_major" ]]; then
      printf '%s\n' "$existing_driver"
      return
    fi
  fi

  platform="$(chrome_for_testing_platform)"
  download_matching_chromedriver "$version" "$platform"
}

cleanup() {
  local exit_code=$?
  local job_pids

  job_pids="$(jobs -p || true)"
  if [[ -n "$job_pids" ]]; then
    kill $job_pids 2>/dev/null || true
  fi
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

CHROMEDRIVER_EXECUTABLE="${CHROMEDRIVER_EXECUTABLE:-$(find_chromedriver "$CHROME_EXECUTABLE")}"

echo "Chrome version:"
"$CHROME_EXECUTABLE" --version
echo "ChromeDriver version:"
"$CHROMEDRIVER_EXECUTABLE" --version

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
"$CHROMEDRIVER_EXECUTABLE" --port=4444 --allowed-ips='' >"$CHROMEDRIVER_LOG" 2>&1 &

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
