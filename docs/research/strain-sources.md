# Bundled strain sources

Reviewed 2026-10-28. The curated library contains **154 records**, including all
53 original records reviewed and 101 additions. These are independently written
factual records, not copied strain descriptions. Nothing here identifies or
authenticates the genetics, effects or strength of a particular bag.

## Reuse and licences

Only one external database is imported: **Kushy**. No new bulk database was added.
The other sources supply individual published facts: names, spelling variants,
reported parentage, breeder credit and broad indica/sativa leaning. Their prose,
photographs, reviews, lab figures, medical claims and catalogue arrangement are
excluded. No scraping or lookup code ships in the app.

| Source / publisher | Licence checked | Use and limits |
| --- | --- | --- |
| [Kushy cannabis-dataset](https://github.com/kushyapp/cannabis-dataset) | [MIT, copyright 2016-present Kushy](https://github.com/kushyapp/cannabis-dataset/blob/8b807c3dfc0aaa1e217fba4924b26ded0774d5aa/LICENSE) | Existing 2017-11-14 export in `strains.json`, unchanged. Effects, downsides, flavours and terpenes remain anecdotal tags. Descriptions and medical claims are excluded. Cross IDs are unreliable; default Hybrid types are not trusted. Curated type, lineage and breeder credit take precedence. |
| [Sensi Seeds](https://sensiseeds.com/en/), including White Label | No open-data licence on cited pages; treated as proprietary | Selected classic-strain facts, breeder history and disagreement checks. Original Skunk #1 is not credited to its present-day retailer as its inventor. |
| [Dutch Passion](https://dutch-passion.com/en/) | No open-data licence on cited pages; treated as proprietary | Individual Dutch classics and named modern hybrids. No secret parents inferred for The Ultimate, Banana Blaze or other undisclosed pedigrees. |
| [Green House Seed Co. / Strain Hunters](https://shop.greenhouseseeds.nl/) | No open-data licence on cited pages; treated as proprietary | Individual published crosses and broad leaning. Geographic parent names remain unresolved rather than being invented as cultivars. |
| [Amsterdam Genetics](https://www.amsterdamgenetics.com/) | Copyright notice; no open-data licence on cited pages | Individual structured parent/type facts for its own named releases. Contradictory Strawberry Glue leaning and Amazing Haze parent spelling are flagged. |
| [Serious Seeds](https://www.seriousseeds.com/), including inherited Magus strains | Copyright notice; no open-data licence on cited pages | Classic AK-47, Bubble Gum and individual releases. Warlock and Double Dutch retain Magus breeder credit. Bubble Gum is not assigned invented parents or a universal leaning. |
| [Barney's Farm](https://www.barneysfarm.com/) | Copyright notice; no open-data licence on cited pages | Individual named hybrids and published history. Product-summary/specification disagreements are retained as uncertainty, not silently reconciled. |
| [DNA Genetics](https://dnagenetics.com/) | Copyright notice; no open-data licence on cited pages | Kosher Kush, Chocolope, LA Confidential, 24K Gold, Strawberry Banana and Tangie facts. Selfing a cultivar does not establish its unknown original parents. |
| [Soma's Sacred Seeds](https://www.somaseeds.nl/) | No open-data licence on cited pages; treated as proprietary | Amnesia Haze identity and broad leaning; complex regional ancestry is not flattened into an invented pair of parents. |
| [Super Strains / Hy-Pro](https://superstrainsseeds.com/) | Copyright notice; no open-data licence on cited pages | Original Amnesia, distinct from Soma's Amnesia Haze; breeder's Enemy of the State / Nevil's Haze account is reported. |
| [Royal Queen Seeds](https://www.royalqueenseeds.com/) | Copyright notice; no open-data licence on cited pages | Individual product and history facts, including alternate accounts. Its Wedding Cake and other seed versions are not assumed identical to original cuts. |
| [Humboldt Seed Organization](https://www.humboldtseeds.net/) | Copyright notice; no open-data licence on cited pages | Chemdawg history and Bubba Kush uncertainty. This is not Humboldt Seed Company or Humboldt CSI. |
| [Mr. Nice](https://shop.mrnice.nl/) | No open-data licence on cited pages; treated as proprietary | Critical Mass credit and pedigree; G13 background and uncertainty, without repeating government-lab origin stories as facts. |
| [Sherbinskis](https://sherbinskis.com/) | Copyright notice; no open-data licence on cited pages | Gelato family, common ancestry, and Bacio #41 as a distinct named selection. |
| [Archive Seed Bank](https://archiveseedbank.com/) | Copyright notice; no open-data licence on cited pages | Do-Si-Dos: OGKB and Face Off OG BX1, not generic GSC. |
| [Terphogz](https://terphogz.com/) | Copyright notice; no open-data licence on cited pages | Original Z naming only. No legal article text or claim of trademark permission is reproduced. |
| [HENDRX Farm](https://www.hendrx.farm/) | No open-data licence on cited page; treated as proprietary | Its nursery's Tropicana Cookies parentage and classification. |
| [Theory Wellness](https://theorywellness.org/) | No open-data licence on cited page; treated as proprietary | Cultivator's Motorbreath parentage, leaning and reported Pisces credit. |
| [Seeds66](https://www.seeds66.com/) | No open-data licence on cited pages; treated as proprietary | Purple Kush selection facts. Historical Snow White facts are attributed to Nirvana's syndicated breeder record; a live original Nirvana product page was not retrievable. No Snow White parents were added. |
| [Pure Sativa](https://www.puresativa.com/) | No open-data licence on cited page; treated as proprietary | Attributed historical Flying Dutchmen Original Haze record, explicitly supplied by the breeder. Name and sativa classification only; exact ancestry omitted. |

The absence of an open licence is **not** a grant to copy a website or extract its
database. These limited factual transcriptions follow the task's permitted
scope; they do not relicense the source text or assert rights to a breeder's
branding. No whole-project licence is introduced by this change. For Kushy,
retain [the complete MIT notice](../../App/Taima/Resources/Licenses/Kushy-MIT.txt)
in source distributions and the app bundle. Its notice was checked at upstream
commit `8b807c3dfc0aaa1e217fba4924b26ded0774d5aa`; this does not claim the existing
2017 generated JSON was rebuilt from that commit.

## Candidates rejected

| Candidate | Licence / rights evidence | Decision |
| --- | --- | --- |
| [Loyal9 grow_data](https://github.com/Loyal9-Elements/grow_data) | [MIT file](https://github.com/Loyal9-Elements/grow_data/blob/main/LICENSE), copyright 2025 Shannon Goddard / Loyal9. README identifies scraped Wikileaf content. | No import. The repository licence alone does not demonstrate the upstream site's permission to redistribute descriptions or its database. |
| [Cannabis Intelligence Database / ci-strains-pro](https://github.com/Shannon-Goddard/ci-strains-pro) | [Data-specific CC BY 4.0 licence](https://github.com/Shannon-Goddard/ci-strains-pro/blob/main/DATA_LICENSE.md), distinct from the software licence. [CC BY 4.0 terms](https://creativecommons.org/licenses/by/4.0/) permit commercial adaptation with attribution and change notices. | Potentially compatible licence, but no import: archived third-party pages and AI extraction do not establish upstream redistribution rights or resolve cultivar/version ambiguity. Needs an upstream provenance audit before adoption. |
| [The Cannabis API](https://github.com/Piyush-Bhor/The_Cannabis_API) | README advertises MIT for the API and identifies Kaggle `cannabis.csv` as the input. A data-specific upstream permission chain was not established. | No import. API code licensing is insufficient evidence for a republished dataset. No assumption that a Kaggle upload licenses its upstream descriptions. |
| [SeedFinder.eu](https://seedfinder.eu/en/legal-notice) | Legal notice reserves rights in text, photographs and databases and requires permission for reuse. | No database, genealogy graph or descriptions imported. Do not assume an old community site has a Creative Commons licence. |
| [Leafly](https://www.leafly.com/info/terms-of-use), Wikileaf and mirrors of their strain descriptions | Leafly terms reserve content rights; no verified open-data redistribution grant for these databases was established. | No import or copying of prose, ratings, reviews or terpene tables. A permissively licensed scraper does not change this. |
| [CanAdelaar](https://www.canadelaar.com/en/coffeeshops) and [Holigram](https://holigram.nl/) public grower pages | No open-data licence. Holigram's full catalogue is behind its B2B portal. | Context for Dutch experiment priorities only; no login, private catalogue extraction or invented current availability claim. A named seed strain is not proof of the grower's cut. |
| Unattributed GitHub/Kaggle dumps and retailer prose | Missing or ambiguous data provenance/licences | No import. Tangilope, LA Woman and Sour Kush additions were left out when a suitable accessible source was not established during this pass. |

## Curation rules and corrections

`t` is the familiar commercial category, not a botanical taxonomy or a measured
genetic percentage. `lean` uses short original labels such as "Sativa-leaning";
dominant hybrids may retain the established Indica/Sativa category. Neither
predicts a person's response or a bag's chemistry.

`p` contains published named parents or, for an explicitly identified selection,
its source cultivar. A three-way breeder pedigree may list three names; it does
not encode pollination order. Composite parents remain intact (for example
`Blueberry x Mazar`). Unknowns are omitted instead of inserting "unknown indica"
or inventing a resolvable parent. `r: true` means uncertain/reported history,
disputed breeder accounts, or ambiguity between versions; it can be true even
when all parents have been omitted. Absence of `r` is not laboratory proof.

The registry below records the review of **every original entry**. Material fixes:

- Separate **Amnesia** from **Amnesia Haze**, **Gelato #33/#41** from the Gelato
  family, and **MAC 1** from MAC. No cut number is an alias of the entire family.
- Remove generic aliases **OG, Skunk, Jack, Critical, Sherbet and Amnesia**. A
  genuine canonical name such as Amnesia or Cheese remains an exact lookup.
  The matcher still skips generic words when finding partial matches.
- Remove OG Kush's unsupported two-parent Hindu Kush claim. Keep its exact
  original ancestry empty and reported. Add Thai ancestry to Northern Lights.
- Correct White Rhino to Green House's published Afghan/Brazilian/South Indian
  pedigree. Do not preserve the former North American-indica assertion.
- Orange Bud is a Skunk selection, not a documented direct Skunk #1 cross;
  remove the false parent edge and add the breeder's sativa leaning.
- Durban Poison retains its South African origin and sativa leaning without
  asserting that a commercial selection is an unchanged landrace. Its own
  product heading and narrative disagree on ancestry, so it is reported.
- LSD names its Mazar-I-Sharif parent explicitly; it does not link to Dutch
  Passion's distinct Mazar hybrid.
- AK-47, Blueberry, Bubba Kush, Strawberry Cough, Green Crack, MAC and Banana
  Kush omit unsupported or over-specific original parent assertions. Trainwreck
  versions disagree on leaning; do not attach an arbitrary pair of parents.
- Ice Cream Cake specifies **Gelato #33**. Do-Si-Dos specifies **OG Kush Breath
  and Face Off OG BX1**. Biscotti specifies **Gelato #25**, not undifferentiated
  Gelato. Thin Mint remains a selection, with reported lineage.
- Wedding Cake keeps the widely published **Triangle Kush / Animal Mints**
  account and marks it reported. [Barney's own history](https://www.barneysfarm.com/us/blog/about-wedding-cake-strain)
  distinguishes it from the GSC/Cherry Pie account still used by
  [Royal Queen Seeds](https://www.royalqueenseeds.com/feminized-cannabis-seeds/628-wedding-cake.html)
  and Dutch Passion. These are not silently merged into one certain pedigree.
- Lemon Cherry Gelato keeps the published Sherbet/GSC parents as reported;
  the source also mentions an unidentified additional component, which is
  deliberately not invented as a named parent. Bubble Gum and 24K Gold avoid
  a single leaning when breeder accounts or the page itself disagree.
- Curated breeder credit is authoritative, including an absent credit. Kushy's
  shop/distributor strings (for example AFFCO and Holistic Healing Collective)
  no longer fill gaps in reviewed records. Community effects/flavours still
  merge. Community-only records keep their historical fields.

### Dutch label spellings

The task supplied **Sneeuwwitje** and **Sneeuwwietje** for Snow White. These remain
lexical aliases, attributed separately as `taima-dutch-aliases`; they are not
independent evidence of genetics. New spelling/label forms include Superskunk,
Silverhaze, Bubblegum, AK020, Blueberry Cheese and Amstel Gold. Broad nicknames
such as "Ami", "Ammo", "Z" and "GG" are deliberately not added because they can
collapse multiple names or cuts. Punctuation-only variants are harmless within
one record and sometimes useful for merging older community spellings.

## Validation and maintenance

```sh
python3 scripts/validate-strains.py
python3 -m unittest discover -s scripts -p 'test_validate_strains.py'
(cd Packages/TaimaCore && swift test)
```

The validator uses only the Python standard library, is independent of the
working directory and exits 1 on invalid JSON/schema, duplicate properties,
cross-strain normalized name/alias collisions, generic-word aliases, undefined
source IDs or self-parent references. It reads `StrainCatalog.generic` from
source rather than maintaining a second list. Curated aliases intentionally
replacing community records are allowed. It validates the community schema
and reports parent-name/alias resolution across both bundled files; unresolved
parents are informational. The source definitions are the backticked IDs in
the registry's first column. Duplicate definitions fail validation.

CI can run the first two commands on a Python runner with no credentials or
network access after checkout. Swift regression tests also read the actual
bundled JSON and cover product noise, Dutch aliases, separate selections,
children, search, source IDs and preservation of community tags.

Validation result: **154 curated records, 9,473 community records, 156 defined
source IDs, zero errors**. **217/242 parent references resolve (89.7%)**; the
remaining 25 are reported individually. Python validator regression tests and
the full TaimaCore suite also pass.

Future additions need a cited factual source and this same licence check.
Changing a product page, a grower's current menu or a synonym should never
trigger an app download. All app data and attribution notices remain bundled.
The maintainer should choose any eventual repository-wide licence separately
and decide whether to surface source IDs/links in a later UI change. The
historical Nirvana Snow White and Flying Dutchmen Original Haze attributions use
syndicated breeder records where original product pages could not be retrieved.
Obtain original archival references before adding further ancestry to either.

## Source reference registry

Every `src` item in the curated file must resolve to one of these IDs. IDs are provenance keys, not web requests. Product pages describe a breeder's version; shared names do not prove a bag's genotype. Original entries are identified in the audit column.

| ID | Record | Evidence | Audit / scope |
| --- | --- | --- | --- |
| `ag-ak-020` | AK-020 | [Reference](https://www.amsterdamgenetics.com/product/ak-020/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-ak-og-kush` | AK-OG Kush | [Reference](https://www.amsterdamgenetics.com/product/ak-og-kush/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-amazing-haze` | Amazing Haze | [Reference](https://www.amsterdamgenetics.com/product/amazing-haze/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-blue-magic` | Blue Magic | [Reference](https://www.amsterdamgenetics.com/product/blue-magic-cannabis-seeds/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-chocolato` | Chocolato | [Reference](https://www.amsterdamgenetics.com/product/chocolato/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-double-blue` | Double Blue | [Reference](https://www.amsterdamgenetics.com/product/double-blue/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-green-magic` | Green Magic | [Reference](https://www.amsterdamgenetics.com/product/green-magic/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-kosher-choco-kush` | Kosher Choco Kush | [Reference](https://www.amsterdamgenetics.com/product/kosher-choco-kush/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-kosher-tangie-kush` | Kosher Tangie Kush | [Reference](https://www.amsterdamgenetics.com/product/kosher-tangie-kush/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-lemon-haze` | Lemon Haze | [Reference](https://www.amsterdamgenetics.com/product/lemon-haze/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `ag-lemon-ice` | Lemon Ice | [Reference](https://www.amsterdamgenetics.com/product/lemon-ice/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-magic-og-kush` | Magic OG Kush | [Reference](https://www.amsterdamgenetics.com/product/magic-og-kush/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-strawberry-glue` | Strawberry Glue | [Reference](https://www.amsterdamgenetics.com/product/strawberry-glue/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-tangerine-g13` | Tangerine G13 | [Reference](https://www.amsterdamgenetics.com/product/tangerine-g13/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-white-choco` | White Choco | [Reference](https://www.amsterdamgenetics.com/product/white-choco/) | Published name, type/leaning and stated parents; no description copied. |
| `ag-white-choco-haze` | White Choco Haze | [Reference](https://www.amsterdamgenetics.com/product/white-choco-haze/) | Published name, type/leaning and stated parents; no description copied. |
| `archive-do-si-dos` | Do-Si-Dos | [Reference](https://archiveseedbank.com/products/do-si-dos) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `bf-amnesia-lemon` | Amnesia Lemon | [Reference](https://www.barneysfarm.com/us/amnesia-lemon-weed-strain-31) | Published name, type/leaning and stated parents; no description copied. |
| `bf-ayahuasca-purple` | Ayahuasca Purple | [Reference](https://www.barneysfarm.com/us/ayahuasca-purple-weed-strain-18) | Published name, type/leaning and stated parents; no description copied. |
| `bf-blue-cheese` | Blue Cheese | [Reference](https://www.barneysfarm.com/blue-cheese-34) | Published name, type/leaning and stated parents; no description copied. |
| `bf-blue-gelato-41` | Blue Gelato 41 | [Reference](https://www.barneysfarm.com/blue-gelato-41-456) | Published name, type/leaning and stated parents; no description copied. |
| `bf-critical-kush` | Critical Kush | [Reference](https://www.barneysfarm.com/critical-kush-23) | Published name, type/leaning and stated parents; no description copied. |
| `bf-dos-si-dos-33` | Dos Si Dos 33 | [Reference](https://www.barneysfarm.com/dos-si-dos-33-495) | Published name, type/leaning and stated parents; no description copied. |
| `bf-g13-haze` | G13 Haze | [Reference](https://www.barneysfarm.com/g13-haze-6) | Published name, type/leaning and stated parents; no description copied. |
| `bf-glookies` | Glookies | [Reference](https://www.barneysfarm.com/glookies-485) | Published name, type/leaning and stated parents; no description copied. |
| `bf-gmo` | GMO | [Reference](https://www.barneysfarm.com/us/gmo-cookies-weed-strain-711) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `bf-gorilla-z` | Gorilla Z | [Reference](https://www.barneysfarm.com/us/gorilla-zkittlez-weed-strain-459) | Published name, type/leaning and stated parents; no description copied. |
| `bf-ice-cream-cake` | Ice Cream Cake | [Reference](https://www.barneysfarm.com/us/ice-cream-cake-weed-strain-632) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `bf-laughing-buddha` | Laughing Buddha | [Reference](https://www.barneysfarm.com/us/laughing-buddha-weed-strain-8) | Published name, type/leaning and stated parents; no description copied. |
| `bf-lemon-cherry-gelato` | Lemon Cherry Gelato | [Reference](https://www.barneysfarm.com/us/lemon-cherry-gelato-weed-strain-701) | Published name, type/leaning and stated parents; no description copied. |
| `bf-lemon-tree` | Lemon Tree | [Reference](https://www.barneysfarm.com/lemon-tree-553) | Published name, type/leaning and stated parents; no description copied. |
| `bf-liberty-haze` | Liberty Haze | [Reference](https://www.barneysfarm.com/liberty-haze-9) | Published name, type/leaning and stated parents; no description copied. |
| `bf-lsd` | LSD | [Reference](https://www.barneysfarm.com/lsd-10) | Published name, type/leaning and stated parents; no description copied. |
| `bf-mac` | MAC | [Reference](https://www.barneysfarm.com/us/mac-1-weed-strain-812) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `bf-mac-1` | MAC 1 | [Reference](https://www.barneysfarm.com/us/mac-1-weed-strain-812) | Published name, type/leaning and stated parents; no description copied. |
| `bf-mimosa-x-orange-punch` | Mimosa x Orange Punch | [Reference](https://www.barneysfarm.com/mimosa-x-orange-punch-552) | Published name, type/leaning and stated parents; no description copied. |
| `bf-pineapple-chunk` | Pineapple Chunk | [Reference](https://www.barneysfarm.com/pineapple-chunk-15) | Published name, type/leaning and stated parents; no description copied. |
| `bf-purple-punch` | Purple Punch | [Reference](https://www.barneysfarm.com/purple-punch-483) | Original 53 reviewed. Retain published identity and metadata. |
| `bf-runtz` | Runtz | [Reference](https://www.barneysfarm.com/runtz-x-layer-cake-597) | Original 53 reviewed. Retain published identity and metadata. |
| `bf-runtz-muffin` | Runtz Muffin | [Reference](https://www.barneysfarm.com/runtz-muffin-523) | Published name, type/leaning and stated parents; no description copied. |
| `bf-runtz-x-layer-cake` | Runtz x Layer Cake | [Reference](https://www.barneysfarm.com/runtz-x-layer-cake-597) | Published name, type/leaning and stated parents; no description copied. |
| `bf-strawberry-lemonade` | Strawberry Lemonade | [Reference](https://www.barneysfarm.com/strawberry-lemonade-466) | Published name, type/leaning and stated parents; no description copied. |
| `bf-tangerine-dream` | Tangerine Dream | [Reference](https://www.barneysfarm.com/tangerine-dream-24) | Published name, type/leaning and stated parents; no description copied. |
| `bf-wedding-cake` | Wedding Cake | [Reference](https://www.barneysfarm.com/us/blog/about-wedding-cake-strain) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `dna-24k-gold` | 24K Gold | [Reference](https://dnagenetics.com/24k-gold-cannabis-strain/) | Published name, type/leaning and stated parents; no description copied. |
| `dna-banana-kush` | Banana Kush | [Reference](https://dnagenetics.com/strawberry-banana/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `dna-chocolope` | Chocolope | [Reference](https://dnagenetics.com/product/chocolope-fem/) | Published name, type/leaning and stated parents; no description copied. |
| `dna-green-crack` | Green Crack | [Reference](https://dnagenetics.com/product/green-crack-feminized/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `dna-kosher-kush` | Kosher Kush | [Reference](https://dnagenetics.com/product/kosher-kush-reg/) | Published name, type/leaning and stated parents; no description copied. |
| `dna-la-confidential` | LA Confidential | [Reference](https://dnagenetics.com/la-confidential-cannabis-strain/) | Published name, type/leaning and stated parents; no description copied. |
| `dna-strawberry-banana` | Strawberry Banana | [Reference](https://dnagenetics.com/strawberry-banana/) | Published name, type/leaning and stated parents; no description copied. |
| `dna-tangie` | Tangie | [Reference](https://dnagenetics.com/tangie/) | Original 53 reviewed. Retain published identity and metadata. |
| `dp-banana-blaze` | Banana Blaze | [Reference](https://dutch-passion.com/en/cannabis-seeds/banana-blaze) | Published name, type/leaning and stated parents; no description copied. |
| `dp-blueberry` | Blueberry | [Reference](https://dutch-passion.com/en/cannabis-seeds/blueberry) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `dp-california-orange` | California Orange | [Reference](https://dutch-passion.com/en/cannabis-seeds/californian-orange) | Published name, type/leaning and stated parents; no description copied. |
| `dp-critical-orange-punch` | Critical Orange Punch | [Reference](https://dutch-passion.com/en/cannabis-seeds/critical-orange-punch) | Published name, type/leaning and stated parents; no description copied. |
| `dp-desfran` | Desfran | [Reference](https://dutch-passion.com/en/cannabis-seeds/desfran) | Published name, type/leaning and stated parents; no description copied. |
| `dp-durban-dew` | Durban Dew | [Reference](https://dutch-passion.com/en/cannabis-seeds/durban-dew) | Published name, type/leaning and stated parents; no description copied. |
| `dp-durban-poison` | Durban Poison | [Reference](https://dutch-passion.com/en/cannabis-seeds/durban-poison) | Original 53 reviewed. Reported ancestry; commercial selection is not asserted to be an unchanged landrace. |
| `dp-euforia` | Euforia | [Reference](https://dutch-passion.com/en/cannabis-seeds/euforia) | Published name, type/leaning and stated parents; no description copied. |
| `dp-frisian-dew` | Frisian Dew | [Reference](https://dutch-passion.com/en/cannabis-seeds/frisian-dew) | Published name, type/leaning and stated parents; no description copied. |
| `dp-frisian-duck` | Frisian Duck | [Reference](https://dutch-passion.com/en/cannabis-seeds/frisian-duck) | Published name, type/leaning and stated parents; no description copied. |
| `dp-glueberry-og` | Glueberry OG | [Reference](https://dutch-passion.com/en/cannabis-seeds/glueberry-og) | Published name, type/leaning and stated parents; no description copied. |
| `dp-hollands-hope` | Hollands Hope | [Reference](https://dutch-passion.com/en/cannabis-seeds/hollands-hope) | Published name, type/leaning and stated parents; no description copied. |
| `dp-kerosene-krash` | Kerosene Krash | [Reference](https://dutch-passion.com/en/cannabis-seeds/kerosene-krash) | Published name, type/leaning and stated parents; no description copied. |
| `dp-master-kush` | Master Kush | [Reference](https://dutch-passion.com/en/cannabis-seeds/master-kush) | Published name, type/leaning and stated parents; no description copied. |
| `dp-mazar` | Mazar | [Reference](https://dutch-passion.com/en/cannabis-seeds/mazar) | Published name, type/leaning and stated parents; no description copied. |
| `dp-meringue` | Meringue | [Reference](https://dutch-passion.com/en/cannabis-seeds/meringue) | Published name, type/leaning and stated parents; no description copied. |
| `dp-orange-bud` | Orange Bud | [Reference](https://dutch-passion.com/en/cannabis-seeds/orange-bud) | Original 53 reviewed. Retain published identity and metadata. |
| `dp-orange-hill-special` | Orange Hill Special | [Reference](https://dutch-passion.com/en/cannabis-seeds/orange-hill-special) | Published name, type/leaning and stated parents; no description copied. |
| `dp-pamir-gold` | Pamir Gold | [Reference](https://dutch-passion.com/en/cannabis-seeds/pamir-gold) | Published name, type/leaning and stated parents; no description copied. |
| `dp-passion-1` | Passion #1 | [Reference](https://dutch-passion.com/en/cannabis-seeds/passion-1) | Published name, type/leaning and stated parents; no description copied. |
| `dp-power-plant` | Power Plant | [Reference](https://dutch-passion.com/en/cannabis-seeds/power-plant) | Published name, type/leaning and stated parents; no description copied. |
| `dp-shaman` | Shaman | [Reference](https://dutch-passion.com/en/cannabis-seeds/shaman) | Published name, type/leaning and stated parents; no description copied. |
| `dp-skywalker-haze` | Skywalker Haze | [Reference](https://dutch-passion.com/en/cannabis-seeds/skywalker-haze) | Published name, type/leaning and stated parents; no description copied. |
| `dp-strawberry-cough` | Strawberry Cough | [Reference](https://dutch-passion.com/en/cannabis-seeds/strawberry-cough) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `dp-the-ultimate` | The Ultimate | [Reference](https://dutch-passion.com/en/cannabis-seeds/the-ultimate) | Published name, type/leaning and stated parents; no description copied. |
| `dp-think-fast` | Think Fast | [Reference](https://dutch-passion.com/en/cannabis-seeds/think-fast) | Published name, type/leaning and stated parents; no description copied. |
| `gh-a-m-s` | A.M.S. | [Reference](https://shop.greenhouseseeds.nl/medicinal-seeds/high-thc-seeds/a-m-s/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-alaskan-ice` | Alaskan Ice | [Reference](https://shop.greenhouseseeds.nl/feminised-cannabis-seeds/climate-zones/indoor/alaskan-ice/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-arjan-s-haze-3` | Arjan's Haze #3 | [Reference](https://shop.greenhouseseeds.nl/medicinal-seeds/moderate-thc-seeds/arjans-haze-3/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-arjan-s-strawberry-haze` | Arjan's Strawberry Haze | [Reference](https://shop.greenhouseseeds.nl/medicinal-seeds/high-thc-seeds/strawberry-haze/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-arjan-s-ultra-haze-1` | Arjan's Ultra Haze #1 | [Reference](https://shop.greenhouseseeds.nl/award-winning-seeds/high-times-cannabis-cup/ultra-haze-1/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-big-bang` | Big Bang | [Reference](https://shop.greenhouseseeds.nl/feminised-cannabis-seeds/1-seed-pack/big-bang/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-damnesia` | Damnesia | [Reference](https://shop.greenhouseseeds.nl/feminised-cannabis-seeds/types-of-seeds/feminised-seeds/damnesia/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-franco-s-lemon-cheese` | Franco's Lemon Cheese | [Reference](https://shop.greenhouseseeds.nl/feminised-cannabis-seeds/types-of-seeds/hybrid-cannabis-seeds/francos-lemon-cheese/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-great-white-shark` | Great White Shark | [Reference](https://shop.greenhouseseeds.nl/award-winning-seeds/highlife-festival/great-white-shark/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-hawaiian-snow` | Hawaiian Snow | [Reference](https://shop.greenhouseseeds.nl/feminised-cannabis-seeds/hawaiian-snow/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-himalaya-gold` | Himalaya Gold | [Reference](https://shop.greenhouseseeds.nl/medicinal-seeds/moderate-thc-seeds/himalaya-gold/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-king-s-kush` | King's Kush | [Reference](https://shop.greenhouseseeds.nl/feminised-cannabis-seeds/families/kush-strains/kings-kush-feminised/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-lemon-skunk` | Lemon Skunk | [Reference](https://shop.greenhouseseeds.nl/feminised-cannabis-seeds/lemon-skunk/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-nevil-s-haze` | Nevil's Haze | [Reference](https://shop.greenhouseseeds.nl/medicinal-seeds/nevilles-haze/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-super-bud` | Super Bud | [Reference](https://shop.greenhouseseeds.nl/feminised-cannabis-seeds/super-bud/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-super-lemon-haze` | Super Lemon Haze | [Reference](https://shop.greenhouseseeds.nl/feminised-cannabis-seeds/1-seed-pack/super-lemon-haze/) | Original 53 reviewed. Retain published identity and metadata. |
| `gh-super-silver-haze` | Super Silver Haze | [Reference](https://shop.greenhouseseeds.nl/feminised-cannabis-seeds/super-silver-haze/) | Original 53 reviewed. Retain published identity and metadata. |
| `gh-the-church` | The Church | [Reference](https://shop.greenhouseseeds.nl/feminised-cannabis-seeds/1-seed-pack/the-church/) | Published name, type/leaning and stated parents; no description copied. |
| `gh-trainwreck` | Trainwreck | [Reference](https://shop.greenhouseseeds.nl/medicinal-seeds/high-thc-seeds/train-wreck/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `gh-white-rhino` | White Rhino | [Reference](https://shop.greenhouseseeds.nl/feminised-cannabis-seeds/1-seed-pack/white-rhino/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `hendrx-tropicana-cookies` | Tropicana Cookies | [Reference](https://www.hendrx.farm/cultivar/tropicana-cookies/) | Original 53 reviewed. Retain published identity and metadata. |
| `hso-bubba-kush` | Bubba Kush | [Reference](https://www.humboldtseeds.net/en/bubba-kush/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `hso-chemdawg` | Chemdawg | [Reference](https://www.humboldtseeds.net/en/blog/hso-chemdawg4/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `mns-critical-mass` | Critical Mass | [Reference](https://shop.mrnice.nl/products/critical-mass) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `mns-g13` | G13 | [Reference](https://shop.mrnice.nl/products/g13-haze) | Published name, type/leaning and stated parents; no description copied. |
| `puresativa-haze` | Haze | [Reference](https://www.puresativa.com/the-original-haze-pot-seeds) | Original 53 reviewed. Attributed historical Flying Dutchmen record; exact ancestry omitted. |
| `rqs-apple-fritter` | Apple Fritter | [Reference](https://www.royalqueenseeds.com/us/feminized-cannabis-seeds/634-apple-fritter.html) | Original 53 reviewed. Retain published identity and metadata. |
| `rqs-biscotti` | Biscotti | [Reference](https://www.royalqueenseeds.com/feminized-cannabis-seeds/630-biscotti.html) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `rqs-cereal-milk` | Cereal Milk | [Reference](https://www.royalqueenseeds.com/us/feminized-cannabis-seeds/631-cereal-milk.html) | Published name, type/leaning and stated parents; no description copied. |
| `rqs-cherry-pie` | Cherry Pie | [Reference](https://www.royalqueenseeds.com/uk/feminized-cannabis-seeds/653-cherry-pie.html) | Original 53 reviewed. Retain published identity and metadata. |
| `rqs-gelato-33` | Gelato #33 | [Reference](https://www.royalqueenseeds.com/us/blog-gelato-strain-review-n1759) | Published name, type/leaning and stated parents; no description copied. |
| `rqs-mimosa` | Mimosa | [Reference](https://www.royalqueenseeds.com/feminized-cannabis-seeds/569-mimosa.html) | Original 53 reviewed. Retain published identity and metadata. |
| `rqs-sour-diesel` | Sour Diesel | [Reference](https://www.royalqueenseeds.com/feminized-cannabis-seeds/185-sour-diesel.html) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `rqs-sunset-sherbet` | Sunset Sherbet | [Reference](https://www.royalqueenseeds.com/us/feminized-cannabis-seeds/441-sherbet-queen.html) | Original 53 reviewed. Retain published identity and metadata. |
| `rqs-thin-mint-girl-scout-cookies` | Thin Mint Girl Scout Cookies | [Reference](https://www.royalqueenseeds.com/us/blog-gelato-strain-review-n1759) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `rqs-zkittlez` | Zkittlez | [Reference](https://www.royalqueenseeds.com/us/feminized-cannabis-seeds/442-sweet-zz.html) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `seeds66-purple-kush` | Purple Kush | [Reference](https://www.seeds66.com/purple-kush-by-seeds66) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `seeds66-snow-white` | Snow White | [Reference](https://www.seeds66.com/snow-white-by-nirvana-seeds) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `sensi-afghani` | Afghani | [Reference](https://sensiseeds.com/en/blog/cannabis-strain-focus-afghani-1-sensi-seeds/) | Original 53 reviewed. Retain published identity and metadata. |
| `sensi-afghani-1` | Afghani #1 | [Reference](https://sensiseeds.com/en/cannabis-seeds/sensi-seeds/afghani-1) | Published name, type/leaning and stated parents; no description copied. |
| `sensi-big-bud` | Big Bud | [Reference](https://sensiseeds.com/en/blog/big-bud-regular-grow-report-indoor/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `sensi-black-domina` | Black Domina | [Reference](https://sensiseeds.com/en/cannabis-seeds/sensi-seeds/black-domina) | Published name, type/leaning and stated parents; no description copied. |
| `sensi-blue-dream` | Blue Dream | [Reference](https://sensiseeds.com/en/blog/31-best-weed-strains-of-all-time-the-greatest-hits-of-cannabis/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `sensi-cheese` | Cheese | [Reference](https://sensiseeds.com/en/blog/31-best-weed-strains-of-all-time-the-greatest-hits-of-cannabis/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `sensi-early-skunk` | Early Skunk | [Reference](https://sensiseeds.com/en/blog/cannabis-strain-focus-early-skunk-sensi-seeds/) | Published name, type/leaning and stated parents; no description copied. |
| `sensi-girl-scout-cookies` | Girl Scout Cookies | [Reference](https://sensiseeds.com/en/blog/31-best-weed-strains-of-all-time-the-greatest-hits-of-cannabis/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `sensi-gorilla-glue-4` | Gorilla Glue #4 | [Reference](https://sensiseeds.com/en/blog/31-best-weed-strains-of-all-time-the-greatest-hits-of-cannabis/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `sensi-granddaddy-purple` | Granddaddy Purple | [Reference](https://sensiseeds.com/en/blog/31-best-weed-strains-of-all-time-the-greatest-hits-of-cannabis/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `sensi-hash-plant` | Hash Plant | [Reference](https://sensiseeds.com/en/blog/choose-hash-strain/) | Published name, type/leaning and stated parents; no description copied. |
| `sensi-hindu-kush` | Hindu Kush | [Reference](https://sensiseeds.com/en/cannabis-seeds/sensi-seeds/hindu-kush) | Original 53 reviewed. Retain published identity and metadata. |
| `sensi-jack-herer` | Jack Herer | [Reference](https://sensiseeds.com/en/blog/31-best-weed-strains-of-all-time-the-greatest-hits-of-cannabis/) | Original 53 reviewed. Retain published identity and metadata. |
| `sensi-jamaican-pearl` | Jamaican Pearl | [Reference](https://sensiseeds.com/en/regular/jamaican-pearl) | Published name, type/leaning and stated parents; no description copied. |
| `sensi-maple-leaf-indica` | Maple Leaf Indica | [Reference](https://sensiseeds.com/en/cannabis-seeds/sensi-seeds/maple-leaf-indica) | Published name, type/leaning and stated parents; no description copied. |
| `sensi-northern-lights` | Northern Lights | [Reference](https://sensiseeds.com/en/blog/31-best-weed-strains-of-all-time-the-greatest-hits-of-cannabis/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `sensi-og-kush` | OG Kush | [Reference](https://sensiseeds.com/en/blog/31-best-weed-strains-of-all-time-the-greatest-hits-of-cannabis/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `sensi-pineapple-express` | Pineapple Express | [Reference](https://sensiseeds.com/en/blog/31-best-weed-strains-of-all-time-the-greatest-hits-of-cannabis/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `sensi-purple-haze` | Purple Haze | [Reference](https://sensiseeds.com/en/blog/31-best-weed-strains-of-all-time-the-greatest-hits-of-cannabis/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `sensi-shiva-skunk` | Shiva Skunk | [Reference](https://sensiseeds.com/en/feminized-seeds/sensi-seeds/shiva-skunk-feminised) | Published name, type/leaning and stated parents; no description copied. |
| `sensi-silver-haze` | Silver Haze | [Reference](https://sensiseeds.com/en/feminized-seeds/sensi-seeds/silver-haze-feminized) | Published name, type/leaning and stated parents; no description copied. |
| `sensi-skunk-1` | Skunk #1 | [Reference](https://sensiseeds.com/en/blog/31-best-weed-strains-of-all-time-the-greatest-hits-of-cannabis/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `sensi-super-skunk` | Super Skunk | [Reference](https://sensiseeds.com/en/feminized-seeds/sensi-seeds/super-skunk-feminised) | Published name, type/leaning and stated parents; no description copied. |
| `sensi-white-widow` | White Widow | [Reference](https://sensiseeds.com/en/blog/31-best-weed-strains-of-all-time-the-greatest-hits-of-cannabis/) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `serious-ak-47` | AK-47 | [Reference](https://www.seriousseeds.com/cannabis-seeds/ak-47) | Original 53 reviewed. Reported/uncertain lineage; omit unsupported parents. |
| `serious-bubble-gum` | Bubble Gum | [Reference](https://www.seriousseeds.com/cannabis-seeds/bubble-gum) | Published name, type/leaning and stated parents; no description copied. |
| `serious-chronic` | Chronic | [Reference](https://www.seriousseeds.com/cannabis-seeds/chronic) | Published name, type/leaning and stated parents; no description copied. |
| `serious-double-dutch` | Double Dutch | [Reference](https://www.seriousseeds.com/cannabis-seeds/double-dutch) | Published name, type/leaning and stated parents; no description copied. |
| `serious-kali-mist` | Kali Mist | [Reference](https://www.seriousseeds.com/cannabis-seeds/kali-mist) | Published name, type/leaning and stated parents; no description copied. |
| `serious-serious-6` | Serious 6 | [Reference](https://www.seriousseeds.com/cannabis-seeds/serious-6) | Published name, type/leaning and stated parents; no description copied. |
| `serious-serious-happiness` | Serious Happiness | [Reference](https://www.seriousseeds.com/cannabis-seeds/serious-happiness) | Published name, type/leaning and stated parents; no description copied. |
| `serious-warlock` | Warlock | [Reference](https://www.seriousseeds.com/cannabis-seeds/warlock) | Published name, type/leaning and stated parents; no description copied. |
| `serious-white-russian` | White Russian | [Reference](https://www.seriousseeds.com/cannabis-seeds/white-russian) | Published name, type/leaning and stated parents; no description copied. |
| `sherbinskis-gelato` | Gelato | [Reference](https://sherbinskis.com/gelato) | Original 53 reviewed. Retain published identity and metadata. |
| `sherbinskis-gelato-41` | Gelato #41 | [Reference](https://sherbinskis.com/gelato) | Published name, type/leaning and stated parents; no description copied. |
| `soma-amnesia-haze` | Amnesia Haze | [Reference](https://somaseeds.nl/product/amnesia-haze/) | Original 53 reviewed. Retain published identity and metadata. |
| `superstrains-amnesia` | Amnesia | [Reference](https://superstrainsseeds.com/about/) | Published name, type/leaning and stated parents; no description copied. |
| `taima-dutch-aliases` | Dutch label spellings | [Reference](#dutch-label-spellings) | Owner-supplied Snow White spellings; lexical aliases, no ancestry inference. |
| `terphogz-z` | Original Z naming | [Reference](https://terphogz.com/z-originator-terphogz-releases-statement-on-settlement-with-skittles-candy-maker-wrigley/) | Original Z naming only; no legal or marketing text copied. |
| `theory-motorbreath` | Motorbreath | [Reference](https://theorywellness.org/product/motorbreath-strain/) | Original 53 reviewed. Retain published identity and metadata. |
