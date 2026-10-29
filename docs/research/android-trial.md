# Taima Android portability trial

Date: 2026-10-28. Synthetic data only. Continuation branch `t3/android-trial-2`
starts from checkpoint `af2540d` on `t3/android-trial`. No push, merge, CI job,
Play Console account or publication is part of this continuation.

## Summary

Native Kotlin/Jetpack Compose can express Taima's collection and logging slice
while exchanging its existing persisted contracts. Swift 6.4.0 cross-compiles
TaimaCore and a small JNI entry point for Android arm64 and x86_64. Runtime and
performance results below determine the remaining portability claim; compilation
alone does not establish it. Keep the portable record/backup/CSV/catalogue corpus
as the architecture seam. Do not treat this trial as full Android parity. Fresh Android execution passed 165
tests with no failures; 19 SQLite-module-guarded declarations were unavailable.
JNI call overhead, Room/plain SQLite runtime comparison, rendered app acceptance
and the signed release APK remain unverified after the boot-readiness failure
and load-gate refusals. No runtime timing is invented for these requirements.

Saiko Next's [ADR-001](https://github.com/lammersbjorn/saiko-next/blob/main/docs/decisions/ADR-001-app-framework.md)
chooses SwiftUI on iOS and later native Compose on Android, sharing persisted
contracts and possibly Swift after a new portability proof. Its
`docs/plans/parallel-work-2026-10-26.md`, section 2, authorizes only a bounded
UI trial in Saiko. This separately requested Taima experiment is broader; it
does not change that scope or edit either Saiko document.

## Outcome: the full app (2026-10-29)

