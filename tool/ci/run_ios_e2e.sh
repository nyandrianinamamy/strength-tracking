#!/usr/bin/env bash
set -euo pipefail
run_started=$SECONDS

# macOS/Xcode and the repo's Flutter dependencies must already be installed.
# Default: fresh iPhone simulator, always deleted on exit. An explicit UDID is
# permitted only if simctl confirms it is an existing simulator; it is retained.
cd "$(dirname "$0")/../.."
with_auth=false
with_watch=false
ui_only=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-auth) with_auth=true ;;
    --paired-watch) with_watch=true ;;
    --ui-only) ui_only=true ;;
    *)
      echo 'Usage: tool/ci/run_ios_e2e.sh [--with-auth] [--paired-watch] [--ui-only]' >&2
      exit 2 ;;
  esac
  shift
done
if "$ui_only" && { "$with_auth" || "$with_watch"; }; then
  echo '--ui-only cannot be combined with --with-auth or --paired-watch' >&2
  exit 2
fi
command -v flutter >/dev/null
command -v xcrun >/dev/null
command -v python3 >/dev/null
if "$with_auth"; then command -v firebase >/dev/null; fi

output_dir="${IOS_E2E_OUTPUT_DIR:-$PWD/build/ios-e2e}"
mkdir -p "$output_dir"
simulator=''
simulator_manifest="$(mktemp "$output_dir/owned-simulators.XXXXXX")"
plist_backup=''
cleanup() {
  if [[ -n "$plist_backup" ]]; then
    cp "$plist_backup" ios/Runner/GoogleService-Info.plist
    rm -f "$plist_backup"
  fi
  if [[ -s "$simulator_manifest" ]]; then
    python3 tool/ci/prepare_simulators.py --cleanup "$simulator_manifest"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# firebase_core configures the bundled default app before Dart starts. Use a
# demo plist for all test builds, and restore the source exactly even on failure.
plist_backup="$(mktemp -t kotrana-e2e-plist)"
cp ios/Runner/GoogleService-Info.plist "$plist_backup"
cp tool/ci/firebase.e2e.plist ios/Runner/GoogleService-Info.plist

prepare_args=(--output "$simulator_manifest")
if "$with_watch"; then prepare_args+=(--paired-watch); fi
python3 tool/ci/prepare_simulators.py "${prepare_args[@]}"
simulator="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["phone"])' "$simulator_manifest")"
export IOS_E2E_SIMULATOR_UDID="$simulator"
export PAIRED_WATCH_OUTPUT_DIR="$output_dir/paired-watch"
if "$with_watch"; then
  export WATCH_SIMULATOR_UDID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["watch"])' "$simulator_manifest")"
fi

printf 'iOS E2E simulator: %s\n' "$simulator"
xcrun simctl boot "$simulator" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$simulator" -b
if "$with_watch"; then
  xcrun simctl boot "$WATCH_SIMULATOR_UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$WATCH_SIMULATOR_UDID" -b
fi
flutter --version > "$output_dir/flutter-version.txt"
xcodebuild -version > "$output_dir/xcode-version.txt"
git rev-parse HEAD > "$output_dir/source-commit.txt"
git status --short > "$output_dir/source-status.txt"
python3 - "$output_dir/source-files.sha256.json" <<'PYSOURCE'
import hashlib, json, pathlib, subprocess, sys
names = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard']).decode().split('\0')
manifest = {}
for name in sorted(set(names) - {''}):
    path = pathlib.Path(name)
    manifest[name] = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
pathlib.Path(sys.argv[1]).write_text(json.dumps(manifest, indent=2) + '\n')
PYSOURCE
xcrun simctl list devices --json > "$output_dir/simulators.json"

suite_failed=0
printf 'suite\tstatus\texit_code\n' > "$output_dir/results.tsv"
printf 'suite\telapsed_seconds\nsetup\t%s\n' "$((SECONDS - run_started))" > "$output_dir/timings.tsv"
run_suite() {
  local suite_name="$1"
  local suite_started=$SECONDS
  shift
  if "$@" 2>&1 | tee "$output_dir/$suite_name.log"; then
    printf '%s\tPASS\t0\n' "$suite_name" | tee -a "$output_dir/results.tsv"
  else
    local result=$?
    printf '%s\tFAIL\t%s\n' "$suite_name" "$result" | tee -a "$output_dir/results.tsv"
    suite_failed=1
  fi
  local elapsed=$((SECONDS - suite_started))
  printf '%s\t%s\n' "$suite_name" "$elapsed" >> "$output_dir/timings.tsv"
  printf '%s completed in %s seconds\n' "$suite_name" "$elapsed"
}

run_suite app-ui flutter test integration_test/ios_app_test.dart \
  -d "$simulator" --dart-define=E2E_DISPOSABLE_SIMULATOR=true \
  --timeout 10m --reporter expanded
if "$ui_only"; then exit "$suite_failed"; fi

run_suite native-wiring flutter test integration_test/native_runtime_wiring_test.dart \
  -d "$simulator" --timeout 5m --reporter expanded

if "$with_watch"; then
  # Flutter reinstalls the phone app; the host driver installs its companion
  # after that step, when the phone has reached the preparation checkpoint.
  run_suite paired-watch flutter drive --driver=test_driver/paired_watch_driver.dart \
    --target=integration_test/paired_watch_test.dart -d "$simulator" \
    --dart-define=E2E_DISPOSABLE_SIMULATOR=true \
    --dart-define=E2E_PHONE_SIMULATOR_UDID="$simulator"
fi

if "$with_auth"; then
  # simctl UDIDs have a constrained form, so this is safe to pass as the
  # emulators:exec command. The Firebase project can never resolve to production.
  python3 - "$PWD/firestore.rules" "$output_dir/firebase-emulators.json" <<'PYCONFIG'
import json, sys
with open(sys.argv[2], "w") as stream:
    json.dump({"firestore": {"rules": sys.argv[1]}, "emulators": {
        "auth": {"port": 19099}, "firestore": {"port": 18081},
        "ui": {"enabled": False}, "singleProjectMode": True}}, stream)
PYCONFIG
  export FIREBASE_EMULATOR_PROJECT=demo-kotrana-e2e
  export FIREBASE_AUTH_EMULATOR_PORT=19099
  export FIRESTORE_EMULATOR_PORT=18081
  run_suite firestore-rules firebase emulators:exec --config "$output_dir/firebase-emulators.json" \
    --project demo-kotrana-e2e --only auth,firestore \
    "dart run tool/verify_firestore_rules.dart"
  run_suite invite-auth firebase emulators:exec --config "$output_dir/firebase-emulators.json" \
    --project demo-kotrana-e2e --only auth,firestore \
    "flutter test integration_test/ios_invite_auth_test.dart -d $simulator --dart-define=E2E_DISPOSABLE_SIMULATOR=true --timeout 10m --reporter expanded"
  run_suite startup firebase emulators:exec --config "$output_dir/firebase-emulators.json" \
    --project demo-kotrana-e2e --only auth,firestore \
    "flutter test integration_test/ios_startup_test.dart -d $simulator --dart-define=E2E_DISPOSABLE_SIMULATOR=true --timeout 10m --reporter expanded"
  run_suite persistence-restart firebase emulators:exec --config "$output_dir/firebase-emulators.json" \
    --project demo-kotrana-e2e --only auth,firestore \
    "bash tool/ci/run_persistence_restart.sh"
fi

exit "$suite_failed"
