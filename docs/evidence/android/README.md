# Android implementation acceptance record

2026-10-28. Synthetic fixtures only. Local branch, no push or publication.
Baseline: `4e2f7aa`; Android trial `41737d1` merged as `dec08c3`.

**Incomplete and not release-ready.** Source coverage below is not a claim of
runtime parity. The trial's old successful runs do not verify this implementation.

## Source paths added

| Area | Available implementation |
| --- | --- |
| Architecture | Hand-written JNI, versioned JSON success/error envelopes, scoped content language and resource directory. Shipping app has no Kotlin domain dependency. |
| Collection | SQLite documents, list/search, detail, add/edit, front/back/flower photos, deletion, tags, scores, dates, product codes, grower/shop. |
| Stash | Bag in use, core open/use/remaining rules, quick amounts, session method/moods/tobacco, repeat/undo, timed text notes. |
| Stats | Core inventory, collection/spending, growers, THC bins, monthly bars, tag/score/mood summaries. |
| Library | Bundled catalogue, Swift search/aliases, parent/child navigation, source IDs, owned bags and persisted wishlist. Explicit public catalogue download, verified in Swift before pointer switch. |
| Scanning | Bundled Tesseract English/Dutch, system camera/photo picker, editable text and review form. Do-I-have lookup from OCR codes/text. Core multi-frame fusion endpoint. |
| Party | Core deck/roulette, persisted players/state/scores, kinds and ways, individual games, secret reveal, scale target, hidden hot-potato timer, mission and rule state, standings, legendary drought. |
| Tools | Core joint/THC/edible arithmetic, persisted edible wait timer, break days/savings, self-check and guidance. |
| History/milestones/year | Core month/day history, anniversaries, milestones, selectable year, PNG share card. |
| Settings/data | Swift format-2 encrypted/plain archives, legacy import, Swift CSV, SAF, atomic database/photo restore, scheduled encrypted backups with a Keystore-wrapped passphrase. |
| Android integration | Material 3, compact navigation bar / wide rail, Back, insets, English/Dutch resources and plurals, app lock via system credentials, discreet Glance widget with quick log, onboarding/What's New. |
| Delivery | Clean-tree signed universal APK script, version/build from project.yml, existing signing identity, optional APK in shared release-preparation command, Obtainium instructions. |

## Verification

- `python3 scripts/test_release.py`: passed, one isolated synthetic test. It
  checks both assets in the printed release command, Android notes, and retained
  IPA SideStore metadata. It never invokes gh or changes this checkout's feed.
- `python3 scripts/android/check-source.py`: passed. XML parsing, missing/duplicate
  Android string/plural identifiers, shipping dependency imports, shell/Python
  syntax and diff whitespace only. This does not compile Swift or Kotlin.
- Repeated Swift/Gradle/iOS admission attempts returned
  `SAIKO_CAPACITY_UNAVAILABLE exit=75`. Those commands did not execute.
- One iOS generic-simulator build was admitted and failed on the newly added
  `PartySpin` Codable synthesis for `Character`. Explicit string serialization
  was added afterward. Final iOS and Swift reruns still require admission.
- New Swift API regression tests and mandatory Android `ParityTest` cover
  inventory mutation, structured counts, persisted games, JNI errors, plural
  resources, and Apple Swift-made synthetic backup round trips. They are added,
  **not reported as passed**.
- Existing Kotlin corpus and migration/rollback instrumentation are retained;
  no fresh successful execution is claimed.
- No emulator was started. No new screenshots, TalkBack, font-scale, light/dark,
  English/Dutch walkthrough or native JNI runtime result exists for this branch.
- `scripts/build-apk.sh` was invoked from a clean committed tree. It printed the
  existing signing key path and stopped at the gate with exit 75 before compilation
  (`apk-build.log`). No new APK exists. Its size is unknown, not the trial size.

## Remaining work beyond verification

- Continuous CameraX rotate-to-scan and live barcode recognition are not wired;
  the current scanner uses still images. The multi-frame core operation is ready.
- The editor does not yet OCR a back photo into the existing draft, choose/remove
  cover photos, or edit potency range/upper-bound metadata. Existing metadata is
  retained when its percentage is unchanged.
- Session detail editing and timed-note photos/deletion are not exposed in UI.
- Collection comparison, grouped/filter/sort controls, full catalogue source
  descriptions and a branching graphical family tree still need UI parity.
- Advanced party customization (custom rules/ways/categories, reset controls,
  richer per-game response/reveal flow), complete wellbeing history, dose/decarb
  guide parity and original per-build What's New highlights remain incomplete.
- iOS Siri/App Groups/Spotlight/Control Center/Live Activities have no direct
  implementation. Glance plus a system-credential app lock are present; Android
  shortcuts, a Quick Settings tile and an ongoing-session notification are not.
- Resource-key fallbacks and all remaining English/Dutch content require an
  actual device audit. Do not claim complete localization from XML validity.
- Review the resolved OCR AAR's native licences and merged manifest before release.
- Confirm real image decoding on both platforms, not only opaque backup bytes;
  selected Android images retain their encoding under the archive's .heic names.
- Test WorkManager backup scheduling and restore, biometric/device credential
  transitions, widget races, process death and cancelled SAF/camera flows.
- Verify Obtainium install and in-place update on a physical Android device.

## Required acceptance run

After admission, run `swift test` and the required generic iOS build, then build
both Android native ABIs and the debug/instrumentation APKs. Run Kotlin contracts
under nl_NL, de_DE, en_US, then `ParityTest` and migration/rollback tests on one
owned emulator via Device tools. Exercise every main screen in English/Dutch,
light/dark, largest font scale and TalkBack. Retain genuine screenshots here.
Import/export a freshly iOS-made synthetic backup with real decodable photos and passphrase, and
restore the Android-written file with iOS. Build/verify the signed release APK
only after these and the remaining source features are complete.

## Signing and cleanup

Existing signing key retained outside the repo:
`~/.local/share/taima/android-trial/release.jks`, alias `taima-trial`.
Password is in the sibling `keystore-password`, never logged or committed.
The key was freshly inspected with keytool; its SHA-256 certificate matches
`d596a6ac7c1335cf62bd79d10c2a6b132bce27320ae65050eb608c52c27c3638`.
**Back up both. Losing this key prevents updates to existing installs.**

Removed the task-owned 114 MB iOS derived-data folder, temporary source-parser
environments and downloaded dependency-inspection files. The idle initial load
gate was terminated by its verified PID; no build or emulator was left running. Bundled OCR models/licence and the trial's
committed evidence are retained as source inputs. No user database or simulator
was read, and no process belonging to another task was stopped.
