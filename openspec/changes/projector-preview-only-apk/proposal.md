# P-05 — пробный APK v0.1.1, не HOME

## Why

P-06 native-settings menu compiled, but no physical projector app install. Android Manifest still declared HomeActivity HOME-eligible; a normal APK install could expose a new candidate in system HOME chooser despite the P-04 runtime lock. Need fail-closed trial APK which cannot displace the factory launcher, and signing with the existing private key.

## Scope

- Increment version 0.1.0 → 0.1.1, versionCode=1001; same package ID and signing identity.
- AndroidManifest: HomeActivity disabled; boot receiver disabled; RemoteKeyService disabled; SettingsActivity/TV launcher entry still enabled.
- Fail closed at source and **compiled binary** manifest with PR CI + signed release checks; never publish or use unsigned artifact for device install.
- New signed prerelease only through manual GitHub Actions workflow on main with existing secrets; no automatic device install/ADB writes.
- Owner-level manual P-05/P-06 checklist for app navigation and OEM settings shortcuts before any HOME pilot.

## Excluded

No HOME switch, system debloat, firmware or OTA change, pairing reset, optic calibration, remote accessibility interception, or automatic watchdog.
