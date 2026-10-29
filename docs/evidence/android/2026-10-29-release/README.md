# Android release continuation, 2026-10-29

Synthetic data only. Local branch `t3/android-release`, based on main `9134110`,
merged `t3/android-ready` (`8fdd12e`) with merge commit `1cb54ab`.
The named earlier worktree was read only and never edited.
No push, merge to main, CI, Play Store or publication.

**Not release-ready until all required runs pass. No exceptions are accepted.**

## Verification continuation on `t3/android-verify`

The new run started at `cd82268`. Two verification fixes are committed:
`c14d9f5` aligns the test-only Room benchmark compiler/runtime to the app's
resolved Room 2.6.1; `00b8ed6` keeps reflected Room database constructors in
shrunk release builds. No features, CI, push, main merge or publication were added.
The evidence below is fresh and supersedes the older pending build results.
Earlier observations remain below as history, not additional current passes.

| Check | Fresh result and limit |
| --- | --- |
| Admission | The unchanged host gate waited roughly 20 minutes before the first Swift run. Every Swift, Gradle and xcodebuild invocation was gated; the Android build helper and APK script independently gate their builds. No bypass. |
| Swift | **Passed: 219 tests, 48 suites** at `cd82268`, including the corrected timestamp and label-sample regression. Swift sources are unchanged by both fixes. |
| iOS | **Passed** generic iOS Simulator build at `cd82268`, two jobs, isolated derived data, signing disabled. iOS/Swift sources remain unchanged. |
| Android Swift/JNI | **Passed** release builds and packaging for arm64-v8a and x86_64. Final APK script repeats both at `00b8ed6`. Runtime instrumentation used arm64; x86_64 runtime is not claimed. |
| Kotlin | **Passed** seven unit/contract tests and seven tests under each of nl_NL, de_DE and en_US, Europe/Amsterdam. Final APK script repeats them at `00b8ed6`. |
| Signed APK | **Passed** `scripts/build-apk.sh` at `00b8ed6`, v2 signature verified. `build/Taima-1.10.apk`, **71,385,534 bytes**, SHA-256 `2a7bc48612bf973ad03ca50cf419d48ada1447910940bdcf89998c1048ed4a4f`. Full local path, source and public certificate digest: `verification/run.json`. The APK remains local and uncommitted. |
| Instrumentation | **Passed: 10 tests**, ParityTest and TrialTest, at `c14d9f5`. Initial run had one Room AbstractMethodError; the isolated benchmark reproduced it before the fix. Debug/test APK rebuild and full rerun passed. The later keep-rule change affects release shrinking, not these debug binaries. |
| Backup | **Passed** fresh Apple-made encrypted synthetic photo backup through Android JNI and an Android-written return archive imported/decoded on Apple. Fixtures and return archive are retained in `verification/backup-roundtrip/`. This is a native archive/codec round trip, not a manual SAF interaction pass. |
| Update retention | **Passed** controlled same-ID, same-key update from re-signed version-1 debug trial to release version 12. A synthetic item created in the predecessor, with 5 g, remained visible in the final release. The intermediate release crashed at WorkManager startup; the constructor keep-rule fix rebuilt, installed over it without clearing data, and launched successfully. Before/after screenshots and version read-back are retained. This is not a published-release or Obtainium acquisition test. |
| Main-screen matrix | **Checked and visually reviewed** Collection, Stash, Stats, Library and More in English and Dutch, light/dark, font scale 1.0/2.0: 40 captures. Android Settings' rightmost font slider was selected and read back as 2.0. Large-font labels wrap heavily on this 320×640 emulator; tabs remain operable and the collection scrolls to the item. Stash was checked in its empty state; Library in its initial/search state. Nested flows and all populated states are not thereby certified. Dutch maximum-font History additionally rendered its day-list alternative. |
| TalkBack | **Partial, live pass still required.** Main labels, item summary, search and add controls were inspected in the accessibility tree. TalkBack was enabled through system UI, but automation left it unbound with touch exploration off. After `agent-device close`, TalkBack bound and touch exploration became active. `talkback-bound.txt` and `talkback-after-close.txt` retain this controller limitation. No live focus traversal or spoken-audio pass is claimed. |
| Extra stress | The tool's 3.2 font preset lies beyond the Settings slider. It produced severely crowded navigation; it is retained as a limitation, not a passing UI result. |

The first instrumentation packaging attempt omitted ANDROID_HOME and failed
before compilation; the corrected gated command passed. The first predecessor
signing command reused one password-file stream and failed; omitting the redundant
key-password option succeeded. No signing material was printed or retained.
Device controller recovery errors were inspected and recovered through the
returned advice; no adb/simctl/SSH UI-driving fallback was used.

