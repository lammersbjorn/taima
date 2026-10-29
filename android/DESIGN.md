# Taima Android

The Android app expresses Taima’s iPhone visual language with native Material 3 components. Collection, inventory and logging remain the primary tasks.

Page: #F2F2F4 light, #000000 dark. Opaque cards: #FFFFFF light, #1A1A1C dark. Raised neutral controls: #EAE9EE light, #2A2A2E dark. Primary ink: #19191D / #F6F6F9. Secondary ink: #5E5D63 / #B2B0B6. Every Material colour role is explicit. No dynamic colour, tinted surfaces or default purple. Green #1B7A47 with white text is reserved for controls, selection and progress. Charts use neutral ink. Party deck backgrounds use the corresponding iPhone deck kind colours with white text.

Use large native top app bars, a compact navigation bar and a rail above 600 dp. Short English and Dutch labels stay on one line. At 1.5 font scale and above, icons retain full destination content descriptions and labels disappear. Body copy scales normally; large layouts stack figures and tiles. Keep controls at least 48 dp.

Content cards have 22 dp corners, 20 dp padding and no tonal elevation. Section titles are semibold. Personal values use the platform family with tabular numerals (tnum), never a monospace face. Charts are local Compose Canvas with text alternatives and explicit values.

Collection has a search field and photo rows. Sort, product, stock, grouping and comparison live in the top-bar filter sheet. The green FAB opens a native add menu. Stash groups the active item, remaining progress, quick logging, weekly summary and recent sessions. Stats opens with personal totals and a responsive metric grid, followed by monthly bars, growers, THC spread and session methods. More uses grouped rows with leading icons and supporting text. Empty states have a quiet icon, short title and one sentence. Party play is a full-screen, scrollable deck with a persistent Next action.

Synthetic evidence lives in ../docs/evidence/android/design. The test-only DesignFixtureTest seeds a disposable owned emulator only when explicitly enabled by an instrumentation argument. Never include real collection data in evidence.
