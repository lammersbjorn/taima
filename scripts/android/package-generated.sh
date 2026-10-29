#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
root=${TAIMA_GENERATED_SCRATCH:-/tmp/taima-trial-generated}
out=android/app/generated-jni/arm64-v8a
lib="$root/aarch64-unknown-linux-android28/release"
mkdir -p "$out"
cp "$lib/libTaimaGenerated.so" "$lib/libSwiftJava.so" "$out/"
"$HOME/Library/Android/sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-strip" --strip-unneeded "$out/libTaimaGenerated.so" "$out/libSwiftJava.so"
# Run after package-jni.sh so the SDK dependencies are present.
python3 scripts/android/prune-jni.py "$out"
