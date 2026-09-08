#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${IOS_E2E_SIMULATOR_UDID:?Use run_ios_e2e.sh to prepare the simulator}"
: "${IOS_E2E_OUTPUT_DIR:?Use run_ios_e2e.sh to prepare the output directory}"

with_auth=false
with_watch=false
ui_only=false
for argument in "$@"; do
  case "$argument" in
    --with-auth) with_auth=true ;;
    --paired-watch) with_watch=true ;;
    --ui-only) ui_only=true ;;
    *) echo "Unknown suite option: $argument" >&2; exit 2 ;;
  esac
done
if "$ui_only" && { "$with_auth" || "$with_watch"; }; then exit 2; fi
simulator="$IOS_E2E_SIMULATOR_UDID"
output_dir="$IOS_E2E_OUTPUT_DIR"
printf 'suite\tstatus\texit_code\n' > "$output_dir/results.tsv"

run_suite() {
  local suite_name="$1"
  local suite_started=$SECONDS
  local result=0
  shift
  if "$@" 2>&1 | tee "$output_dir/$suite_name.log"; then
    printf '%s\tPASS\t0\n' "$suite_name" | tee -a "$output_dir/results.tsv"
  else
    result=$?
    printf '%s\tFAIL\t%s\n' "$suite_name" "$result" | tee -a "$output_dir/results.tsv"
  fi
  local elapsed=$((SECONDS - suite_started))
  printf '%s\t%s\n' "$suite_name" "$elapsed" >> "$output_dir/timings.tsv"
  printf '%s completed in %s seconds\n' "$suite_name" "$elapsed"
  # Preserve evidence and stop before spending minutes building later suites.
  return "$result"
}

if "$ui_only"; then
  run_suite app-ui flutter test --no-pub integration_test/ios_app_test.dart \
    -d "$simulator" --dart-define=E2E_DISPOSABLE_SIMULATOR=true \
    --timeout 10m --reporter expanded
  exit 0
fi

if "$with_auth"; then
  run_suite firestore-rules dart run tool/verify_firestore_rules.dart
fi

run_suite phone-acceptance flutter test --no-pub integration_test/ios_acceptance_test.dart \
  -d "$simulator" --dart-define=E2E_DISPOSABLE_SIMULATOR=true \
  --dart-define=E2E_WITH_AUTH="$with_auth" --timeout 10m --reporter expanded

if "$with_watch"; then
  run_suite paired-watch flutter drive --no-pub --driver=test_driver/paired_watch_driver.dart \
    --target=integration_test/paired_watch_test.dart -d "$simulator" \
    --dart-define=E2E_DISPOSABLE_SIMULATOR=true \
    --dart-define=E2E_PHONE_SIMULATOR_UDID="$simulator"
fi

if "$with_auth"; then
  run_suite persistence-restart bash tool/ci/run_persistence_restart.sh
fi
