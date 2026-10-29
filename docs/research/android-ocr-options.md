# Android label OCR options

2026-10-28. Research only. No OCR SDK, camera permission or internet permission
was added to the trial app. No image, identifier or collection was uploaded.

| Option | Image/text path | Other network traffic | Trial decision |
| --- | --- | --- | --- |
| Manual entry | User types locally | None required | Implemented |
| Tesseract, bundled `eng`/`nld` traineddata | Local native engine and files | None required by the proposed bundled design; optional model downloads would disclose IP/device request metadata to the chosen host | Preferred next experiment, not integrated or packet-capture verified |
| ML Kit Text Recognition v2, bundled | Google says inputs and OCR outputs stay on device | ML Kit terms document update/configuration contacts and performance/utilisation metrics. Android disclosure lists device/app information, per-install identifiers, timing, configuration, input/output sizes and event/error codes, including bundled features | Cannot call this zero-network OCR |
| ML Kit, Play Services thin model | Same local recognition once ready | Adds dynamic model download/Play Services dependency to the disclosed traffic; unavailable models affect first use offline | Poorer offline fit |
| Cloud OCR API | Label image or crop leaves device; returned text may include identifiers | Provider sees image content, IP and request metadata; retention/credentials/cost depend on provider | Outside this trial and incompatible with automatic private-collection handling |

Tesseract is an inference about an integration we control, not an assurance about
every Android wrapper. Audit the exact wrapper, native libraries and models,
bundle them locally, omit network permission, and test with network capture.
Evaluate synthetic labels with rotation, blur, glare, Dutch decimals, upper bounds
and ambiguous product codes. Require review before OCR values become records.
Do not infer product identity from text confidence or silently enrich a collection.

ML Kit's on-device recognition claim does not remove its separate metrics
behaviour. Disabling the app's network permission also does not establish that
an external Play Services process cannot communicate. The bundled variant avoids
that model-download dependency but does not erase the published disclosures.

Primary sources, accessed 2026-10-28:

- [Tesseract engine and traineddata installation](https://tesseract-ocr.github.io/tessdoc/Installation.html).
- [ML Kit text recognition Android setup, bundled versus thin](https://developers.google.com/ml-kit/vision/text-recognition/v2/android).
- [ML Kit terms and privacy](https://developers.google.com/ml-kit/terms).
- [ML Kit Android data disclosure](https://developers.google.com/ml-kit/android-data-disclosure).
