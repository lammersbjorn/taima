#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
serial=${1:?Pass the owned emulator serial}
remote=/data/local/tmp/taima-trial-20261028
adb="$HOME/Library/Android/sdk/platform-tools/adb"
sdk="$HOME/Library/org.swift.swiftpm/swift-sdks/swift-6.4.0-RELEASE_android.artifactbundle/swift-android"
ndk="$HOME/Library/Android/sdk/ndk/28.2.13676358"
build="${TAIMA_ANDROID_SCRATCH:-/tmp/taima-trial-native}/aarch64-debug/aarch64-unknown-linux-android28/debug"
trap '"$adb" -s "$serial" shell rm -rf "$remote"' EXIT
status=0
"$adb" -s "$serial" shell mkdir -p "$remote/repo/App/Taima/Resources" "$remote/repo/contracts"
"$adb" -s "$serial" push "$build/TaimaCorePackageTests.xctest" "$remote/" >/dev/null
for bundle in "$build/"*.resources; do "$adb" -s "$serial" push "$bundle" "$remote/" >/dev/null; done
"$adb" -s "$serial" push "$sdk/swift-resources/usr/lib/swift-aarch64/android/"*.so "$remote/" >/dev/null
"$adb" -s "$serial" push "$ndk/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so" "$remote/" >/dev/null
for name in strains-curated.json strains.json growers.json; do "$adb" -s "$serial" push "App/Taima/Resources/$name" "$remote/repo/App/Taima/Resources/" >/dev/null; done
"$adb" -s "$serial" push contracts/golden "$remote/repo/contracts/" >/dev/null
"$adb" -s "$serial" shell "cd $remote && chmod 700 TaimaCorePackageTests.xctest && LD_LIBRARY_PATH=. TAIMA_REPO_ROOT=$remote/repo LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TZ=Europe/Amsterdam ./TaimaCorePackageTests.xctest --testing-library swift-testing" || status=1
for locale in nl_NL de_DE en_US; do
    "$adb" -s "$serial" shell "cd $remote && LD_LIBRARY_PATH=. TAIMA_REPO_ROOT=$remote/repo LANG=$locale.UTF-8 LC_ALL=$locale.UTF-8 TZ=Europe/Amsterdam ./TaimaCorePackageTests.xctest --testing-library swift-testing --filter ContractGoldenTests" || status=1
done
exit "$status"
