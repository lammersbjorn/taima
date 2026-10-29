#!/bin/bash
# Explicit local build acceptance. No CI, device boot, network upload or publication.
set -uo pipefail
cd "$(dirname "$0")/../.."
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
evidence="$PWD/build/android-verification"
mkdir -p "$evidence"
summary="$evidence/local-verification.txt"
printf 'Source: %s\nUTC: %s\n' "$(git rev-parse HEAD)" "$(date -u +%FT%TZ)" > "$summary"
gate="$HOME/.t3/tools/saiko-load-gate/load-gate.sh"
failed=0
run() {
    local name="$1"; shift
    local source
    source=$(git rev-parse HEAD)
    printf 'Starting %s at %s\n' "$name" "$source"
    printf '%s source=%s dirty=%s\n' "$name" "$source" "$(test -z "$(git status --porcelain)" && echo no || echo yes)" >> "$summary"
    "$@" > "$evidence/$name.log" 2>&1
    local result=$?
    printf '%s exit=%s\n' "$name" "$result" | tee -a "$summary"
    if [[ $result != 0 ]]; then failed=1; fi
    return "$result"
}
# Every heavy command is independently admitted. Exit 75 never executes its build.
run swift-test bash -c '"$1" && TAIMA_ANDROID_FIXTURES_DIR="$PWD/build/android-contracts" swift test --package-path Packages/TaimaCore --scratch-path build/core-tests -j 2' _ "$gate"
run ios-build bash -c '"$1" && xcodebuild -project Taima.xcodeproj -scheme Taima -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" -derivedDataPath build/android-ios-validation -jobs 2 CODE_SIGNING_ALLOWED=NO build' _ "$gate"
run kotlin-build bash -c '"$1" && android/gradlew -p android :core:test :app:assembleDebug :app:assembleDebugAndroidTest --max-workers=2 && python3 scripts/android/run-jvm-contracts.py' _ "$gate"
for arch in aarch64 x86_64; do
    if run "native-$arch" scripts/android/swift-build.sh "$arch" release; then
        run "package-$arch" scripts/android/package-jni.sh "$arch"
    fi
done
# Requires a committed clean checkout and repeats native/Kotlin checks behind their gates.
run apk-build scripts/build-apk.sh
exit "$failed"
