# Android implementation acceptance record

2026-10-29. Synthetic data only. Local `t3/android-ready`; no push, CI or publication.
Merged main `841745c` (1.10) with Android branch `fc0e304` as `6aad312`.
Latest implementation: `74e3799ebdc8c4686f59a246e48c88ee8b099f25`. The frozen native-build
source is `3931f9994deed78afdbcab1451c2b584fa3ebba6`; its complete TaimaCore
package tree is unchanged in the latest implementation.
Later acceptance/documentation commits do not imply another build.

**Not release-ready.** Source additions, compilation, JVM tests, JNI execution,
visual/accessibility acceptance and signed distribution are separate claims.

## Source added in this continuation

| Area | Implementation |
| --- | --- |
| 1.10 core/model | Main owns the item and party rules. Rosin, edible pieces, THC per piece, fitting methods, fitting roulette ways, stage/kind spacing and seen cards are preserved. The written party deck remains main's unchanged 326-card file. Explicit Character serialization for PartySpin is retained. |
| Editor/stash | Edible piece/THC fields, Ate half/Ate one, fitting method chips including dab, edible-safe widget, collection date editing, local calendar days, potency range/upper-bound/basis fields. |
| Live scanner | Optional CameraX permission, lifecycle-bound preview and one backpressure-limited analyzer, rotated frames, bundled English/Dutch Tesseract and ZXing barcodes. At most 24 readings enter Swift fusion. The frame with the most detected fields is retained, scanning pauses for review, and a fresh-item reset clears prior readings. |
| Photos/back OCR | Front/back/flower choices, cover selection/removal including unsaved photos, orientation-aware bounded decoding. Back OCR fills missing fields, retains the front/typed values and separate back text, and rejects stale results after concurrent edits. |
| Sessions/notes | Edit time/method/mood/tobacco/note while Swift preserves session amount and identity. Timed-note photo attachment/deletion. Orphan photo pruning after saved mutations. Notes/details are reachable from Stash. Stale editor saves fail inside the writer transaction before adding photos or replacing a row; the UI refreshes saved state on conflict/resume. This new instrumentation regression has not run. |
| Collection | Swift search/filter/sort/group endpoint, persisted grouping/sort controls, form/stock filters and two-item comparison with preferred-value markers. Edibles stay out of group gram totals. |
| Catalogue | Full public source records and links from the active verified catalogue, bundled fallback, measured branching tree with grandparents/parents/crosses and accessible native buttons. |
| Party/wellbeing | Custom games/rules, custom ways/categories/letters, legendary chance, reset controls, active mission/rule displays and combination prompts. Private self-check results and completed-break history with deletion and a saved starting pace. Bundled iPhone dose/decarb/safer-use copy and current 1.10 highlights. |
| Android access | App shortcuts, a Quick Settings stash tile, opt-in discreet ongoing stash notification. Actions open the normal app unlock flow. No Play services or CI. |
| Dependencies | Resolved Tesseract4Android 4.9.0 native licence files are bundled in Settings, with immutable source URLs/hashes. Its AAR manifest adds no permissions. Installation is limited to arm64-v8a and x86_64, matching the Swift bridge. The retained merged release manifest was inspected; no advertising ID, contacts, microphone, location or broad-media permission is present. Final APK packaging remains unverified. |
| Backup acceptance inputs | Swift Apple-side test can generate an encrypted synthetic archive containing edible/rosin records and a decodable PNG. Instrumentation imports/decodes/re-exports it, and Swift has a return-import check. These new checks are not reported as executed. |

## Verification results

| Check | Observed result |
| --- | --- |
| Source/release checks | `python3 scripts/android/check-source.py` and `python3 scripts/test_release.py` passed. XML, resource identifiers, shell/Python syntax, whitespace and one isolated synthetic release-preparation test. English/Dutch resource identifier sets match. This is not compilation or a localization/device audit. |
| Kotlin JVM corpus | 7 tests passed in the admitted Gradle run. The already-built, unchanged corpus then passed 7 tests each under default JVM locales `nl_NL`, `de_DE`, `en_US`, timezone Europe/Amsterdam. No JNI was exercised by these tests. |
| Android Swift | Both arm64 and x86_64 release TaimaBridge builds and JNI packaging passed at clean `3931f99`, whose full TaimaCore package tree equals the latest implementation. See round3 native/packaging logs and the APK-script log. |
| Android Kotlin/resources | Initial debug compile failed on the mixed-type SQL argument array and session callback argument order; `6b73535` fixes those. The release Kotlin sources subsequently compiled at `3931f99`. Resource linking then failed on `@string.name` shortcut labels. `9d28d10` fixes those to `@string/name`. The subsequent conflict/resume changes have not compiled yet. |
| Final APK | The last clean retry at `74e3799` returned `SAIKO_CAPACITY_UNAVAILABLE exit=75` before compilation. No signed APK exists, so size/digest/signature are unknown. |
| Swift tests/iOS build | Repeated gate refusals, including additional independent retries. Neither `swift test` nor the generic iOS simulator build executed in this continuation. The new Swift regressions and Apple-made photo fixture are added, not passed. |
| Device/JNI/backup | Not run. Device inventory was read, but no emulator was booted or driven. No screenshots, TalkBack, font-scale, language/theme walkthrough, instrumentation, fresh photo-archive round trip or Obtainium result exists. |

