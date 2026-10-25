# Capability: projector-preview-only-apk

## ADDED Requirements

### Requirement: P-05 APK cannot become the system HOME

The Android TV trial package SHALL retain its normal SettingsActivity launch entry, but the compiled AndroidManifest SHALL explicitly disable the package HOME Activity. It SHALL also disable boot/update receiver and remote accessibility key interception service. Runtime HOME mutation code SHALL remain locked by __BT__PROJECTOR_HOME_SWITCH_AUDITED=false__BT__.

#### Scenario: APK is compiled

- **WHEN** a P-05 unsigned APK is built in pull-request CI
- **THEN** source and compiled binary manifest checks SHALL prove SettingsActivity enabled and HOME, receiver and key interception disabled, without projector access.

#### Scenario: APK is privately signed

- **WHEN** authorized owner invokes the manual signed release workflow on main with their existing signing secrets
- **THEN** it SHALL publish a new monotonically increasing prerelease tag only if signature, package, version and compiled HOME-disabled manifest all verify.

#### Scenario: Missing secret or mismatch

- **WHEN** a private key, manifest safety flag, expected version or APK signature check fails
- **THEN** the workflow SHALL fail before producing a publicly installable release.

#### Scenario: Owner installs as ordinary app

- **WHEN** the owner separately installs and opens the preview APK from stock Android TV
- **THEN** the original HOME SHALL remain selected and FreeMyProjector settings SHALL be accessible, but HOME mode and remote-key interception SHALL remain unavailable.
