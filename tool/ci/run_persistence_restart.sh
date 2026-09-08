#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${IOS_E2E_SIMULATOR_UDID:?Use the disposable simulator created by run_ios_e2e.sh}"

flutter drive --keep-app-running --driver=test_driver/persistence_restart_driver.dart \
  --target=integration_test/ios_persistence_restart_test.dart \
  -d "$IOS_E2E_SIMULATOR_UDID" --dart-define=E2E_DISPOSABLE_SIMULATOR=true \
  --dart-define=E2E_RESTART_PHASE=write

python3 - "$IOS_E2E_SIMULATOR_UDID" <<'PY'
import json, subprocess, sys
sim = sys.argv[1]
devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))
if not any(d['udid'] == sim for group in devices['devices'].values() for d in group):
    raise SystemExit('Restart target is not an available simulator')
subprocess.run(['xcrun', 'simctl', 'terminate', sim, 'dev.mamy-r.kotrana'], capture_output=True)
processes = subprocess.check_output(['xcrun', 'simctl', 'spawn', sim, 'launchctl', 'list'], text=True)
for row in processes.splitlines():
    fields = row.split()
    if 'dev.mamy-r.kotrana' in row and fields and fields[0].isdigit() and int(fields[0]) > 0:
        raise SystemExit('App is still running; process restart was not established')
print('Confirmed Kotrana is stopped before the persistence read phase.')
PY

flutter drive --keep-app-running --driver=test_driver/persistence_restart_driver.dart \
  --target=integration_test/ios_persistence_restart_test.dart \
  -d "$IOS_E2E_SIMULATOR_UDID" --dart-define=E2E_DISPOSABLE_SIMULATOR=true \
  --dart-define=E2E_RESTART_PHASE=read
