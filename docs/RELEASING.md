# Releasing Taima

For maintainers.

1. **Bump the version.** In `project.yml`, raise `CURRENT_PROJECT_VERSION` by one and set `MARKETING_VERSION`.
2. **Write release notes.** Add a `ReleaseHighlights(build: N, …)` entry in `App/Taima/Onboarding.swift`. These notes become the What's New sheet, the SideStore notes and the GitHub release notes.
3. **Re-read prompt (optional).** If label reading improved enough to re-read older bags, raise `EntryReview.readerVersion`.
4. **Library changes** (strains, their sources, or growers):
   ```sh
   scripts/validate-strains.py
   scripts/build-sources.py                  # after editing the registry in docs/research/strain-sources.md
   scripts/publish-library.py --minimum-build N
   ```
   The library holds `strains-curated.json`, `strains.json`, `strain-sources.json` and `growers.json` from `App/Taima/Resources`. Growers are matched by lower-case aliases and `domain:`, `tel:` or `ean:` keys; set `"designated": false` for a brand that isn't one of the ten designated growers. Apps download a new library within a day, without an app update.
5. **Commit and build:**
   ```sh
   (cd Packages/TaimaCore && swift test)
   git commit -am "chore: release X.Y"
   scripts/build-ipa.sh                      # refuses a dirty tree
   scripts/release.py build/Taima-X.Y-<sha>.ipa
   ```
6. **Publish.** Commit `sidestore/source.json`, push, then run the `gh release create` command `release.py` printed. SideStore picks the update up from the source, and the app's daily check announces it.
7. **Keep the debug symbols.** Store the `.dSYMs.zip` next to the IPA, so crash reports can be read later.
