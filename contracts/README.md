# Android trial contract checks

`golden/` is a synthetic interchange corpus, consumed independently by Swift
and Kotlin. It is intentionally small. No user archive or simulator database
was read. Regeneration is explicit and reviewable, not part of normal tests.

- Record/manifest JSON: sorted keys, UTF-8, no whitespace, unescaped slashes,
  UTC second-precision ISO 8601 dates. This fixture convention is not a general
  canonical JSON specification. Swift's typed record drops unknown fields;
  Kotlin's JSON documents retain them, which needs a product compatibility rule.
- Backup format 2: `TAIMABK2`, flag, optional salt/PBKDF2 iteration count,
  big-endian length-prefixed manifest/photo records, optional AES-256-GCM.
  See the golden README for deterministic test-only crypto values. Real exports
  use secure randomness. The synthetic `.heic` bytes are opaque test data.
- CSV: English wire headers/form labels and invariant decimal syntax, quoted
  fields and formula protection. Import is a lossy collection projection with
  new IDs, empty stock and no restored usage history. It is not a backup.
- Catalogue: version/format/path constraints and content SHA-256 verification.
- SQLite: BagStore tables use JSON `body` plus `id` and reference-epoch
  `collected_on` columns, producer keys and wishlist migration 1 to 2. Android
  photo BLOBs are an auxiliary table. No SQLite-file interchange was tested.

Run the commands in `android/README.md`. All three default locales (`nl_NL`,
`de_DE`, `en_US`) use the same bytes. Amsterdam's spring DST transition checks
12:00-to-12:00 across a 23-hour day. These tests do not cover every timezone,
malformed input, optional field, archive size or encoding from older app versions.
