#!/bin/sh
# Builds an unsigned Release IPA for SideStore. SideStore signs it on install.
# Usage: scripts/build-ipa.sh [output directory]
set -eu
cd "$(dirname "$0")/.."
OUT="${1:-build}"

# The IPA name carries the commit; uncommitted changes would make it lie.
if [ -n "$(git status --porcelain)" ] && [ "${ALLOW_DIRTY:-0}" != "1" ]; then
  echo "Uncommitted changes: commit first, or run with ALLOW_DIRTY=1." >&2
  exit 1
fi

# What's New is keyed on the build number, so each build needs its own notes.
BUILD_NUMBER=$(sed -n 's/.*CURRENT_PROJECT_VERSION: "\([0-9]*\)".*/\1/p' project.yml | head -1)
if ! grep -q "ReleaseHighlights(build: $BUILD_NUMBER," App/Taima/Onboarding.swift; then
  echo "warning: no What's New entry for build $BUILD_NUMBER" >&2
fi
DERIVED="$(mktemp -d /tmp/taima-release.XXXXXX)"
trap 'rm -rf "$DERIVED"' EXIT

xcodegen generate --quiet
xcodebuild build -project Taima.xcodeproj -scheme Taima -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO \
  DEPLOYMENT_POSTPROCESSING=YES STRIP_INSTALLED_PRODUCT=YES STRIP_STYLE=non-global \
  STRIP_SWIFT_SYMBOLS=YES COPY_PHASE_STRIP=YES DEBUG_INFORMATION_FORMAT=dwarf-with-dsym -quiet

APP="$DERIVED/Build/Products/Release-iphoneos/Taima.app"
# An unsigned build carries no entitlements. Ad-hoc signing records the App
# Group, which SideStore reads and re-registers for its own Apple ID.
codesign --force --sign - --entitlements App/TaimaWidgets/TaimaWidgets.entitlements "$APP/PlugIns/TaimaWidgets.appex"
codesign --force --sign - --entitlements App/Taima/Taima.entitlements "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Info.plist")
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo local)
STAGE="$DERIVED/ipa"
mkdir -p "$STAGE/Payload" "$OUT"
cp -R "$APP" "$STAGE/Payload/"
IPA="$(cd "$OUT" && pwd)/Taima-$VERSION-$SHA.ipa"
# Debug symbols, to read crash reports from this build later.
DSYMS="$(cd "$OUT" && pwd)/Taima-$VERSION-$SHA.dSYMs.zip"
(cd "$DERIVED/Build/Products/Release-iphoneos" && zip -qry "$DSYMS" ./*.dSYM 2>/dev/null) || true
rm -f "$IPA"
(cd "$STAGE" && zip -qry "$IPA" Payload)

echo "Bundle ID: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
echo "Archs:     $(lipo -archs "$APP/Taima")"
if grep -rqa "$HOME" "$APP"; then echo "WARNING: home path embedded in the app"; fi
echo "IPA:       $IPA"
shasum -a 256 "$IPA"
