# Taima Android
<!-- impeccable:product-schema 1 -->

## Platform
android

## Stack
Kotlin, Jetpack Compose, Material 3, explicit SQLite and a versioned JSON/JNI boundary to shared Swift TaimaCore.

## Users
Adults who keep a private collection of cannabis bought in the Dutch regulated experiment.

## Product Purpose
Keep an adult’s collection, stash and notes privately on Android, with iPhone feature parity as the acceptance target.

## Capabilities and Constraints
Swift owns all domain calculations, inventory mutations, label parsing, catalogue matching, games, archive and CSV codecs. Kotlin owns native screens, SQLite documents, OCR and platform I/O. Bundled English/Dutch OCR requires no Play services. INTERNET is used only for explicitly requested public catalogue updates. No account, analytics, CI, paid service or publication. Synthetic data only during evaluation. Source coverage, gaps and outstanding runtime acceptance are recorded in ../docs/evidence/android/README.md.

## Brand Commitments
The maintainer specified neutral surfaces, green #1B7A47 as the single accent, calm typography and rounded or tabular numbers, and native Android conventions. The existing Taima iOS product is the behavioral reference, not a UI template.

## Evidence on Hand
`../contracts/golden`, retained `../docs/evidence/android-trial`, and current `../docs/evidence/android`. Retained trial results do not verify new source. Rendered acceptance remains separate from compilation, unit and contract checks.
