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