The trial turned into a released app. Taima 1.11 ships a signed Android APK
next to the iPhone IPA on [the GitHub release](https://github.com/lammersbjorn/taima/releases/tag/v1.11),
updated through Obtainium. The rest of this note describes the first trial;
this section records what changed once the whole app was built on its findings.

- **Architecture held.** Kotlin does UI, platform glue and storage only. All
  domain logic runs in TaimaCore over JNI through 37 coarse JSON operations
  (`AndroidAPI.swift`, 349 lines; `TaimaBridge`, 62 lines) with versioned
  success/error envelopes. The Kotlin app is about 3,200 lines. New core features,
  such as the rebuilt party deck and the rosin/edible item types, reached Android
  without a port. The only Android-side work was screens and resources.
- **Size.** The release APK is 41,104,144 bytes for arm64-v8a only. The first
  universal APK was 71 MB because it carried x86_64 libraries that only
  emulators need. `lib_FoundationICU.so` (about 40 MB uncompressed) is the
  largest single file and could not be removed without breaking the date and
  plural behaviour that the contract tests cover.
- **Verification that passed:**
  - 219 Swift tests and the iOS build;
  - Android Swift builds for both ABIs;
  - Kotlin contracts under nl_NL, de_DE and en_US;
  - 10 instrumentation tests;
  - an Apple → Android → Apple backup round trip;
  - an update installed over the previous build that kept its data;
  - all main screens in English and Dutch, light and dark, at normal and 2.0
    font scale.
- **Not verified:**
  - TalkBack spoken output, because automation left the service unbound;
  - an actual Obtainium install and update;
  - widget refresh races;
  - process-death recovery;
  - parts of the nested Stats and History interactions.
- **Design needed its own pass.** The first full build used default Material 3
  styling. It looked generic: tinted purple surfaces, tab labels that broke
  mid-word in Dutch ("Statistiek/en"), and plain label lists for stats. A
  dedicated pass applied the visual language with an explicit colour scheme and
  no dynamic colour: neutral page, opaque cards, one green accent on controls,
  tabular numbers, short tab labels. Budget a design pass separately from
  functional parity.
- **Two release-only bugs** surfaced only in the minified release build: Room
  constructors removed by R8, and a resource error in shortcuts. Test the
  signed release APK, not just debug builds.
- **The shared host was the main bottleneck.** Load stayed between 100 and 900
  for most of a day, mostly from other agents' simulators. The load gate refused
  builds for hours at a time. Six implementation and verification runs were
  needed, and most of their wall time was spent waiting rather than building.
  Verification only completed once a run was dedicated to waiting for a quiet
  window.

For Saiko Next, this is evidence that a shared Swift core can carry a complete
Compose app, at the cost of about 40 MB of runtime and a more complex build. It
does not change ADR-001's choice by itself. Compare the cost of the runtime with
the cost of porting a domain engine of Saiko's size.

## Method and provenance

Host: Apple M3 Pro, macOS 27.2 (26B5112a). Builds use the host load gate, two Swift jobs or two Gradle workers, and Gradle's
2560 MB heap. Admission wait is excluded from `/usr/bin/time` observations.
Shared host load and file caches are uncontrolled. Cold means an empty named
scratch directory, not a reboot or empty filesystem cache. Warm means a no-op
rebuild unless explicitly labelled changed-source. One observation is not a
performance distribution. Retained checkpoint logs are identified separately
from the fresh continuation runs.

The corpus in `contracts/golden/` contains a made-up Unicode record, CSV, a
catalogue manifest and content digest, and backup format 2 with/without a
Unicode passphrase. A synthetic opaque photo payload checks archive retention;
it is not an image-decoder/HEIC compatibility test. Fixed salt/nonces exist only
in the goldens. Production exports use secure randomness. Both languages consume
the same bytes, test corruption/wrong-passphrase rejection, and compare the
supported CSV projection rather than pretending CSV restores session history.
Dates use UTC wire syntax; Europe/Amsterdam's spring transition checks that
adding one calendar day preserves noon over 23 elapsed hours.

JNI measurements call the same Swift decode → validate → trim name → sorted JSON
operation. Seven batches of 10,000 calls follow 1,000 warmups. The string comparison
includes UTF-16/UTF-8 conversion on both routes. A direct Swift batch estimates the
core contribution but subtraction is only a noisy estimate, not a pure JNI latency
measurement. Kotlin is a separate implementation with narrower validation parity;
its timing cannot establish equivalence for all records.

Room/plain SQLite compare 1,000 JSON-document writes in one WAL transaction,
after warmup, over seven batches on the same emulator. The test first upgrades
identical hand-created version-1 tables to version 2 and verifies retained rows
and the wishlist table. This isolates a small write workload, not application
startup, concurrent readers, query planning or a phone's storage.

## Exact environment and working route

| Component | Pin used |
| --- | --- |
| Swift toolchain | Standalone Swift 6.4.0 RELEASE, matching Android SDK |
| Swift Android SDK | `swift-6.4.0-RELEASE_android`, artifact version 0.1; target API 28 |
| NDK | r28c, `28.2.13676358`, user-space SDK |
| AGP | 9.5.0, built-in Android Kotlin support |
| Kotlin JVM / Compose compiler plugin | 2.4.21 |
| Compose BOM | 2026.09.00 |
| Gradle / JDK | 9.8.2 wrapper / 21.0.13.0.2; swift-java macro setup uses JDK 25 |
| Compile / target / min Android API | 37.2 revision 2 / 36 / 28 |
| Build tools / command-line tools | 36.0.0 / 23.0 |
| Room | 2.8.5, Java annotation processor; no KSP setup |
| Emulator / system image | 36.6.11 / Android 36 Google APIs arm64-v8a revision 7 |
| AVD | `Taima_Trial`, 2 CPU cores, 2048 MB RAM |
| swift-java | revision `301e3da710ede7af93e798f1ce1c7950715a5748` |

Latest stable AGP, Kotlin and Compose BOM were checked against their publisher
Maven metadata during continuation; see `stable-versions.json`. Swift/NDK pins
are the working matched SDK route, not a claim that Swift 6.4.0 is the newest
host compiler. The Swift getting-started page now illustrates 6.4.1; changing a
matched toolchain/SDK pair would be a different measurement.

1. Install matching standalone Swift and its Android SDK in user space, plus
   NDK r28c; follow Swift's Android SDK configuration instructions.
2. Build with `scripts/android/swift-build.sh aarch64 debug` or the release
   variant for `aarch64` and `x86_64`. Each invocation passes the gate.
3. `package-jni.sh` compiles the 29-line C adapter with the NDK, strips native
   libraries and retains the ELF dependency closure. `-PwithSwift=true` includes it.
4. Build the optional generated product using `android/swiftjava/README.md`.
   Prepend the standalone compiler to PATH: an upstream helper otherwise selected
   Apple's `/usr/bin/swift` and failed. `DEVELOPER_DIR` alone did not fix discovery.
5. Build JVM tests/APKs with the wrapper. `-PtrialLocale=<locale>` sets the entire
   JVM test default locale; timezone is Europe/Amsterdam. Run the full matrix,
   not only the decimal parser test.
6. Use T3 device tools to open the owned AVD after admission, install only the
   synthetic test APKs, run Swift tests and instrumentation, then terminate its
   recorded emulator PID. Never operate other simulators or read user databases.

## Swift build and library measurements

Retained checkpoint measurements, seconds:

| Build | Time | Interpretation |
| --- | ---: | --- |
| Android arm64 debug, fresh scratch | 117.75 | Includes test build |
| Android arm64 debug, no-op warm | 2.84 | Same scratch |
| Android arm64 release, fresh scratch | 115.19 | TaimaBridge product |
| Android x86_64 release, fresh scratch | 155.41 | TaimaBridge product |
| Android arm64 release, changed source | 64.10 | Not no-op warm |
| Android x86_64 release, changed source | 55.51 | Not no-op warm |
| Fresh continuation arm64 test rebuild | 34.28 | Reused scratch, new worktree paths |
| Fresh continuation Mac full suite, build + tests | 69.95 | 184 tests, 0 failures; test runtime 2.640 s |
| Retained iOS generic simulator build | 131.45 | Build succeeded; no device operated |

Final sizes are in `native-sizes-final.json`. The stripped TaimaBridge library
is 5,210,000 bytes on arm64 and 5,733,776 bytes on x86_64. Their handwritten JNI
runtime dependency closures total 70,606,064 and 72,153,528 bytes respectively,
19 libraries per ABI, before APK compression. ICU dominates (about 40 MB per ABI).
Copying every SDK `.so` would also ship unused testing libraries; the earlier
`native-sizes.json` did that and is not the final runtime footprint. Generated
JNI adds its own libraries and is only measured on arm64. x86_64 is build/size
coverage, not emulator runtime coverage.

## Fresh contract and runtime results

| Execution | Passed | Failed | Runtime skipped | Coverage gap |
| --- | ---: | ---: | ---: | --- |
| Mac full TaimaCore | 184 | 0 | 0 | Host only |
| Android arm64 full TaimaCore | 165 | 0 | 0 | 19 declarations excluded by `canImport(SQLite3)` |
| Swift golden suite, Mac, each locale environment | 4 declarations | 0 | 0 | Three locale-number arguments within the fourth declaration |
| Swift golden suite, Android, each locale environment | 4 declarations | 0 | 0 | Same synthetic bytes, Amsterdam timezone |
| Kotlin JVM whole corpus, each default locale | 7 | 0 | 0 | Compiled classes run directly with JUnitCore |

Full Android runtime was 53.560 s on the admitted AVD; this shared-host execution
is not a device performance benchmark. Each Android golden run passed, including
backup encryption/photos, CSV import/export, record JSON, catalogue verification
and the 23-hour Amsterdam spring day. The JVM runs took 0.582, 0.490 and 0.442 s
under nl_NL, de_DE and en_US, respectively. These are suite durations, not bridge
latencies. Locale arguments also explicitly test comma/dot rejection.

The retained baseline's 14 resource-path errors were harness deployment errors,
not Foundation/ICU defects. The affected bundled-alias/selection/grower tests now
pass using `TAIMA_REPO_ROOT` and deployed public resources. The two plural
assertions also pass after the non-Darwin fallback fix. No remaining executed
failure needs a Foundation/ICU/toolchain classification. The 19 compile-time
exclusions are a **toolchain/SDK module availability gap**: Android does not
expose the `SQLite3` Swift module, so guarded store, wishlist, reset and migration
tests are absent, including some non-SQLite tests grouped in guarded files. Do
not count these as runtime skips or claim the entire Mac suite ran on Android.
The production Swift BagStore is guarded too; the JNI probe does not exercise
Swift persistence. A future Swift persistence route needs a public, supported SQLite dependency
and a fresh run of those declarations.

The generated JNI release build succeeded in 803.80 s after resuming the
interrupted scratch. This includes rebuilding host macro dependencies and
Android libraries, so it is neither a clean cold measurement nor a no-op warm
measurement. `libSwiftJava.so` is 2,343,592 stripped bytes and
`libTaimaGenerated.so` 8,232; total arm64 native closure with both probes is
72,957,888 bytes. Compilation does not prove JNI execution or ART error mapping.

The first emulator session was admitted after the gate passed. Its actual PID
14993 was retained and terminated after the Swift suite. T3 reported the device
booted, but installing the app returned `Error: device is still booting.` No
instrumentation, Room timing or rendered app flow is credited to that session.

## JNI, storage and app acceptance limits

| Requested check | Result |
| --- | --- |
| Handwritten versus generated JNI call overhead | Both release libraries and the instrumented comparison compile; no executed timing samples |
| JNI error boundary | Both source paths return the same JSON envelope; ART assertions remain unexecuted |
| Room versus SQLite write timings | Seven-by-1,000-row harness compiled; no executed timing samples |
| Version-1-to-2 migrations and atomic/photo restore | Instrumentation compiled, not executed; Swift persistence tests also excluded as above |
| English/Dutch manual add → use → log → relaunch | Source and compilation only; no rendered journey credited |
| Light/dark, large text, TalkBack, physical phone | Unverified |
| Local release signing | Keystore created and permissions/certificate checked; release APK build withheld by gate |
| Obtainium install/update | Instructions documented; not executed or published |

The first installation failed before instrumentation started. After stopping the
emulator, both-probe debug app/test APKs built in 52.65 s and were retained at
`~/.local/share/taima/android-trial/artifacts/`. The measurement app is 119,986,615
bytes, test APK 1,642,926 bytes; hashes are in `apk-artifacts.json`. The app is
**debug signed**, not signed with the local release key. This large two-ABI probe
APK is not the default Kotlin-only app size. No release APK size is claimed.

Subsequent bounded release admission checks returned
`SAIKO_CAPACITY_UNAVAILABLE exit=75`. This is unavailable host capacity, not a
Gradle failure. The load limit stayed at 60; it was never raised. Default 30-minute
waits were cancelled in favour of bounded 60-second attempts. No second emulator
was started while new builds were unavailable. Existing compile-time test and
instrumentation code are reviewable, but do not replace these missing runtime
measurements. Use `run-instrumentation.sh` once a fresh gate passes and the owned
AVD reports `sys.boot_completed=1`; it refuses premature installation. Capture
all `TAIMA_BRIDGE`, `TAIMA_GENERATED` and `TAIMA_STORAGE` batch samples before
reconsidering JNI overhead or persistence performance.

The explicit JSON boundary maps malformed/decode/encode failures to
`{"error":"invalidJSON"}`, and validation failures (for example negative grams)
to `{"error":"invalidRecord"}`. Success is `{"record":...}`. Swift errors never
unwind through C. Handwritten JNI copies the UTF-8 byte array, releases the Java
input with JNI_ABORT, copies the result and calls `taima_free`. Generated JNI
converts Java strings and returns the same envelope; its API is deliberately
nonthrowing. No conclusion about swift-java's general Swift `throws` mapping,
OOM handling or object lifetimes follows from this probe.

## Kotlin port effort and data integrity

The Kotlin portable layer is 231 physical lines: Archive 82, CSV 66, Records and
AmountInput 65, Catalog 18. The explicit Android SQLite adapter is separate,
as are Compose UI, Room entities and tests. These are dense trial source lines,
not a maintainability score or an estimate of a full port. No human person-hours
were measured. Git timestamps and build wall times cannot provide them. The
checkpoint already contained these implementations; continuation work focused
on executing measurements, packaging, party scope and documentation.

The app uses Kotlin for archive framing/PBKDF2/AES-GCM, CSV, document handling,
locale numbers and session updates. It does not call Swift in its normal UI.
The JNI probe calls Swift for JSON normalisation only. Handwritten setup adds a
29-line C adapter with explicit allocation/free ownership and the NDK packaging
step. Generated setup adds a 6-line forwarding function, 23-line generated Swift
thunk, 33-line generated Java wrapper, a pinned package dependency and upstream
Java loader sources. The retained host-generator build succeeded in 77.72 s,
after a PATH-discovery retry. Those source/build measurements describe setup
work; no human implementation-time measurement was taken. Unknown JSON fields survive
Kotlin edits, while the typed Swift encoder drops fields it does not model.
Passing the fixed corpus does not make those behaviours identical. Kotlin's
validator and CSV parser need a larger malformed/optional/range-value corpus
before promotion. No general cross-language JSON canonicalisation standard is
claimed. Dates, number spellings and key order are pinned for these fixtures.

Backup replacement is transactional across bags, metadata and Android photo
BLOBs. The BLOB table is Android-specific, not part of BagStore's portable schema.
No cross-platform database-file migration or real user restore was tested.
CSV import intentionally creates empty-stock records and does not restore usage.

## App, OCR and distribution

The app has collection/detail/manual editor, one bag in use, quick amounts,
session notes/history, basic statistics and SAF backup/CSV exchange. It follows
Material 3 with a compact navigation bar and a rail from 600 dp. English and Dutch
resources include singular/plural item counts and locale number input. It is a
trial slice: no catalogue browsing/import UI, camera OCR, photo viewer, full
statistics parity, tablet acceptance or Android-phone acceptance is claimed.

Party is a sequential reader for bundled JSON only. Eligibility, randomness,
player substitution and deck flow were removed from the checkpoint Android app
because Party.swift and content are being rebuilt elsewhere. The new deck flow
lives in Swift; Android party-game parity is unclaimed.

[OCR options](android-ocr-options.md) distinguishes image processing from network
metadata. ML Kit states recognition inputs/outputs stay on-device, but publishes
metrics/update traffic and per-install identifiers even for bundled features.
Bundled Tesseract is the preferred next experiment, with synthetic accuracy and
network verification still required. The app has no internet permission or OCR
SDK. SAF providers may upload exported files if the user chooses a cloud location.

A local keystore/password pair lives outside git at
`~/.local/share/taima/android-trial/`, with directory 0700 and files 0600.
No key/password was printed or committed. [Android instructions](../../android/README.md)
document signing and Obtainium's GitHub release source route. No release was
published; Obtainium installation/update and physical-phone signing acceptance
remain unverified.

## Recommendation and open questions

Keep Compose native and persisted formats as the seam, consistent with Saiko's
ADR-001. The trial demonstrates a route to build Swift, not grounds to require a
Swift runtime in every Android build. Kotlin avoids the measured runtime closure
and generator setup, but incurs real duplicated logic and parity work. Before a
product decision, obtain JNI/storage device results and check full malformed-input compatibility,
archive memory limits, hardware timings, ABI/page-size support, licence review
and upgrade maintenance against the cost of porting the actual domain engine.
Prefer coarse JSON operations over many object-level JNI calls if Swift reuse
is chosen. Keep explicit error envelopes and narrow ownership at the boundary.

Open gates include production-scale archives, Android backup restore on diverse
phones, keyboard/rotation/accessibility journeys, TalkBack, camera OCR and
network capture, the rebuilt Swift party flow, encrypted export interrupted by
process death, 16 KB-page target acceptance and an actual signed Obtainium update.
A simulator screenshot, source review and local signing are separate claims.

## Cleanup and handoff

Removed the task-owned `/tmp/taima-trial-*` scratch/download/log paths, this
worktree's Swift/Gradle build caches and native packaging outputs, and the
Quick Boot snapshot created by the owned emulator session. Confirmed that no
emulator or build was using those paths first. The old worktree was not edited.
`cleanup.json` records the 36 removed paths. No new AVD or system image was
created during continuation; pre-existing AVD disks/system images, shared tool
caches and user-space SDK/NDK/Swift installations were preserved.

Kept the two measurement APKs (about 122 MB combined) and private local key/password
under `~/.local/share/taima/android-trial/`, plus small committed evidence and
synthetic goldens. The APKs permit later execution without rebuilding, but must
not be confused with a signed release. `run-instrumentation.sh` accepts their
paths as its second and third arguments. No build process, emulator, push,
merge, PR or release publication remains active from this task.

The requested `saiko-next-d0` alias returned `thread_not_found` for both read and
send. The Saiko project's founding coordinator was separately identified through
T3 and its user brief read before handoff. See `delivery.json` for the actual
notification result; tool acceptance is not a claim that the coordinator read
or acted on the report. No Saiko source or decision document was edited.

## Primary sources

Accessed 2026-10-28; measurements above come from local evidence, not these pages.

- [Swift Android SDK getting started](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html): matching toolchain, SDK and NDK route.
- [Pinned swift-java source](https://github.com/swiftlang/swift-java/tree/301e3da710ede7af93e798f1ce1c7950715a5748): generator and runtime provenance; also inspected locally.
- [AGP publisher metadata](https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/maven-metadata.xml), [Kotlin publisher metadata](https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/kotlin-gradle-plugin/maven-metadata.xml), [Compose BOM metadata](https://dl.google.com/dl/android/maven2/androidx/compose/compose-bom/maven-metadata.xml): stable pins.
- [Kotlin releases](https://kotlinlang.org/docs/releases.html), [Compose compiler setup](https://developer.android.com/jetpack/androidx/releases/compose-kotlin).
- [Room migrations](https://developer.android.com/training/data-storage/room/migrating-db-versions): migration validation and schema export.
- [ML Kit terms](https://developers.google.com/ml-kit/terms), [Android disclosure](https://developers.google.com/ml-kit/android-data-disclosure), [OCR setup](https://developers.google.com/ml-kit/vision/text-recognition/v2/android).
- [Tesseract engine/models](https://tesseract-ocr.github.io/tessdoc/Installation.html).
- [Obtainium upstream](https://github.com/ImranR98/Obtainium).

Decisions: [Android ledger](../decisions/android-trial-ledger.md).
Evidence directory: `docs/evidence/android-trial/`.
