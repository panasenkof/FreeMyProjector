# P-04 tasks — evidence and safety first

- [x] Real MiProjM05 ADB identity and HOME evidence received from owner on 24.10.2026, no serial/IP committed.
- [x] Inspect current `HomeMode` / `ModeJob` for package disable / HOME / screensaver writes and rollback assumptions.
- [x] Write OpenSpec proposal, design and non-mutating safety specification.
- [x] Document read-only Windows ADB package inventory for owner.
- [x] Preserve the source-level HOME safety lock and require separate consent for any future mutation.
- [ ] Confirm filtered installed system/OEM packages on real device.
- [ ] Confirm preexisting disabled-package state (filtered).
- [ ] Confirm access to focus and vertical keystone in native Xiaomi menu without changes.
- [ ] Map actual optical dependency components and test that ordinary app opening keeps them accessible.
- [ ] Design and review an Android 9 specific reversible HOME method with ADB + remote rollback.
- [ ] Obtain explicit owner approval before *any* HOME/default-setting mutation; complete manual tests, including power cycle/ADB reachability.

**Acceptance:** this change is *diagnostic only*. No claim of safe switch or device compatibility until manual proofs pass. Related P-04A: `openspec/changes/projector-functions-preservation/`.