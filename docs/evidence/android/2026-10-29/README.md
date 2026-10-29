# Local continuation evidence, 2026-10-29

No CI, publication, emulator or user data. Latest implementation: `74e3799`.
The native sources and manifest/dependency configuration at that head are
identical to `3931f99`, the frozen source recorded in round 3.

- Round 1 began at `879d9f9`, while source work continued. JVM tests passed;
  app compilation failed. `6b73535` fixes those Kotlin errors. Its APK attempt
  admitted an intermediate arm64 build, then denied x86_64. This is not a final
  exact-source result.
- Round 2 denied every requested build. The live verification script was edited
  while Bash was reading it; after the refusals the terminal returned exit 2
  with `syntax error near unexpected token fi` and attempted packaging missing
  x86_64 output. No native compilation happened in that pass. Round 3 used a
  frozen helper copy and was not edited while running.
- Round 3 records clean `3931f99` before every operation. The arm64 build and
  package step passed. The separate x86_64 attempt was denied, but the later
  APK-script attempt admitted both ABIs and packaged x86_64 successfully. The
  release Kotlin sources compiled, then resource linking failed on shortcut
  label references. `9d28d10` fixes the slash syntax; `40746ab` additionally
  protects editor saves against concurrent widget/session writes. `74e3799`
  refreshes the stale collection after a conflict and on resume. These latest
  frontend changes require another compilation and instrumentation run.
- `apk-final.log` is the denied retry after the resource fix. `apk-corrected.log`
  is the denied retry at `40746ab`. Both returned 75 before compilation.
- The standalone Swift/iOS retry logs contain admission refusals, not builds.
- `jvm-locale-contracts.log` runs the already-built, unchanged Kotlin JVM corpus
  under all three requested default locales, 7 tests each. This does not run JNI.
- The retained merged release manifest came from round 3. Its source manifest
  and dependency configuration have not changed since then. It disables Android
  cloud backup. Permissions are CAMERA, POST_NOTIFICATIONS, INTERNET, WAKE_LOCK,
  ACCESS_NETWORK_STATE, RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE and the
  app-signature dynamic-receiver permission. Exported platform services are
  permission guarded; the launcher activity and widget receiver are exported.
  No contacts, location, microphone, broad media, analytics or advertising-ID
  permission was added. No claim of a runtime network audit is made.

There is no APK size, signature or emulator screenshot result. No fresh
Apple-made photo archive was generated because Swift tests were never admitted.
The source and release-preparation checks are structural Python checks only.

The final `74e3799` APK attempt returned 75 before compilation
(`apk-last-clean-attempt.log`). A preceding attempt returned 2 because retained
evidence was untracked; that evidence was moved out of the source tree before
the clean retry. No build was performed by the exit-2 attempt.

The full TaimaCore package tree at `74e3799` equals `3931f99`:
`e0aafac8f1d4c62f8f0a74bac998fafe2f9f918c`. The later differences are frontend
conflict handling and shortcut XML references, plus the structural checker.

Console line endings and trailing whitespace were normalized for retention.