Logs and the retained merged release manifest are in
[2026-10-29](2026-10-29/README.md), with SHA-256 inventory. Intermediate successes
are identified separately. Round 2 also records a verification-helper mistake:
it was edited while Bash was reading it and terminated with a syntax error
after the admission refusals; round 3 ran a frozen helper copy.


## Exact remaining runs

- `swift test` in Packages/TaimaCore, including the new Android API regressions.
  The local helper sets `TAIMA_ANDROID_FIXTURES_DIR=$PWD/build/android-contracts`
  to generate the Apple-side synthetic photo archive for instrumentation.
- Generic iOS simulator build of Taima and its widgets, signing disabled.
- Final Android app/debug/instrumentation compilation after the Kotlin fixes;
  the initial app compiler failure is not converted into a pass by source edits.
- Final release APK packaging/signing after the XML and editor conflict fixes.
  Both native ABIs have compiled; the APK script still gates each rebuild.
- On one fresh, owned Android emulator, run `ParityTest` and the existing
  migration/rollback instrumentation. No user AVD or simulator data may be used.
- Walk every main screen and edit/reveal flow in English and Dutch, light/dark,
  and at maximum font scale; inspect TalkBack names, actions and reading order.
  Exercise live OCR/barcodes with synthetic inputs, picker/camera/SAF cancellation,
  app lock, shortcut/tile/notification entry, process death, widget races and
  WorkManager backups. Retain genuine screenshots here.
- Complete the Apple-made synthetic photo archive round trip through Android,
  extract only `synthetic-android-return.taimabackup` from the owned test app,
  and run the Swift test with both `TAIMA_ANDROID_FIXTURES_DIR` and
  `TAIMA_ANDROID_RETURN_ARCHIVE` set. Verify real decoding on both platforms.
- Run `scripts/build-apk.sh` from a clean committed tree. Record signed APK
  bytes, digest and certificate, inspect the final merged manifest, and test
  Obtainium install/in-place update on an Android device.

Use `scripts/android/verify-local.sh` for the explicit local build pass. Each
heavy operation independently uses the existing load gate. Its output lives
under ignored `build/android-verification` so it cannot invalidate the release
clean-tree check. The default admission wait is 30 minutes; a denied operation
returns 75 without running its build. Gate refusals must never be bypassed.
Gradle remains at two workers and a 2560 MB heap. Device interaction must use
Device tools; boot only after admission, record the owned emulator PID and stop
that PID after use.

## Remaining parity limits

The seven requested source gaps now have UI implementations, **not runtime
acceptance**. Full iPhone parity remains unproven. Only current-build highlights
are exposed; the historical per-build release list is not ported. The iPhone's
bulk/paired photo import, accepted-suggestion re-reading/learned corrections,
per-item share card, complete preference/reminder/reset flows and rich calendar/
strain-detail presentation still need an explicit parity inventory and closure.
Do not infer their completion from the broad feature table. Android shortcuts,
tile, widget and notification are platform alternatives; they do not establish
Siri/Spotlight/App Groups/Control Center/Live Activity equivalence.

## Signing, artefact and cleanup

No signed APK has been produced for this continuation. Its size is unknown.
The existing signing identity remains outside the repository at
`~/.local/share/taima/android-trial/release.jks`, alias `taima-trial`; its password
file remains beside it. Neither secret contents nor key bytes were printed or
committed. The older trial's APK/certificate results are not final acceptance.

Removed task-owned build outputs, generated JNI libraries, local Gradle/Kotlin
caches and the temporary source-parser installation after retaining the logs
and merged manifest. No emulator was created, started or left running. The
initial waiting gate processes were stopped only by their verified owned PIDs;
all subsequent build/test commands finished. Shared SDKs, toolchains and shared
dependency caches were preserved. Source, licences, synthetic test definitions
and genuine command evidence are retained. No other worktree, user database,
`/tmp/taima-clean`, simulator data or signing files were modified.