The owned AVD was created only for this run, after admitted build work; its sole
emulator boot followed an explicit gate pass. PID 15013 was verified against the
unique AVD name, stopped with SIGTERM immediately after device work, and confirmed
absent. Task-owned AVD/build/JNI/Gradle/Kotlin scratch outputs are removed after
retaining evidence and the final APK. Shared SDKs, global dependency caches,
other devices/processes and signing files are preserved.

## Source parity inventory

| Required area | iPhone reference | Android addition | Acceptance still needed |
| --- | --- | --- | --- |
| Main CSV change | `Packages/TaimaCore/Sources/TaimaCore/Backup.swift` | Swift-generated `collection.csv` includes final `thc_mg_each`; Kotlin comparison codec supports the column and edible/rosin forms. New edible CSV regression verifies a nonempty dose. | Swift and all three JVM locale results for final fixtures; JNI CSV test. |
| Widget pieces | `App/TaimaWidgets/TaimaWidgets.swift`, `WidgetSnapshot.swift` | `bag.view` supplies whole-unit count and unit amount from Swift; widget displays units and logs one edible or preroll. Half-piece remains available inside Stash. | Actual widget refresh, race, empty-item and edible tapping tests. |
| Bulk import | `CollectionView.swift`, `AppModel.importPhotos` | Multiple-picker front-only or alternating front/back imports, sequential bounded image decoding/OCR, one-item-at-a-time editor queue, per-item save or discard, failed-item count. | Picker order/cancel, odd final pair, errors, process death, large collection. |
| Learned corrections | `LearningViews.swift`, `AppModel.makeDraft`, `Learning.swift` | Local Swift CorrectionMemory apply/learn/forget, default-on preference; learned producer identifiers saved with the item and reused from SQLite. | New scan/correct/save/rescan flow, disabling/deletion and backup producer-key retention. Opt-in redacted label-sample preview/sharing now uses Swift LabelSample; its redaction regression still needs the admitted Swift rerun. |
| Accepted re-reading | `AppModel.reviewSuggestions`, `EntryReview.swift` | Settings scans stored front/back photos, previews shared-core fill-empty changes, accepts per item; writer verifies unchanged baseline before commit. | Permission-free stored-photo flow, cancel/recovery and concurrent edits. Back-only records are included; review-owed prompts still need parity closure. |
| Item sharing | `ShareCard.swift` | Native PNG preview and explicit Android sharesheet, photo plus an allowlist of public review fields; long text wraps. Codes, prices, shops, notes and sessions are excluded. | Rendered card, image decode/rotation, English/Dutch, sharesheet cancellation, potency range/upper-bound presentation (source handling is added). |
| Historical highlights | `Onboarding.swift` | Generated source asset has all 11 historical builds, 62 entries; Android labels it iPhone release history. | Rendered scrolling and reading order; verify onboarding filters to builds newer than the recorded seen build. |
| Settings | `SettingsView.swift`, `StashView.LimitsSettings` | Default stock, learning/review, weekly/low-stash preferences with Swift crossing rules, local neutral reminders, intro/history, language settings, Obtainium link, version, CSV privacy confirmation and typed DELETE reset with database compaction. Lock immediately enables secure-window handling. | Settings persistence, permission cancellation, reset/WorkManager races, encrypted backup and SAF flows. iPhone-specific signing/iCloud controls have Android distribution/cloud-backup alternatives, not claimed equivalent runtime evidence. |
| History | `HistoryViews.swift` | Locale-first-weekday calendar; bounded month navigation; use/no-use/untracked descriptions; day selection and session-to-item navigation; linked anniversary items; large-font list alternative. | English/Dutch light/dark/max-font/TalkBack walk. Grouped strain metrics, tappable THC history and effect counts are added; full interactive Stats presentation and exact strain-summary coverage still need parity closure. |

Compilation, tests, signing, native execution, screen checks and distribution are
separate results. Earlier retained trial logs do not verify these additions.

## Earlier observed verification (historical)

