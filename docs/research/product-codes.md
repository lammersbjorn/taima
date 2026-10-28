# Product codes on Dutch experiment cannabis labels

Research checked on 27 October 2026. Scope: the example label transcriptions below and publicly accessible primary sources. **Verified** means checked against the supplied strings, a retrieved document, or an identified primary source. **Inference** means a plausible interpretation without a published mapping. **Unresolved** means the evidence did not establish the answer.

The PRD strings contain UUIDv4 identifiers, not decodable product descriptions. Justid operates the experiment's government track-and-trace system, whose underlying records have restricted access. All four EANs pass their check-digit calculation, but neither the registered company-prefix boundary nor its licensee was verified. Both supplied leaflet links ultimately provide generic cannabis information. Taima can retain and compare these identifiers offline; strain, potency, dates and weight should come from the printed label or a separately verified local catalogue.

## 1. PRD identifiers

### What the bytes establish

**Verified, local calculation.** Removing `PRD-` from each supplied value leaves a valid UUID. Every third group starts with `4`, the version nibble. Every fourth group starts with `8`, `9` or `a`, whose two highest bits are `10`, the IETF UUID variant, also commonly called the RFC 4122 variant.

| Supplied identifier | Version | First variant nibble |
| --- | --- | --- |
| `PRD-a0000005-0000-4000-a000-000000000006` | 4 | `a` = `1010` |
| `PRD-a0000000-0000-4000-8000-000000000001` | 4 | `8` = `1000` |
| `PRD-a0000003-0000-4000-a000-000000000004` | 4 | `a` = `1010` |
| `PRD-a0000001-0000-4000-a000-000000000002` | 4 | `a` = `1010` |
| `PRD-a0000004-0000-4000-a000-000000000005` | 4 | `a` = `1010` |
| `PRD-a0000002-0000-4000-a000-000000000003` (FYTA label) | 4 | `a` = `1010` |
| `PRD-a0000006-0000-4000-9000-000000000007` (Holigram label) | 4 | `9` = `1001` |

**Verified, standard.** UUIDv4 specifies 122 random or pseudorandom bits plus four version bits and two variant bits. It defines no timestamp, sequence, grower, product type or device-address fields. The samples therefore look like random identifiers, rather than timestamp-bearing UUID versions 1, 6 or 7. Seven samples cannot establish the generator's randomness or prove that its implementation follows the standard internally. There is no supported way to recover product attributes from these values. See [RFC 9562, sections 4.1, 4.2 and 5.4](https://www.rfc-editor.org/rfc/rfc9562.html#section-5.4).

**Inference.** `PRD` plausibly labels a product-record identifier. It is outside the UUID and has no meaning defined by the UUID standard. The supplied observations establish that these QR payloads are exactly the printed PRD strings. A QR or DataMatrix symbol carrying that string adds no hidden product fields, and the string is not a web address. No public specification explicitly assigning the literal `PRD-` prefix was located.

### Which system uses them

