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
- [ ] Independently verify checksum after move and storage protection; hardware rollback remains untested; do not call this a full firmware backup.
- [ ] Test the **actual** pairing/re-pairing and gear key, voice, long-press Volume, cold boot, emergency alternative input; document precise MiProjM05 model behavior.
- [ ] Record the exact OEM picture-mode settings and meaning of camera brightness; verify identical state before/after ordinary APK trial.
- [ ] Simulate Android 9 rollback of original HOME and per-package enabled/disabled states on mocks; verify failure paths and absence of dangerous fallback.
- [ ] Confirm a realistic independent device-recovery method before a HOME pilot.

- [ ] Check exported flags, alias targets, permissions and safe entry routes without mutation; HDMI/optical functional behavior remains untested.

- [ ] Confirm access to focus and vertical keystone in native Xiaomi menu without changes.
- [ ] Map actual optical dependency components and test that ordinary app opening keeps them accessible.
- [ ] Design and review an Android 9 specific reversible HOME method with ADB + remote rollback.
- [ ] Obtain explicit owner approval before *any* HOME/default-setting mutation; complete manual tests, including power cycle/ADB reachability.

**Acceptance:** this change is *diagnostic only*. No claim of safe switch or device compatibility until manual proofs pass. Related P-04A: `openspec/changes/projector-functions-preservation/`.