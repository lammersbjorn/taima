# Label parser evaluation

Measured on 28 October 2026, against the same 37 cases before and after this change.

- Present-value accuracy: **206/237 (86.9%) → 228/237 (96.2%)**.
- Exact field accuracy, including correct absence: **553/586 (94.4%) → 577/586 (98.5%)**.
- False positives: **2 → 0**, both expiry dates previously treated as harvest/packing dates.

The corpus contains all 13 retained `Fixtures.swift` / `WebFixtures.swift` labels, 10 fresh on-device Vision captures of the owner's label photos, and 14 synthetic format/candidate cases. The fresh captures overlap the retained labels; these numbers measure this regression corpus, not independent products or expected accuracy in the wild. The unrelated Stats screenshot was excluded. The Zunami screenshot is included, with its status-bar text, so its previous false 50 g reading is tested.

## Expectations and scoring

`Tests/TaimaCoreTests/LabelFixtures/photos.json` and `formats.json` write down every expected field. `LabelEvaluationTests.swift` supplies the retained fixture expectations, including the three published labels. `—` means the parser should leave the field empty. `producerKeys` compares a sorted set of normalized identifiers from the supplied OCR, not verified company ownership. Dates compare civil days using the app's calendar. Potencies compare the value, upper-bound flag and range endpoints; separate tests check THCA/total-THC basis.

Three fields on each of the two damaged Amnesia Haze captures (harvest, packing and product ID) are explicitly unscored because their truth cannot be established reliably from the photo. Every other absence counts, so an invented value fails. All fixture PRDs, including the previously retained ones, are synthetic. Deliberate OCR mistakes, code disagreements and truncated identifiers remain in the retained fixtures.

| Field | Present before | Present after | Exact before | Exact after |
| --- | ---: | ---: | ---: | ---: |
| name | 33/37 | 35/37 | 33/37 | 35/37 |
| producer | 13/14 | 14/14 | 36/37 | 37/37 |
| strainType | 2/2 | 2/2 | 37/37 | 37/37 |
| thc | 23/28 | 27/28 | 32/37 | 36/37 |
| cbd | 20/23 | 22/23 | 34/37 | 36/37 |
| grams | 23/28 | 25/28 | 32/37 | 34/37 |
| harvestedOn | 19/23 | 21/23 | 30/35 | 33/35 |
| packedOn | 21/24 | 24/24 | 31/35 | 35/35 |
| bestBeforeOn | 0/2 | 2/2 | 35/37 | 37/37 |
| productID | 20/20 | 20/20 | 35/35 | 35/35 |
| sku | 8/9 | 9/9 | 36/37 | 37/37 |
| ean | 2/2 | 2/2 | 37/37 | 37/37 |
| leafletURL | 2/2 | 2/2 | 37/37 | 37/37 |
| form | 1/2 | 2/2 | 36/37 | 37/37 |
| unitCount | 1/2 | 2/2 | 36/37 | 37/37 |
| producerKeys | 18/19 | 19/19 | 36/37 | 37/37 |

Run from `Packages/TaimaCore`:

```sh
swift test --filter labelEvaluationReport
swift test
```

The report prints every miss and per-field numerator/denominator. The test rejects new mismatches; its nine explicit unresolved entries remain visible in the report. Baseline numbers came from the parser at `e6342c165580a56100b606695ed10a5685e2ca65` before production edits, after the corpus and expectations were added. Existing behavior assertions were retained; only product identifiers were anonymized and the Zunami input was moved into reusable fixtures.

## Remaining misses

- Pheno Hunt's name reads `Miix`, with no alternative from Vision (two captures).
- Its harvest year reads `202€`, with no alternative (two captures).
- Damaged Amnesia Haze weight reads `S pr` (two captures).
- The small Aardachtig jar has `17 89%`, `C80%`, and `5gi`; row alignment and damaged glyphs prevent three values being recovered safely.

