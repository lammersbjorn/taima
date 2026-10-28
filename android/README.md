# Taima Android trial

Standalone Kotlin/Compose app with synthetic evaluation evidence in
[the research note](../docs/research/android-trial.md). No CI, backend or release
publication is configured. The app runs the Kotlin implementation; Swift JNI
is an optional measurement build. Party is a sequential JSON content preview.
The new deck engine and flow remain owned by Swift on another branch.

## Build

Use JDK 21, user-space Android SDK, and the exact pins in `build.gradle.kts`.
Put `sdk.dir=<your SDK directory>` in ignored `local.properties` or set
`ANDROID_HOME`. Gradle uses two workers and a 2560 MB heap.

```sh
~/.t3/tools/saiko-load-gate/load-gate.sh && ./android/gradlew -p android :core:test :app:assembleDebug :app:assembleDebugAndroidTest
```

Repeat `:core:test --rerun-tasks -PtrialLocale=nl_NL`, `de_DE` and `en_US`
behind the gate to run the entire golden corpus in each JVM default locale.
Alternatively, `python3 scripts/android/run-jvm-contracts.py` reuses those compiled
classes with JUnitCore and a 512 MB heap without another build. All use Europe/Amsterdam, with the spring DST 23-hour day checked explicitly.
See `scripts/android/swift-build.sh` and `run-swift-tests.sh` for the portable
Swift SDK build and emulator test deployment. `TAIMA_REPO_ROOT` points only at
public resources and synthetic contracts on the device.

For app tests, `scripts/android/run-instrumentation.sh <owned-serial>` checks
`sys.boot_completed` before installing and running the synthetic instrumentation.
Use T3 device tools to boot/control the device and stop its recorded PID after use.

For handwritten JNI, build `scripts/android/swift-build.sh <aarch64|x86_64>
release`, then run `scripts/android/package-jni.sh <architecture>` and add
`-PwithSwift=true` to Gradle. `prune-jni.py` retains the ELF dependency closure,
including ICU; do not ship testing libraries just because they are in the SDK.

Generated JNI uses swift-java revision
`301e3da710ede7af93e798f1ce1c7950715a5748`. Its generated sources are committed;
`swiftjava/runtime` contains unmodified upstream Java loader sources under
Apache-2.0 with the upstream licence. The wildcard imports removed from the
generated Java file referred to unused generated packages. Build the dynamic
product as described in `swiftjava/README.md`, package it, then enable
`-PwithGenerated=true -PwithSwift=true` for the instrumentation comparison.

## Local signing

The local trial key is outside this repository at
`~/.local/share/taima/android-trial/release.jks`, alias `taima-trial`. Its password
is in the sibling `keystore-password` file (directory 0700, files 0600).
Keep both private and backed up together. Losing the key prevents in-place
updates under the same signing identity. No credential belongs in Gradle files,
logs, git, or chat. Set `TAIMA_KEYSTORE`, `TAIMA_STORE_PASSWORD` and
`TAIMA_KEY_PASSWORD` locally and build `:app:assembleRelease` behind the gate.
The default release omits native probes. Verify with SDK `apksigner verify
--verbose --print-certs <apk>`; this is a local trial identity, not a published
release signing commitment.

## Obtainium (documented, not installed or published)

[Obtainium upstream](https://github.com/ImranR98/Obtainium) supports GitHub release
APK sources. Once a maintainer separately publishes a signed APK, add the Taima
repository URL in Obtainium, select GitHub as the source, choose the release
channel, and filter assets to the intended APK (for example
`^taima-.*-release\.apk$`). Permit installs from this source in Android when
prompted. Ensure the package ID remains `nl.taima.android`, versionCode increases,
and all updates use the same signing certificate. Compare its fingerprint with
the maintainer's trusted value before first install. Do not use debug and release
builds interchangeably: their certificates differ. No Play Console is required.
There is no published trial release for Obtainium to install yet. Obtainium's
update checks and downloads contact GitHub; they do not need collection records.
SAF file destinations may themselves be cloud providers, at the user's choice.

## Scope and limitations

English and Dutch strings/plurals are in resources. Collection/detail/editor,
one bag in use, quick logging/session notes, basic totals, backup format 2 and
CSV are implemented. JSON preserves fields the editor does not expose. SQLite
stores JSON documents using BagStore's tables and migration 1 to 2; Android
photos use an auxiliary BLOB table. Room is a separate benchmark module, not
the production data path. OCR is a report, not an implemented permission or SDK.
Do not import a real collection to evaluate the trial. See the research note for
what was actually run and the remaining parity/security/phone acceptance gaps.
