#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
arch=${1:-aarch64}
case "$arch" in aarch64) abi=arm64-v8a; resources=swift-aarch64; target=aarch64-linux-android28;; x86_64) abi=x86_64; resources=swift-x86_64; target=x86_64-linux-android28;; *) exit 2;; esac
sdk="$HOME/Library/org.swift.swiftpm/swift-sdks/swift-6.4.0-RELEASE_android.artifactbundle/swift-android"
ndk="$HOME/Library/Android/sdk/ndk/28.2.13676358"
bin="$ndk/toolchains/llvm/prebuilt/darwin-x86_64/bin"
lib="${TAIMA_ANDROID_SCRATCH:-/tmp/taima-trial-native}/$arch-release/$arch-unknown-linux-android28/release"
out="android/app/generated-jni/$abi"
mkdir -p "$out"
cp "$lib/libTaimaBridge.so" "$out/"
cp "$sdk/swift-resources/usr/lib/$resources/android/"*.so "$out/"
cp "$ndk/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/${target%28}/libc++_shared.so" "$out/"
"$bin/clang" --target="$target" --sysroot="$ndk/toolchains/llvm/prebuilt/darwin-x86_64/sysroot" -shared -fPIC android/bridge/taima_jni.c -L"$out" -lTaimaBridge -Wl,-rpath,'$ORIGIN' -o "$out/libtaimajni.so"
"$bin/llvm-strip" --strip-unneeded "$out/"*.so
wc -c "$out/libTaimaBridge.so"
