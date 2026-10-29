#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../Packages/TaimaCore"
arch=${1:-aarch64}
mode=${2:-debug}
swift_bin="$HOME/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift"
scratch="${TAIMA_ANDROID_SCRATCH:-../../build/android-native}/$arch-$mode"
if [[ "$mode" == debug ]]; then
    "$HOME/.t3/tools/saiko-load-gate/load-gate.sh" && /usr/bin/time -p "$swift_bin" build --build-tests --build-system native --swift-sdk "$arch-unknown-linux-android28" --scratch-path "$scratch" -j 2
else
    "$HOME/.t3/tools/saiko-load-gate/load-gate.sh" && /usr/bin/time -p "$swift_bin" build -c release --product TaimaBridge --build-system native --swift-sdk "$arch-unknown-linux-android28" --scratch-path "$scratch" -j 2
fi
