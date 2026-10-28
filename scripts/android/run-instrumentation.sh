#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
serial=${1:?Pass the serial of the owned device opened through T3}
adb="$HOME/Library/Android/sdk/platform-tools/adb"
# T3's booted state means ADB is available, not necessarily package-manager readiness.
if [[ $("$adb" -s "$serial" shell getprop sys.boot_completed | tr -d '\r') != 1 ]]; then
    echo 'Android is still booting; no APK install or instrumentation started.' >&2
    exit 75
fi
app=${2:-android/app/build/outputs/apk/debug/app-debug.apk}
tests=${3:-android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk}
"$adb" -s "$serial" install -r "$app"
"$adb" -s "$serial" install -r "$tests"
output=$(mktemp -t taima-trial-instrumentation)
trap 'test ! -f "$output" || unlink "$output"' EXIT
"$adb" -s "$serial" shell am instrument -w -r nl.taima.android.test/androidx.test.runner.AndroidJUnitRunner > "$output"
cat "$output"
"$adb" -s "$serial" logcat -d -s System.out:I | rg 'TAIMA_' || true
if rg -q 'FAILURES!!!|INSTRUMENTATION_FAILED|shortMsg=Process crashed' "$output" || ! rg -q 'INSTRUMENTATION_CODE: -1' "$output"; then
    exit 1
fi
