# Synthetic portable contract corpus

These files contain made-up records, never a user collection. Both `ContractGoldenTests` (Swift) and `ContractTest` (Kotlin JVM), plus the Android instrumented test, consume them.

`record.json` and `manifest.json` use sorted keys, UTF-8, no whitespace, no escaped slashes, and second-precision ISO 8601 UTC dates. `collection.csv` has a final LF and RFC 4180 quoting and formula-cell protection. Plain format-2 backup bytes are deterministic for this manifest. The encrypted golden uses salt bytes 0...15, nonce bytes 16...27, 210,000 PBKDF2-HMAC-SHA256 rounds, passphrase `taima-é-🌿`, and AES-256-GCM. This fixed randomness is **test data only**. Product writes use secure random salt and nonce.

To deliberately regenerate the archive, record and CSV goldens using the Apple implementation:

```sh
~/.t3/tools/saiko-load-gate/load-gate.sh && TAIMA_REGENERATE_GOLDENS=1 swift test --package-path Packages/TaimaCore --filter ContractGoldenTests
```

Review every byte change. Matching this corpus proves these cases, not every valid JSON representation or every malformed input. JSON object key order and numeric spelling are not a general canonicalization standard. Encrypted product exports intentionally differ because their salt and nonce are random.