**Verified.** The responsible operator is the **Justitiële Informatiedienst (Justid), within the Ministry of Justice and Security**. Justid's announcement of 14 April 2025 identifies its Track en Trace solution and explains that APIs connect growers' systems and coffeeshop tills. This establishes the government system; it does not establish that the identifiers come from a commercial platform such as Metrc. See [Justid's API announcement](https://www.justid.nl/actueel/nieuws/2025/04/14/track-en-trace-koppeling-zorgt-voor-efficientere-invoer-gegevens-in-experiment-gesloten-coffeeshopketen).

**Verified, regulatory record.** The [2022 amendment, Staatscourant 2022, 4952](https://zoek.officielebekendmakingen.nl/stcrt-2022-4952.html) explicitly makes the identification marking one generated through the track-and-trace system. Annex IV defines `PRODUCTNUMMER` as a nationally unique identifier of a packaged final product, separately from the batch identifier. Its product record links product type, batch number(s), cannabis weight, quality, position and registration/mutation time. Coffeeshops update the product record at sale. These are associated database fields, not fields encoded in the UUID. The [current regulation, effective 22 March 2025](https://wetten.overheid.nl/BWBR0043749/2025-03-22), retains this structure in article 15 and Annex IV.

**Inference, strongly supported by the labels and regulation.** The scanned PRD values are those packaged-product identifiers. Treat a repeated PRD as evidence of the same labelled package, useful for duplicate detection. Different packages of the same strain can have different PRDs. Neither a matching PRD nor valid UUID syntax proves authenticity, since a label can be copied.

### Public lookup availability

**Verified.** Article 33(2)-(3) of the [current Besluit, effective 5 April 2025](https://wetten.overheid.nl/BWBR0043738/2025-04-05#Paragraaf6_Artikel33) requires the ministers' electronic system and restricts the information behind the identifier to the relevant grower, coffeeshop and authorised supervisory bodies. The original [Staatsblad 2020, 185](https://zoek.officielebekendmakingen.nl/stb-2020-185.html) contains the same access restriction. A publicly described API for participating businesses is consequently not evidence of a consumer API.

**Research result.** No official public PRD-to-product lookup or documented anonymous endpoint was found. No owner's PRD was submitted to a remote lookup, no endpoints were guessed, and no login was attempted. There was no official public example to fetch.

**Limited public alternative.** A search index exposed [Potspot's own PRD page for a different, already public Holigram code](https://www.potspot.nl/product-code/prd-2c04693c-d4d3-4290-8e40-c6e0bec46898), presenting a strain, grower and community information. The live page fetch timed out. This supports the existence of community-published mappings, not government-registry access, accuracy or coverage. None of the owner's PRDs was searched there. Such a service could only be an optional, unverified enrichment source.

## 2. EAN-13 / GTIN-13 structure and prefix ownership

### Licensee: not independently established

**Verified observation.** The owner reports these four codes on COG/Canadelaar bags. CanAdelaar's own site expands COG to **CanAdelaar Original Grow**, and its imprint names **CanAdelaar B.V.** See [CanAdelaar's COG page](https://www.canadelaar.com/en/coffeeshops) and [company imprint](https://www.canadelaar.com/en/imprint).

**Inference.** CanAdelaar B.V. is the likely business associated with these labels. **Unresolved:** an authoritative registry result establishing the licensee of `8721098`, or confirming that seven digits are the actual licensed company prefix, was not obtained. Do not present the label association as verified GS1 ownership.

GS1 company prefixes have variable lengths. In fact, these four strings share **nine** leading digits, `872109800`. Agreement on seven digits does not establish a seven-digit prefix boundary. A longer registered prefix would move the item-reference boundary. See [GS1's implementation guideline, section 25 on GTIN structure](https://ref.gs1.org/guidelines/tiig/).

### Digits and check digits

**Verified, local calculation.** All four are 13 numeric digits and pass the standard modulo-10 check. The split below is conditional on the proposed seven-digit prefix being correct.

| EAN-13 | Assumed company prefix | Remaining five-digit item reference | Check digit, verified |
| --- | --- | --- | --- |
| `8721098003880` | `8721098` | `00388` | `0` |
| `8721098004528` | `8721098` | `00452` | `8` |
| `8721098002081` | `8721098` | `00208` | `1` |
| `8721098003774` | `8721098` | `00377` | `4` |

For a nine-digit company prefix, the item references would instead be `388`, `452`, `208` and `377`. Under either split, the differing suffixes look like catalogue numbers. Their order does not establish harvest dates, strengths, sizes or strain names.

The final digit is calculated from the preceding twelve: multiply their digits alternately by 1 and 3, add, and choose the digit that brings the sum to a multiple of ten. This catches many transcription errors; it does not verify a GS1 allocation or product identity. See [GS1 Nederland's check-digit guidance](https://www.gs1.nl/kennisbank/gs1-barcodes-ean-gtin/controlecijfer-berekenen/).

**Verified, standard.** GS1 describes identification numbers as non-significant references to database records. Product characteristics are linked data, not a standard interpretation of the item-reference digits. A GTIN identifies a trade item, rather than serialising an individual bag. `870`-`879` are allocated to GS1 Netherlands; this identifies the issuing GS1 organisation, not the product's cultivation country. See [GS1 on linked product information](https://support.gs1.org/support/solutions/articles/43000734469-what-kind-of-information-is-linked-to-the-gs1-identification-key-) and [GS1's prefix allocation list](https://www.gs1.org/standards/id-keys/company-prefix).

### Verified by GS1 and public product data

**Verified service capability.** [Verified by GS1](https://www.gs1.nl/producten-services/codes-verifieren/verified-by-gs1/) is the official public route for checking a full GTIN. GS1 says results provide the assigning company's information and, where supplied, corresponding product data. Public use is limited to 30 queries daily. See [GS1's service explanation](https://support.gs1.org/support/solutions/articles/43000734070-how-do-i-check-if-a-gs1-gtin-is-valid-).

**Access limitation, not a negative database result.** The global results page returned HTTP 403. The accessible GS1 Nederland page embeds a global lookup iframe, which also returned HTTP 403. No result was obtained for a sample GTIN, and there was no attempt to bypass that restriction. Exact web searches for `8721098003880` and `8721098004528` produced no useful product records. The other two were checked locally, not remotely. This does not establish that GS1 lacks records for them.

GS1 also states that the global Verified by GS1 service has no public API; member organisations may offer additional interfaces. Do not base an offline app on an assumed free enrichment endpoint. See [GS1's architecture finding on its registry platform](https://ref.gs1.org/architecture/findings/integrity-and-security/).

## 3. The two leaflet links

### Aardachtig: direct government PDF

**Verified retrieval.** The exact [open.overheid.nl URL printed on the label](https://open.overheid.nl/documenten/75c79be3-b473-4c6c-9d79-736e7c30cfb7/file) was fetched once. It returned HTTP 200, `application/pdf`, 284,560 bytes, two pages, titled **Bijsluiter Cannabis (hasj en wiet)**. Both pages were text-extracted and visually inspected. SHA-256: `e54d92cefd0c5171e3cb6a4137a0114eec06a510603fc23501e385469049c5a8`.

It covers possible adverse effects, groups advised against use, smoking/vaporising/eating, harm-reduction advice, help contacts and an explanation of the experiment. It points readers to the packaging for THC strength. It contains no strain, PRD, EAN, batch, grower-specific analysis or certificate of analysis.

**Classification: generic, experiment-wide information.** The document URL's UUID identifies a document, not the bag. This leaflet cannot identify Aardachtig on its own; other growers can use the same government document.

### Holigram: dynamic link to a grower-hosted generic leaflet

**Verified retrieval.** [The supplied `view.page/yIS1x0` URL](https://view.page/yIS1x0) was fetched once. It returned HTTP 200 and a JavaScript application shell, not a PDF or readable leaflet. Its linked [public JavaScript bundle](https://view.page/static/js/main.8d36b1ee.js) explicitly constructs the page-data route. A single read of [that route for this link](https://view.page/api/qr-code?uId=yIS1x0) returned an active, non-password-protected URL entry pointing to `https://www.holigram.nl/bijsluiter/`. No application JavaScript or analytics request was executed.

**Verified contents.** The [Holigram destination](https://www.holigram.nl/bijsluiter/) was then fetched once. It reproduces the government's generic cannabis leaflet in HTML, with the same main subjects listed above, an information animation and Dutch/English PDF links. The page labels its version `v2023.10`, last updated 11 October 2023, and directs readers to Rijksoverheid for the current version. No product code, strain-specific result or batch certificate appears in the retrieved leaflet. The linked PDFs and video were not separately downloaded.

**Classification: grower-specific destination, generic leaflet content.** `yIS1x0` is a hosted-link identifier, not a supported product decoder. Its target can change independently of the printed QR code; this finding describes its destination on the research date.

**Verified regulatory distinction.** Article 9 of the [current regulation](https://wetten.overheid.nl/BWBR0043749/2025-03-22#Paragraaf3_Artikel9) requires a QR code labelled “Bijsluiter” providing the prescribed information and animation. It permits sharing the code with the optional product-information QR under article 8(2), provided the leaflet comes first. Therefore some future leaflet destinations could also contain product/laboratory information. The PRD tracking code, a generic leaflet link and an optional product-information link should remain separate concepts in Taima.

## 4. Code 128 SKUs and phone numbers

### SKU formats

**Verified observation.** The supplied payloads are `LB-CALIMIX-05` and `PHMX-FLW-50G`. Neither is a GTIN. Code 128 is a data carrier; it does not define the meanings of these hyphen-separated tokens. GS1-128 is a specific subset using FNC1 and GS1 Application Identifiers, which these strings do not demonstrate. See [GS1's description of the distinction](https://ref.gs1.org/standards/genspecs/24.0.0/), section 5.4.3.7.

**Inference only, with no grower-published dictionary found:**

- `LB-CALIMIX-05`: `LB` could identify a grower, brand or product line; `CALIMIX` looks like a product/mix mnemonic. `05` is ambiguous. It could represent 0.5 g, 5 g, a count or a catalogue variant. None is established.
- `PHMX-FLW-50G`: `PHMX` could be a product/strain mnemonic or a company/line code. `FLW` plausibly abbreviates flower. `50G` literally suggests a gram-denominated size, but it could mean 50 g or use an internal decimal convention. Do not turn it automatically into 5.0 g or 50 g.

The decree's article 29(1) limits consumer packaging units to 5 g. A literal 50 g interpretation would therefore conflict with an ordinary compliant consumer bag. That is a reason to inspect the printed weight and packaging context, not proof that `50G` means 5.0 g. These could also be logistics SKUs or transcription errors. No evidence establishes which token position is a grower prefix across both formats.

### Phones as local grower hints

**Verified normalisation, label attribution supplied by the owner:**

| Printed phone | Normalised Dutch international form | Label association |
| --- | --- | --- |
| `+31 181 72 91 31` | `+31181729131` | COG / CanAdelaar |
| `085-2738149` | `+31852738149` | Aardachtig |
| `0416-237000` | `+31416237000` | FYTA |

FYTA independently lists `0416 237 000` on its [official contact page](https://fyta.group/contact/). The other two number-to-grower mappings were not independently confirmed on the accessible official contact pages. They remain owner-observed label associations. Full-number matches against a curated local table can suggest the grower offline; an area code alone cannot. Numbers may change, and labels may also contain coffeeshop contact details, so preserve confirmation and provenance rather than treating any phone as an infallible producer ID.

## 5. What Taima can derive, and what a request reveals

The following are implementation recommendations based on the evidence above, not changes made to the app.

**Reliable offline operations:**

- Read and preserve the exact payload and barcode symbology. Recognise a PRD-shaped UUID, inspect its version/variant, and compare it locally with previously saved identifiers.
- Validate a GTIN-13 check digit, preserve leading zeros, and match a full GTIN to an already verified bundled or user-confirmed local record. A valid checksum alone does not authenticate a product.
- Recognise and store a leaflet URL without opening it. A known government leaflet can be identified by its exact URL; the URL alone cannot establish the bag's producer.
- Normalise phone numbers and use confirmed local grower associations. Treat shared EAN digits and SKU prefixes as learned hints, not registry facts.
- Read strain, THC/CBD, weight, harvest date, packing date and producer from label text on-device, with user correction. None of these sample PRDs or GTIN suffixes independently encodes those values.

**Network-dependent enrichment and disclosure:**

| Lookup | Potential information | What the recipient could learn from the request |
| --- | --- | --- |
| Official track-and-trace | Package, batch, quality and chain records | The exact package identifier, potentially linkable to its chain and sale record. No public consumer access was found. |
| Verified by GS1 / GTIN search | Registered licensee and possibly product name, brand or size | The exact trade item being queried, plus request metadata. It does not by itself identify a particular bag. |
| Community PRD lookup | Previously published strain/grower mapping, if any | The exact package identifier and interest in that package. Coverage and accuracy remain unverified. |
| Government leaflet URL | Generic information | Interest in cannabis information. This shared document does not name a specific bag, strain or grower. |
| `view.page/yIS1x0` and its target | Hosted-link destination and grower leaflet | The hosted-link identifier, then interest in Holigram. The intermediary and destination both receive requests. |
| Remote SKU, phone or label-photo search | Possible producer/catalogue match | A product/producer hint, or substantially more of the collection if images or multiple records are sent. |

**Privacy inference.** A lookup is not proof of ownership, but a service can infer possession or interest from an identifier and correlate repeated requests using IP addresses, cookies, account state or timing. Exact PRDs disclose more than generic leaflet links. HTTPS protects requests in transit; the receiving service still sees the requested identifier. The retrieved `view.page` shell includes a Cloudflare analytics beacon, and its public bundle contains a separate scan-analytics call, reinforcing that opening a hosted QR can involve more than the final document host.

**Recommendation for the stated offline-only contract.** Make no automatic network request when scanning, saving, opening a bag or viewing a stored QR. Do not preload web views, resolve hosted links, attach PRDs to analytics, or upload a collection for enrichment. Use a catalogue distributed independently of the person's scans, or locally imported verified mappings. If a future product decision permits external lookups, make each one a deliberate per-item action explaining the exact identifier and recipient. A consent prompt would not itself satisfy a strict requirement that no collection identifiers leave the device.

## Retrieval limits and cleanup

Both supplied leaflet URLs were requested once each. For the JavaScript-only Holigram link, one linked script, its explicitly referenced public page-data route and the returned public destination were fetched to resolve the leaflet. No private endpoints, authentication, guessed PRD routes or bulk queries were used. No downloaded code was executed. Source downloads, extracted text and PDF page renders were kept in a dedicated temporary directory and deleted after the note was checked. Only this Markdown file was created by this research task; no commit was made.