| Check | Result and scope |
| --- | --- |
| Final frontend compilation | Passed `:app:compileDebugKotlin :app:compileDebugAndroidTestKotlin` at clean `440fac1`. The final app source tree is identical. See `frontend-compile.log`. This compiles app and test sources, not JNI execution. |
| CSV regeneration | `recordCSVAndManifest` passed and regenerated `collection.csv` at `4ed59a9`. The added edible fixtures were then generated by executing that already-built Swift library's `taima_normalize`/`taima_call` entry points, with no compiler invocation. Its model/CSV/normalizer sources are unchanged. `csv-built-swift.log`, the retained generator and `provenance.json` identify the exact inputs. The final golden-test rerun was denied. No CSV golden was hand-edited. |
| Full Swift tests | First admitted run executed 218 tests and reported one failure in the new review regression's timestamp equality: the wire format rounds to seconds while its initial Date.now fixture had fractions. `ff77d72` changes the fixture to an exact second. The corrected full rerun and added sample-redaction test were denied, including the final clean retry. They remain unpassed. |
| Apple photo fixture | `applePhotoArchiveAndOptionalAndroidReturn` passed its Apple-side generation/decoding portion in that admitted run. Its synthetic archive, manifest and PNG are retained under `apple-fixture/`. No Android return archive existed, so this does not pass the Android-to-Apple return check. |
| iOS simulator build | Generic simulator `xcodebuild` passed at the round-1 production source, including Taima and widgets, arm64/x86_64, signing disabled. `label.sample` was added afterward. The final-source rerun was denied, so the earlier success is not a final-head pass. See `round1/ios-build.log`. |
| Kotlin contracts | After the edible fixtures were generated, the unchanged compiled corpus passed 7 tests each under default locales nl_NL, de_DE and en_US, Europe/Amsterdam. See `jvm-corrected-locales.log`. Those classes were compiled at `ff77d72`; the final Kotlin core source tree is identical. No JNI is exercised. The preceding Gradle run failed because the new edible fixture had not existed yet. The later Gradle retry was denied. |
| Android Swift/JNI | Arm64 release TaimaBridge build and packaging passed at `ff77d72`, before `label.sample`. x86_64 was denied. Both final-source ABI retries were denied. No final-native/runtime pass is claimed. |
| Signed APK | Clean-tree `scripts/build-apk.sh` attempts at `0674234` and `5eb84e6` returned 75 before compilation. No signed APK was produced. Size, digest, signature and artifact path are unknown. Intended output is `build/Taima-1.10.apk`, currently absent. |
| Instrumentation | Test sources compiled; tests did not run. A current debug/test APK must be packaged after the final JNI libraries and release clean step. The helper now enforces that order. |
| Device walkthrough | Inventory only. No AVD was created or booted, no device data was read and no owned emulator PID exists to stop. English/Dutch, light/dark, maximum font scale, TalkBack, screenshots, photo/SAF cancellation, widget races and backup round trip are unpassed. |
| Update retention | The retained trial APK's digest/application ID/version were verified (`predecessor.json`). It was not re-signed, installed or modified. In-place same-key update and actual Obtainium acquisition remain unpassed. |
| Cheap checks | Source/XML/resource identifiers, shell syntax, whitespace and isolated release preparation passed. Resource identifier sets match in English/Dutch. Native/Gradle refusal propagation passed with inert build stubs and synthetic signing files. The final test leaves HOME unchanged and uses only disposable script copies. |

Round 1 starts at `4ed59a9`; the golden and helper fixes/tests were committed
between operations as shown by its per-operation source records. Round 2 starts
at `440fac1`; the generated edible fixture commit is `0674234`. No app source
changed after the successful round-2 frontend compile. Final clean Swift, iOS
and APK attempts were made at `5eb84e6`; all returned 75. Later changes are
verification plumbing and this record. The aggregate verifier previously
returned 1 even for denied operations; its individual exit-75 lines are the
capacity evidence. The helper now preserves 75 unless a real failure also occurred.

Intermediate compile failures are retained, not hidden: the initial new widget
resource reference was added; the share card's Compose-only amount helper was
split into a Context formatter plus a Compose wrapper. Their corrected frontend
compile passed. The Swift timestamp correction is written, not reported as passed.

## Still required

1. Complete live TalkBack focus/label/speech verification with a controller that
   preserves the bound accessibility service. Accessibility-tree inspection
   and an enabled-but-unbound service are not a pass.
2. Complete the source/runtime parity gaps listed in the inventory: widget
   refresh/races, populated Stash, picker/cancel/process-death, learning and
   review recovery, sharing/SAF/settings transitions, and the full nested
   History/Stats interaction matrix. This verification run added no features
   and does not close those pre-existing gaps.
3. Actual Obtainium acquisition remains untested; nothing was published.

Builds, contracts, instrumentation, the native backup round trip and the
controlled update now have fresh passing evidence. Full release acceptance
remains open for the above runtime and parity checks.

## Cleanup and boundaries

The earlier worktree, main, user AVDs, user simulator data, `/tmp/taima-clean`,
shared SDKs/toolchains/dependency caches and signing files were not modified.
The mistakenly waiting `--help` gate process was stopped early by its verified
owned PID; all actual verification processes finished. No emulator was created.
Task-owned build/derived-data/native/JNI outputs and local Gradle/Kotlin caches
are removed after retaining these logs, synthetic fixtures and source. No APK
exists to retain. No push, CI, merge to main or publication occurred.
