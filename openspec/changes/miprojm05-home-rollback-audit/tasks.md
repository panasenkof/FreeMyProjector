# P-04 tasks — evidence and safety first

- [x] Real MiProjM05 ADB identity and HOME evidence received from owner on 24.10.2026, no serial/IP committed.
- [x] Inspect current `HomeMode` / `ModeJob` for package disable / HOME / screensaver writes and rollback assumptions.
- [x] Write OpenSpec proposal, design and non-mutating safety specification.
- [x] Document read-only Windows ADB package inventory for owner.
- [x] Preserve the source-level HOME safety lock and require separate consent for any future mutation.
- [x] Confirm filtered OEM package candidates on real device 24.10.2026: Fengmi imaging/settings/platform/autofocus/tests plus Google HOME (documented without IP/serial).
- [x] Confirm no matches in disabled-package list with the SAME filter (not a global disabled-state claim).
- [x] Add fail-closed protections for observed packages and Formovie/Fengmi namespace prefixes; guard both disable loops and add static regression checks.
- [x] Second filtered read-only inventory confirms 18 Fengmi/Formovie/Droidlogic/Camera2 packages on firmware `.4185` (24.10.2026).
- [x] Extend fail-closed guard for `com.droidlogic` namespace and `com.android.camera2`, verify both disabling paths through CI static checks.
- [x] Find optical and TV settings Activity Resolver Table entries for imaging/gsettings/tvinput on real `.4185`, without starting them.
- [x] Receive local `FengmiImaging.apk` manifest excerpt: target `ImagingFeatureActivity` exported=true, alias enabled=true, each alias has Action/DEFAULT; Android 9 alias with intent-filter defaults exported=true (practical external launch not yet tested).
- [x] Specify mandatory pre-change local backup, remote pairing/re-pairing, picture settings from photos, no-root backup limits, and fail-closed rollback matrix in [P-04B](../../../docs/MIPROJM05_BACKUP_REMOTE_PICTURE_ROLLBACK.md).
- [x] Implement read-only Windows baseline snapshot + fake ADB test cases for exact firmware, packages, HOME, SHA-256 and fail-closed; **hardware snapshot was taken 25.10.2026**.
- [x] Owner reports `saved` on 25.10.2026: 114 packages, 0 disabled, snapshot moved to D:\Git\FreeMyProjector outside Git checkout; no private JSON committed.
- [x] Owner compared SHA256 of pulled `FengmiImaging.apk` with live OEM file on 25.10.2026: identical `948b530bbaf1cd7cf1185099422c8cf1a2521ec1bfcfd92b886c2a12456ab0f2` (one APK, not firmware).
- [x] Owner verified SHA256 of moved baseline JSON in local folder with `Compare-ProjectorBaseline.ps1 -VerifyOnly` on 25.10.2026: `status=verified`, `sha256=match`, 114/0, no ADB/no device writes.
- [ ] Review physical/offline storage protection of snapshot; hardware rollback remains untested; do not call this a full firmware backup.
- [x] Owner ran read-only baseline-versus-live-device comparison 25.10.2026: `matches-baseline`, exact Google TV HOME, identical firmware and 114/114 package states; no package differences or device writes. No private JSON stored in Git.
- [x] Implement checksum validation and read-only live drift preview with offline fake-ADB scenarios (HOME, packages, corrupt hash, firmware); CI required. This does NOT implement restoration.
- [ ] Owner to execute safe [P-04C manual checklist](../../../docs/P04C_REMOTE_PICTURE_MANUAL_CHECKLIST.md): remote/gear/voice/long-press, original picture/focus/keystone/HDMI and alternative control. Do NOT unpair/reset/recalibrate yet.
- [ ] Test the **actual** pairing/re-pairing and gear key, voice, long-press Volume, cold boot, emergency alternative input; document precise MiProjM05 model behavior.
- [ ] Record the exact OEM picture-mode settings and meaning of camera brightness; verify identical state before/after ordinary APK trial.
- [x] Add P-04D offline-only mock simulator for Android 9 HOME and package rollback based on SHA-verified baseline + explicit change journal (failure injection; idempotency; protected packages). CI must verify; no device write implementation exists.
- [x] Add one-command local Windows offline mock-rollback runner using owner's SHA-verified baseline without ADB/Android writes, plus temp-fixture cleanup and mocked CI coverage; owner-side execution remains pending.
- [x] Owner executed `tools/Test-ProjectorRollbackLocally.ps1` with original 114-package SHA-verified baseline on 25.10.2026: `status=passed`, `OFFLINE_MOCK_ONLY`, 5 cases, original unchanged, 0 ADB/physical writes. Injected faults were correctly detected. This is NOT actual firmware/HOME rollback.
- [x] Add P-04E read-only user 0 scoping check and offline fake ADB regressions, including Android chooser HOME rejection. Hardware scope check pending CI and owner run.
- [x] Owner executed P-04E real-device check on MiProjM05 `.4185` 25.10.2026: `user0-matches-baseline`, active Android user 0, implicit/explicit=114, 0 disabled, 0 discrepancies vs baseline, SHA match and zero device writes.
- [x] Document P-04F Android 9 recovery gates G0-G6, marking confirmed evidence and missing emergency/OEM/firmware proofs; this is a **design protocol only**.
- [ ] Demonstrate an independent physical recovery/control path, obtain picture/optics/pairing baseline evidence and validate actual Android 9 HOME restoration only in a separately approved and safe hardware procedure.
- [ ] Independently implement and review actual Android 9 recovery protocol only after manual and emergency-access gates; no mutation in this change.
- [ ] Confirm a realistic independent device-recovery method before a HOME pilot.

- [ ] Check exported flags, alias targets, permissions and safe entry routes without mutation; HDMI/optical functional behavior remains untested.

- [ ] Confirm access to focus and vertical keystone in native Xiaomi menu without changes.
- [ ] Map actual optical dependency components and test that ordinary app opening keeps them accessible.
- [ ] Design and review an Android 9 specific reversible HOME method with ADB + remote rollback.
- [ ] Obtain explicit owner approval before *any* HOME/default-setting mutation; complete manual tests, including power cycle/ADB reachability.

**Acceptance:** this change is *diagnostic only*. No claim of safe switch or device compatibility until manual proofs pass. Related P-04A: `openspec/changes/projector-functions-preservation/`.