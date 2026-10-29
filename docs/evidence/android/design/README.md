# Android design evidence, 29 October 2026

Base: `e5a7c2bf69cb4bd0595ad3209b4fb6edc4ea4703` (`t3/android-verify`).
Application source: `b33b9be` on `t3/android-design`. Evidence-only commits follow it. No push, merge, publication or CI changes.

## Screens

- Collection: photo thumbnails, name and grower, neutral amount/THC chips and stock words. Sort, product, stock, grouping and comparison moved into the top-bar sheet. The green FAB opens manual add, scan, photos and paired photos.
- Stash: active item card, remaining ring, quick quantities, full logging action, weekly summary and recent use. Figures stack at large text sizes.
- Stats: collection figures, responsive icon tiles, monthly bars, grower bars, THC distribution and session-method bars. Charts use neutral marks and expose their values as text, without network access. Additional totals and existing insights remain below the charts.
- Library: neutral search, quiet search guidance, leading book icons and native local results.
- More: grouped rows, leading icon tiles, supporting text and chevrons.
- Party: full-screen deck-kind colour, white content, scrolling card and persistent Next action; secrets and timers remain available.
- Shared: explicit Material colour roles, opaque white/near-black cells, neutral raised surfaces, tabular figures, large titles, quiet empty states, and neutral text/outlined actions. Selection uses white icons on green. Bottom labels are single-line and become labelled icons at font scale 1.5 and above. Dutch uses Collectie, Voorraad, Stats, Bieb and Meer.

`screens/` holds five main screens plus the party deck for each combination of English/Dutch, light/dark and font scale 1.0/2.0. English normal-size captures also include recent use and chart details. `contact-*.png` summarizes each variant. `before-after.png` compares the retained English light normal screenshots with the new signed-release captures. The old and new evidence use different synthetic fixtures and device dimensions; the contact sheet preserves image aspect ratios.

Data is synthetic: eight items across bag, jar, preroll, hash, rosin and edible forms; several growers, sessions and an active bag. Thumbnails are locally drawn synthetic package labels. `DesignFixtureTest` is test-only and requires an explicit opt-in argument. Public bundled catalogue search is offline. No collection was uploaded.

## Verification

- `kotlin-tests.log`: Kotlin compilation and 7 core tests passed.
- `swift-tests.log`: 219 Swift tests passed, including contract fixtures. No Swift production source changed.
- `jvm-contracts.log`: 7 contract tests passed independently under nl_NL, de_DE and en_US, Europe/Amsterdam.
- `debug-build.log`: final debug application and instrumentation APK compilation passed.
- `instrumentation.log`: 10 existing Android instrumentation checks passed, including mandatory JNI/archive/decimal/plural contracts and storage tests. The fixture test is deliberately skipped without its opt-in argument; the runner reports 11 tests including that assumption skip. The native comparison probe remains optional in the retained suite.
- `seed.log`: the explicit synthetic fixture test passed separately.
- `release-build.log`: signed, minified arm64 release build, release lint, Kotlin tests and JVM contracts passed. All Swift and Gradle invocations used the load gate. Gradle used two workers and a 2560 MB heap. No capacity denial occurred.
- `release-install.log`: the signed release installed over the locally re-signed debug build without deleting the synthetic database. All final screenshots use the signed release, not the debug build.
- `*-normal.log` and `*-max2.0.log`: device actions and font-setting readback. The agent-device categories large and accessibility-extra-large read back as Android 1.0 and 2.0 respectively.

Accessibility is supported by scalable text, 48 dp Material touch targets, full destination descriptions when labels hide, meaningful merged item rows, chart text alternatives, and decorative icons omitted from spoken content. Snapshot labels were inspected. `capture-matrix.py` accepts the exact T3 `device_open` command through `TAIMA_DEVICE_COMMAND` and an evidence directory through `TAIMA_DESIGN_EVIDENCE`. A spoken TalkBack focus walkthrough was not performed; screenshots do not prove spoken output.

## APK and native dependencies

Final artifact: `build/Taima-1.10.apk` in this worktree (retained locally, ignored by Git).

- Size: **41,093,284 bytes** (41.09 MB / 39.19 MiB).
- Before: 71,385,534 bytes. Reduction: **42.43%**.
- SHA-256: `fe42bfdea2ca543005fd6d0ef4fd044f6fa75ecb990450bc063a1a41b65b3f42`.
- APK native ABIs: **arm64-v8a only**, confirmed from ZIP entries. Debug still permits arm64-v8a and x86_64. Both native variants were freshly built and packaged; instrumentation ran on the arm64 emulator. For an x86_64 emulator, build/package that variant with `scripts/android/swift-build.sh x86_64 release` and `scripts/android/package-jni.sh x86_64` before the gated debug Gradle build.
- Signer certificate SHA-256: `d596a6ac7c1335cf62bd79d10c2a6b132bce27320ae65050eb608c52c27c3638`.

FoundationICU was retained. `icu-dependencies.txt` records `libFoundationInternationalization.so` directly requiring `lib_FoundationICU.so`. The latter is 40,042,536 bytes uncompressed, 15,679,887 bytes in the APK. Removing it from this dependency closure would break loading rather than safely reduce size. Date and decimal behaviour was kept and covered by the contracts.

## Ownership and cleanup

The 48 required captures and 10 additional detail/control captures are retained. The add menu and filter sheet were also opened at Dutch dark 2.0. Some pre-existing party-kind headings, such as “Everyone”, still fall back to English; prompts and control labels follow Dutch.

Only the disposable `Taima_Design_1c6f6fbe` emulator was used. Its PID was recorded as 1270. Cleanup status and exact source/APK provenance are in `run.json`. The pre-existing branch tip was preserved as `t3/android-design-before-20261029` before starting from the requested verified base. Signing credentials stayed outside Git and were never printed. Shared Gradle/SDK caches and other devices were not removed.
