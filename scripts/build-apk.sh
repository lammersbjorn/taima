#!/bin/bash
# Build a signed universal release locally. Never uploads or publishes.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "$(git status --porcelain)" ]]; then
    echo 'Commit or stash changes before building a release APK.' >&2
    exit 2
fi
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export TAIMA_KEYSTORE="${TAIMA_KEYSTORE:-$HOME/.local/share/taima/android-trial/release.jks}"
password_file="${TAIMA_KEYSTORE_PASSWORD_FILE:-$HOME/.local/share/taima/android-trial/keystore-password}"
[[ -f "$TAIMA_KEYSTORE" && -f "$password_file" ]] || { echo 'Local signing files are missing.' >&2; exit 2; }
export TAIMA_STORE_PASSWORD="$(cat "$password_file")"
export TAIMA_KEY_PASSWORD="$TAIMA_STORE_PASSWORD"
trap 'unset TAIMA_STORE_PASSWORD TAIMA_KEY_PASSWORD' EXIT
printf 'Signing key: %s\nBack up this keystore and its password. Losing them prevents updates.\n' "$TAIMA_KEYSTORE"
export TAIMA_ANDROID_SCRATCH="$PWD/build/android-native"
for arch in aarch64 x86_64; do
    scripts/android/swift-build.sh "$arch" release
    scripts/android/package-jni.sh "$arch"
done
"$HOME/.t3/tools/saiko-load-gate/load-gate.sh" && android/gradlew -p android clean :core:test :app:assembleRelease --max-workers=2
python3 scripts/android/run-jvm-contracts.py
version=$(python3 - <<'PY'
import re
print(re.search(r'MARKETING_VERSION: "([^"]+)"', open('project.yml').read())[1])
PY
)
mkdir -p build
output="build/Taima-$version.apk"
cp android/app/build/outputs/apk/release/app-release.apk "$output"
"$ANDROID_HOME/build-tools/36.0.0/apksigner" verify --verbose --print-certs "$output"
python3 - "$output" <<'PY'
import hashlib, pathlib, sys
p = pathlib.Path(sys.argv[1])
print(f'{p.resolve()}: {p.stat().st_size:,} bytes')
print('SHA-256:', hashlib.sha256(p.read_bytes()).hexdigest())
PY
