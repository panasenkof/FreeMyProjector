# P-05 tasks

- [x] Source manifest P-05 safety: version 0.1.1/1001, HomeActivity/HomeReceiver/RemoteKeyService disabled, SettingsActivity enabled.
- [x] Add static source safeguards in CI.
- [x] Add compiled Android XML checks to unsigned and signed build workflows.
- [x] Add manual signed v0.1.1 prerelease and device acceptance guide.
- [x] Android APK build [40196452349](https://github.com/panasenkof/FreeMyProjector/actions/runs/40196452349): **success**; static source and `aapt2` compiled binary manifest gate passed. OpenSpec validation [40196452287](https://github.com/panasenkof/FreeMyProjector/actions/runs/40196452287): **success**. Hardware untouched.
- [ ] Owner manually launches signed release workflow on main (requires private signing secrets) and confirms v0.1.1 asset.
- [ ] Owner separately authorizes and installs test APK **as normal app**, without switching HOME.
- [ ] Owner records P-05/P-06 categories, OEM settings, remote/Home/Back and uninstall test.
- [ ] Only after independent recovery evidence discuss system HOME pilot (separate explicit approval).
