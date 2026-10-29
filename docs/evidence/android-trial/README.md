# Android trial evidence

Read `../../research/android-trial.md` for interpretation and coverage limits.

- Logs named `*-resume` plus JVM locale logs and Swift host locale logs are
  fresh continuation runs on `t3/android-trial-2`.
- `swift-emulator-final.log` records the full Android Swift run followed by
  three filtered golden-suite runs. `coverage.json` keeps runtime counts and
  the 19 compile-time SQLite module exclusions separate.
- `native-sizes-final.json` is the handwritten ELF runtime closure;
  `generated-sizes.json` records swift-java's extra arm64 libraries.
- Earlier build logs are retained checkpoint evidence. They have been trimmed
  to conclusions and timings, with home paths replaced by `~`. They are not
  reruns. `baseline-errors.txt` is retained, not a current failure list.
- `restart-checkpoint.json` and `android-trial-checkpoint.md` describe the
  historical interruption. They are superseded by the final report's results.
- `capacity-unavailable.log` means no admission, not a compilation/test failure.
- Device session records retain the actual owned PID and stop method. A T3
  device-open result is not app boot/readiness or rendered acceptance.

All input records/photos/archives are synthetic. No credentials or full build
logs belong here. The local signing key and any retained APK live outside git.
