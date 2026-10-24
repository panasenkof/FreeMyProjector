# Tasks

- [x] Compare upstream 62e883b → aa34335 (181 commits).
- [x] Port Android 8–10 ADB approval retry from upstream 6209fca8e.
- [x] Document optical function preservation, read-only discovery, firmware research and rollback acceptance.
- [x] Preserve P-04 safety gate, signing and Android package identity.
- [ ] Confirm CI compilation and existing regression tests on the PR.
- [x] Review [CleanYourTV MiProjM05 profile](https://github.com/Gathin23/cleanyourtv/tree/main/examples/formovie-mprojm05), with research in [docs/CLEANYOURTV_MIPROJM05_RESEARCH.md](../../../docs/CLEANYOURTV_MIPROJM05_RESEARCH.md) (different firmware, research only).
- [x] Map imaging FocusActivity/KeystoneActivity/AutoKeystoneActivity and Droidlogic settings Activity names from owner-supplied `dumpsys package`, documented in [docs/MIPROJM05_ACTIVITY_DISCOVERY.md](../../../docs/MIPROJM05_ACTIVITY_DISCOVERY.md) (read-only names, not proven callable).
- [x] Read actual OEM `FengmiImaging.apk` AndroidManifest locally: target `ImagingFeatureActivity` exported=true, aliases enabled=true with `targetActivity`; Android 9 aliases with filters default exported=true.
- [ ] Check remaining permission/runtime restrictions and a safe ordinary-APK launch separately; no automated keystone or motor test before consent.
- [ ] Before HOME changes, satisfy P-04B: remote (including re-pairing), native picture controls, verified local backup and recovery plan ([protocol](../../../docs/MIPROJM05_BACKUP_REMOTE_PICTURE_ROLLBACK.md)).
- [ ] Investigate actual Formovie settings, Droidlogic HDMI behavior and remote gear codes **read-only**; do not import debloat list.
- [ ] On real MiProjM05, inventory required focus/keystone packages (read-only).
- [ ] Verify stock focus/keystone from our app **without** switching HOME.
- [ ] Introduce protected OEM components from real evidence, run P-04 rollback acceptance.
- [ ] Transfer other desired upstream improvements via separately tested PRs.
