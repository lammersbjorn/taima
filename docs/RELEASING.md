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
   python3 scripts/android/sync-highlights.py   # What's New for Android
   python3 scripts/android/sync-strings.py      # core strings for Android
   scripts/build-ipa.sh                      # refuses a dirty tree
   scripts/build-apk.sh                      # signed arm64 APK, same version and build
   scripts/release.py build/Taima-X.Y-<sha>.ipa --apk build/Taima-X.Y.apk
   ```
   Run the two sync scripts before committing, so the tree stays clean for the builds.
6. **Publish.** Commit `sidestore/source.json`, push, then run the `gh release create` command `release.py` printed. It attaches the IPA and the APK to one release. SideStore picks the iPhone update up from the source, Obtainium picks up the APK, and the app's daily check announces it.
   Then check that the raw source serves the new version and that both downloads match the files you built: the raw GitHub CDN can lag for a few minutes.
7. **Keep the debug symbols.** Store the `.dSYMs.zip` next to the IPA, so crash reports can be read later.

## Android signing key

`scripts/build-apk.sh` signs with a key outside the repository:
`~/.local/share/taima/android-trial/release.jks` and the `keystore-password` file
next to it. Back both up. A different key can't update existing installs.

Heavy builds on a shared Mac go through the host load gate; exit 75 means try
again later. This project has no CI or GitHub workflows; do not add them.
