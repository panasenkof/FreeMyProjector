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
- [ ] Check exported flags, alias targets, permissions and safe entry routes without mutation; HDMI/optical functional behavior remains untested.

- [ ] Confirm access to focus and vertical keystone in native Xiaomi menu without changes.
- [ ] Map actual optical dependency components and test that ordinary app opening keeps them accessible.
- [ ] Design and review an Android 9 specific reversible HOME method with ADB + remote rollback.
- [ ] Obtain explicit owner approval before *any* HOME/default-setting mutation; complete manual tests, including power cycle/ADB reachability.

**Acceptance:** this change is *diagnostic only*. No claim of safe switch or device compatibility until manual proofs pass. Related P-04A: `openspec/changes/projector-functions-preservation/`.