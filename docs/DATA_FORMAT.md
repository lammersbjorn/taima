# Taima data formats

Taima keeps everything on the iPhone. These are the formats it reads and writes, so your data is never locked in.

## Backup (`.taimabackup`, format 2)

A stream of records, written and read one at a time.

| Bytes | Content |
| --- | --- |
| 8 | `TAIMABK2` |
| 1 | Mode: 0 plain, 1 encrypted |
| 16 + 4 | Encrypted only: salt, then the PBKDF2 iteration count (big-endian UInt32) |
| repeated | Record: payload length (big-endian UInt32), then the payload |

A plain payload is a kind byte, then the name length (big-endian UInt16), the UTF-8 name and the data. Kind 1 is `manifest.json` and comes first. Kind 2 is one photo, named like `UUID.heic`.

An encrypted payload is the plain payload sealed with AES-256-GCM, in combined form (nonce, ciphertext, tag). The key is PBKDF2-HMAC-SHA256 of the passphrase with the salt, by default 210,000 iterations.

The manifest holds `version` (2), `exportedAt`, `bags`, `wishlist` and `producerKeys` (the learned growers). A bag is the `Bag` record in `Packages/TaimaCore/Sources/TaimaCore/Bag.swift`. Its fields are optional except the identity, name, dates, notes and recognised text, so older backups keep decoding.

Version 1 backups (`.taima.json`, a single JSON object with base64 photos) still restore.

## Spreadsheet (CSV)

Export writes one row per bag with these columns:

`name, producer, form, type, thc, cbd, grams, stock, remaining_g, harvested, packed, collected, price_eur, shop, town, score_of_10, effects, downsides, flavours, sessions, product_id, sku, ean, notes, thc_mg_each`

- **Forms:** `Bag`, `Prerolls`, `Jar`, `Hash`, `Rosin` or `Edibles`.
- **Edibles:** `grams` and `remaining_g` hold pieces, and `thc_mg_each` is the THC per piece in milligrams. The column is empty for everything else.
- **Dates:** `YYYY-MM-DD`.
- **Tags:** effects, downsides and flavours are separated by `; `.
- **Formula cells:** text starting with `=`, `+`, `-` or `@` gets a leading `'`, so spreadsheets don't run it as a formula.

Import reads the same columns by header name, case-insensitive, and ignores columns it doesn't know. Only `name` is required. A `rating` column (1 to 5) also works. Imported bags arrive as empty bags without photos or sessions.
