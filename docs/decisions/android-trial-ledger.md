# Android trial decision ledger

These are trial decisions, not an Android launch approval or a change to Saiko
Next's ADR-001. Evidence and unresolved gates live in
[the research note](../research/android-trial.md).

## AND-001

- Date: 2026-10-28.
- Context: Saiko Next plans native Compose UI with portable persisted contracts;
  Taima gives that direction a concrete synthetic trial without editing Saiko.
- Decision: Keep Android UI native in the standalone `android/` project. Use
  Kotlin for the trial's app data path and make Swift JNI an optional probe.
- Consequences: Record/backup/CSV/catalogue goldens are the shared contract.
  Kotlin logic requires ongoing parity work. Swift reuse remains viable only
  after SDK size, runtime behaviour and target-device acceptance are considered.
  The broader Taima experiment does not expand Saiko's bounded UI-only trial.

## AND-002

- Date: 2026-10-28.
- Context: Both handwritten JNI and swift-java can call the same small Swift
  normalisation operation; Swift exceptions cannot unwind safely through C.
- Decision: Use an explicit JSON success/error envelope for this experiment.
  Keep generated and handwritten bindings side by side for measurements.
- Consequences: Boundary ownership and conversion costs are measurable without
  conflating an exception mapping policy with code generation. This probe does
  not settle generated mappings for arbitrary Swift throwing APIs or objects.

## AND-003

- Date: 2026-10-28.
- Context: BagStore stores JSON bodies alongside explicit indexed columns and
  small metadata tables. Room adds entities, a DAO, schema export and validation.
- Decision: Use plain SQLite in the trial app; keep Room in a comparison module
  using the same tables, WAL, transaction size and version-1-to-2 migration.
- Consequences: The app keeps direct control over portable documents and
  transactions. SQL correctness stays our responsibility. A bounded emulator
  write benchmark cannot establish general Room performance or phone behaviour.

## AND-004

- Date: 2026-10-28.
- Context: Collection privacy includes OCR inputs and metadata. ML Kit says image
  recognition is local but documents metrics and per-installation identifiers.
- Decision: Ship no OCR SDK or network permission in this trial. Prefer evaluating
  bundled Tesseract models next, with an accuracy corpus and network verification.
- Consequences: Manual entry works now. OCR accuracy, latency and integration
  remain open; ML Kit requires a separate explicit privacy decision. Do not send
  label images or collection records to a cloud OCR service.

## AND-005

- Date: 2026-10-28.
- Context: A separate branch is rebuilding Party.swift and party-content.json.
- Decision: Android reads the existing JSON as a sequential content preview;
  do not port selection, eligibility or deck flow logic.
- Consequences: Preview placeholders are displayed as content. The new game
  flow remains in Swift and Android game parity is intentionally unclaimed.

## AND-006

- Date: 2026-10-28.
- Context: A local release artifact needs repeatable signing without publication.
- Decision: Keep the trial keystore/password outside git with restrictive
  permissions. Document Obtainium's GitHub release route; publish nothing.
- Consequences: Preserve the signing identity for in-place trial updates. An
  actual Obtainium install and a physical-device update remain separate gates.

## AND-007

- Date: 2026-10-28.
- Context: The maintainer selected full Android parity using the shared Swift
  core, superseding the Kotlin-domain trial in AND-001 and preview in AND-005.
- Decision: Ship hand-written JNI with one versioned UTF-8 JSON operation
  dispatcher and explicit success/error envelopes. Swift owns inventory,
  calculations, catalogue matching, label parsing, games, CSV and archives.
  Kotlin owns Compose, SAF, image decoding, OCR and explicit SQLite storage.
- Consequences: No generated binding pipeline, Swift object lifetime bridge or
  Swift exceptions across JNI. Game state and settings round-trip as documents.
  Resource paths and content language are passed explicitly and scoped with
  TaskLocal, leaving iOS bundle and language selection as the default.
  Trial Kotlin domain modules remain test/reference material, not app dependencies.

## AND-008

- Date: 2026-10-28.
- Context: Non-Darwin Foundation does not interpret string-catalog plurals.
- Decision: Return form identifiers and numeric counts. Android uses resource
  plurals and formats metrics locally. Static core text resolves through Android
  resources generated from existing catalogues; party content remains bilingual
  domain content. Native prompt wrappers use Android format resources.
- Consequences: One jar and multiple jars use Android quantity selection in
  English and Dutch. iOS counted labels and string catalogues are unchanged.

## AND-009

- Date: 2026-10-28.
- Context: The maintainer requires offline OCR without Play services.
- Decision: Bundle Tesseract4Android 4.9.0 standard and tessdata_fast 4.1.0
  English/Dutch models. Use the system camera intent and photo picker. No direct
  camera permission is necessary. No image or OCR text is transmitted.
- Consequences: APK includes models. OCR output is reviewed before saving.
  INTERNET is present solely for explicitly requested public catalogue downloads;
  no automatic update request, analytics or collection upload is implemented.
  OCR accuracy and dependency/network behaviour still require device evidence.

## AND-010

- Date: 2026-10-28.
- Context: Android must preserve BagStore records and iOS archive bytes.
- Decision: Keep explicit SQLite tables and JSON documents, with the trial's
  version-1-to-2 migration. Swift reads/writes both archive generations and CSV;
  Android stages SAF streams privately and restores rows/photos transactionally.
- Consequences: Imported image bytes are preserved. Newly selected Android image
  bytes use the archive's opaque .heic filename convention; platform image readers
  must detect the actual encoding. Cross-device image rendering is an explicit
  acceptance gate, separate from opaque byte preservation.

The portable localization bundle accessor uses `Bundle.main` outside Darwin:
Foundation's English key fallback must not evaluate SwiftPM's generated resource
accessor on Android, where it can trap before Android formats the key. Darwin
still uses `Bundle.module`; iOS string-catalog and plural behaviour are unchanged.
Party JSON is loaded through the explicit resource directory on Android.

## AND-011

- Date: 2026-10-29.
- Context: The user asked for a fully usable Android version at parity with the
  iPhone app, distributed without the Play Store.
- Decision: Ship one app on the shared Swift core over JNI, with coarse JSON
  operations. Kotlin holds only UI, platform glue and storage. The release APK is
  arm64-v8a only, signed with a local key outside the repo, and attached to the
  same GitHub release as the IPA for Obtainium.
- Consequences: Core features reach both apps at once, and backups are
  byte-compatible. The APK is about 41 MB, mostly the Swift and Foundation ICU
  runtime. Emulator-only ABIs stay in debug builds. Losing the signing key breaks
  updates, so it must be backed up. TalkBack speech, the Obtainium update path and
  some deep flows still need device testing.

