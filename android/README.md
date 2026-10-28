# Taima for Android

Native Compose / Material 3 UI over the shared Swift core, through a versioned
JSON/JNI boundary. Minimum Android 9 (API 28), arm64 and x86_64. GPL-3.0.
No Play services, account, analytics, CI, paid service or publication step.

This branch is **not release validated**. See
[the acceptance record](../docs/evidence/android/README.md) for implemented paths,
known gaps and the load-gate refusals. The trial's older evidence is retained
under `docs/evidence/android-trial`; it is not evidence for this implementation.

## Build

Use the matching Swift 6.4.0 RELEASE toolchain, Swift Android SDK and NDK r28c
specified in [the trial](../docs/research/android-trial.md). JDK 21 and the user-space
Android SDK are expected. Gradle is pinned by the wrapper and restricted to two
workers with a 2560 MB heap. Every heavy build must pass the shared-host gate.

From a clean, committed checkout:

```sh
scripts/build-apk.sh
```

Output: `build/Taima-<project.yml version>.apk`, signed by the existing trial
identity. The script derives both version name and version code from project.yml,
builds both native ABIs, runs Kotlin contracts, builds and verifies the release.
It never pushes, uploads or creates a release. Exit 75 means capacity was denied.

Signing files, outside the repository:

- `~/.local/share/taima/android-trial/release.jks`, alias `taima-trial`.
- `~/.local/share/taima/android-trial/keystore-password`.

Back up both securely. Losing the key prevents existing installations from
accepting updates. Certificate SHA-256:
`d596a6ac7c1335cf62bd79d10c2a6b132bce27320ae65050eb608c52c27c3638`.
Optional overrides are `TAIMA_KEYSTORE` and `TAIMA_KEYSTORE_PASSWORD_FILE`.
No credentials should be added to Gradle files, logs, shell tracing or Git.

For development, build/package the Swift libraries before installing an APK:

```sh
scripts/android/swift-build.sh aarch64 release
scripts/android/package-jni.sh aarch64
~/.t3/tools/saiko-load-gate/load-gate.sh && \
  JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
  ANDROID_HOME="$HOME/Library/Android/sdk" \
  android/gradlew -p android :app:assembleDebug :core:test --max-workers=2
```

`app` always needs Swift. `core`, `storage-room` and `swiftjava` retain the trial's
comparison tests; Kotlin domain implementations are not app dependencies.
`ParityTest` is the mandatory on-device JNI/archive/plural contract suite.
`TrialTest` retains storage migration/rollback tests and comparison benchmarks.
Use the T3 Device tools for an owned emulator, only after the load gate passes.
Do not run another person's AVD, inspect their data or use broad process kills.

## Data and privacy

SQLite uses BagStore's explicit schema and JSON document bodies, with the trial's
version-1-to-2 wishlist migration. Core inventory rules also run for widget actions.
Swift performs backup/CSV import/export; SAF streams are staged in private cache
folders, then removed. Restore replaces rows and photo blobs in one transaction.
Android's system cloud backup is disabled. Exporting to a cloud SAF provider is
an explicit user choice. Daily encrypted backups use WorkManager; Android Keystore
wraps their local passphrase. Keep that passphrase separately to restore elsewhere.

OCR bundles English/Dutch Tesseract models and uses the system camera/photo
picker. There is no camera permission to grant to Taima. INTERNET exists only
for the explicit Settings catalogue-update action, downloading fixed public
files and verifying them in Swift. No launch-time network request occurs.

Photos preserve their bytes and use the format-2 archive's `.heic` filename
convention, including Android JPEG inputs. Platform rendering of these opaque
payloads must be checked on Android and iOS before release.

Android resource plurals own counts. Regenerate static core UI translations with
`scripts/android/sync-strings.py` after editing the maintained string catalogues.
English and Dutch per-app languages appear in Android's language settings.

## Distribution

Use Obtainium with source `https://github.com/lammersbjorn/taima` and APK filter
`^Taima-.*\.apk$`. Select the universal APK; keep the same application ID and key.
Prepare the shared iPhone/Android release without publishing:

```sh
scripts/release.py build/Taima-1.10-<sha>.ipa --apk build/Taima-1.10.apk
```

Review the printed command and notes before publishing yourself. Obtainium's
installation/update path remains a physical-device acceptance gate.