The fresh macOS Vision run returned one candidate for each observation, even with `topCandidates(3)`. Candidate rescue, close 25%/26% conflicts, and joint label/value alternatives are therefore covered with synthetic OCR cases, not claimed as improvements observed in these photos.

## API and UI handoff

`RecognizedLine` accepts optional `confidence` and up to two `RecognizedCandidate` alternatives. Existing initializers and old Codable text/box fixtures keep working. `LabelReading.confidence[LabelField]` holds `FieldConfidence`: `source` (`ocr`, `barcode`, `inferred`), `ocrConfidence`, pattern `specificity`, `usedAlternative`, `isAmbiguous`, frame-vote `agreement`, and a bounded `score`. These are heuristic evidence scores, not calibrated probabilities. Missing OCR confidence stays unknown and lowers the score. Barcode evidence is 0.99; inferred SKU weight remains doubtful. `needsReview` is true below 0.75 or when ambiguous.

Confidence follows the selected value through `LabelFusion` and `merged(withBack:)`; missing fields do not count as disagreeing votes. Alternatives are hypotheses from one observation, never extra frame votes. Valid competing numbers retain the primary candidate and flag ambiguity. Fusion keeps majority voting, stable earliest ties, and longer names on ties. It retains the strongest evidence belonging to the winning value and reduces its score by its vote share.

The app should carry the confidence map into its draft, flag `needsReview` (and missing evidence), and remove field evidence after a manual edit. The current draft UI still uses its existing detected-field marks; confidence badges are not added here. Camera completion still measures field coverage, not confidence.

`LabelReading.bestBeforeOn` / `LabelField.bestBeforeOn` hold THT or “Houdbaar tot” separately. The app needs a distinct expiry control/storage field to display or persist it; never map it to `packedOn`.

`Potency.lowerBound` preserves a printed range, with the existing `percent` storing its upper endpoint. `Potency.basis` distinguishes `.thca` and `.totalTHC`; ordinary THC/CBD keep the existing nil default. These optional Codable additions read old backups. THCA is kept as printed, without chemical conversion or claiming it is total THC. UI should show the basis and full range (`Potency.label`), and choose explicitly whether upper endpoints are suitable for calculations. The editor preserves range/basis metadata on unchanged values; an explicit potency edit replaces it.

Printed/name weights take precedence over SKU hints. A decimal gram token such as `AB-FLW-0.5G` can supply a low-confidence inferred weight. `PHMX-FLW-50G` remains uninterpreted without a published decimal/unit mapping, as described in `research/product-codes.md`.

## Scanner verification and capture

`LabelScanner` forwards Vision confidence and up to three candidates. When the upright pass yields fewer than 20 characters, it tries 90° and 180°, keeps the most legible text pass, and preserves barcodes found in any pass. Work is bounded to three passes and checks cancellation between retries. Video and still images use the same path; normalized boxes stay in the selected text orientation.

The native smoke check exercises fallback call order, no retries on legible input, barcode retention, and real Vision over generated labels at 0°, 90° and 180°:

```sh
products=$(cd Packages/TaimaCore && swift build --show-bin-path)
xcrun swiftc -swift-version 6 -default-isolation MainActor \
  -I "$products" -L "$products" -lTaimaCore \
  App/Taima/LabelScanner.swift scripts/check-label-scanner.swift \
  -o /tmp/taima-label-scanner-check
/tmp/taima-label-scanner-check
```

This checks the macOS Vision path and compilation under MainActor defaults. A generic iOS build also passes; no physical iPhone or camera throughput acceptance is claimed.

To capture more local fixtures:

```sh
swift scripts/capture-label-fixtures.swift /tmp/captures.json <local photos...>
```

The script writes text, boxes, OCR evidence and barcode payloads, replacing PRDs with made-up identifiers while preserving truncated or malformed shapes. Review orphaned code fragments manually, write all expected values, and add only sanitized JSON to the corpus. Images are never copied into the repository. Neither capture nor parsing makes network requests.
