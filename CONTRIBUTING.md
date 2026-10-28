# Contributing to Taima

Thank you for helping. Taima is a small, privacy-first app, so a few rules matter more than usual.

## Ways to help

- **Share a label Taima misread.** Turn on **Settings ▸ Label reading ▸ Offer to share label samples**, correct a bag, and choose **Open as a GitHub issue**. The sample has codes removed and nothing personal. Each one becomes a test case.
- **Report a bug.** Use the bug template, with your iOS version, Taima version and steps. Never attach your backup, product codes or anything personal.
- **Improve the strain library.** Edit `App/Taima/Resources/strains-curated.json`, cite a source for every lineage (`docs/research/strain-sources.md`), and mark disputed lineages as reported. Run `scripts/validate-strains.py`.
- **Code.** Open an issue first for anything bigger than a fix.

## Ground rules

- **Offline first.** No new network calls, analytics, accounts or third-party SDKs. The update check in `UpdateService` is the only network use.
- **No personal data in the repository.** Fixtures hold recognised text and boxes only, never photos, and every product code (PRD) in them is made up.
- **Plain, neutral wording** in the app. No medical claims, no encouragement to use more.
- **Accessibility:** Dynamic Type, VoiceOver labels and enough contrast in light and dark mode.

## Development

```sh
xcodegen generate
(cd Packages/TaimaCore && swift test)
```

Logic belongs in `Packages/TaimaCore` with tests; the app target (`App/Taima`) is SwiftUI. Commit messages follow [Conventional Commits](https://www.conventionalcommits.org). Debug builds accept a few launch variables for simulator checks, documented in `AppModel.debugImport`.

By contributing you agree that your work is released under the GPL-3.0.
