# Xiaomi MiProjM05 HOME safety

## ADDED Requirements

### Requirement: Confirm exact firmware and current HOME before any switch
The system SHALL preserve an evidence-backed record of the original HOME component for the identified Xiaomi firmware, without collecting device-identifying network or serial data.

#### Scenario: Read-only device baseline
- **WHEN** the owner provides the P-01 real-device diagnostic result
- **THEN** record model `MiProjM05`, device `eva`, API `28`, build `PQ3B.190705.003.4185` and HOME `com.google.android.tvlauncher/.MainActivity` with read-only provenance

#### Scenario: Firmware changes
- **WHEN** model, build, HOME or OEM package state differs from the baseline
- **THEN** prior rollback assumptions SHALL NOT be used without a new audit

### Requirement: Protect Xiaomi optical functionality
The application MUST NOT disable or replace unknown Xiaomi focus, keystone, remote, settings or other OEM services.

#### Scenario: Focus / keystone dependencies not identified
- **WHEN** package inventory or functional dependency evidence is incomplete
- **THEN** no HOME switching or package disabling is allowed

#### Scenario: Candidate package inferred only by name
- **WHEN** an installed package name looks related to focus or keystone
- **THEN** mark it as a candidate, NOT as a proven implementation or safe-to-disable package

### Requirement: Read-only audit before rollback implementation
The project SHALL provide a minimal, non-mutating procedure for owners to collect filtered package names without publishing full lists, credentials or network identifiers.

#### Scenario: Device query
- **WHEN** the owner follows the P-04 collection procedure
- **THEN** only package enumeration queries are run, no install, launcher switch, setting write, service start, reboot or package state change

### Requirement: Safeguard observed Xiaomi OEM components

The application MUST skip package-disabling operations for observed Fengmi and Xiaomi projector packages and MUST also conservatively protect unknown Formovie/Fengmi namespaces.

#### Scenario: Installed OEM inventory
- **WHEN** the owner provides the filtered real-device package inventory for MiProjM05 on 24.10.2026
- **THEN** protect `com.fengmi.projector.imaging`, `com.fengmi.fmsettings`, `com.fengmi.platform`, autofocus/test and model-specific `com.fengmi.*` packages, and preserve the installed original `com.google.android.tvlauncher`

#### Scenario: Unknown future Fengmi service
- **WHEN** an installed package to be disabled starts with `com.fengmi.`, `com.formovie.`, or `cn.formovie.`
- **THEN** skip disabling it regardless of presence in any optional debloat list

#### Scenario: Second installed-package inventory and platform protections
- **WHEN** the owner supplies the second read-only filtered list of 18 OEM packages from `PQ3B.190705.003.4185`
- **THEN** all detected Droidlogic packages (`com.droidlogic` and descendants) and `com.android.camera2` SHALL be protected from both package-disabling paths, as already are `com.fengmi.*`, `com.formovie.*` and `cn.formovie.*`
- **AND** retaining the package MUST NOT be treated as evidence that HDMI, focus, auto-keystone or camera services work after switching HOME

#### Scenario: Future Droidlogic namespace package
- **WHEN** a future disable target is `com.droidlogic` or starts with `com.droidlogic.`
- **THEN** disabling it MUST be skipped regardless of whether it was present in the 24.10.2026 list

#### Scenario: Initial disabled-package audit
- **WHEN** the owner runs the filtered disabled list `pm list packages -d`
- **THEN** record no matched disabled candidates, without claiming all packages system-wide are enabled

### Requirement: Pre-change snapshot and rollback are mandatory gates

The project MUST NOT change default HOME or disable any system package until the owner has created a local read-only evidence snapshot of original HOME and package states, the recovery procedure has passed offline tests, the independent device recovery path has been verified, and separate approval is given for the specific test.

#### Scenario: A backup is claimed but not produced
- **WHEN** only a plan or a previously pulled single OEM APK exists, without a verified timestamped snapshot of HOME, installed/disabled packages and firmware build
- **THEN** HOME mutation and package deactivation MUST remain locked, and it MUST NOT claim a full firmware backup.

#### Scenario: Original package states
- **WHEN** a rollback is prepared
- **THEN** the original snapshot SHALL not be overwritten by subsequent runs and restoration SHALL preserve packages that were disabled before testing rather than enabling all packages.

#### Scenario: Recovery if ADB or remote is unavailable
- **WHEN** ADB or remote control access is lost during a proposed modification
- **THEN** the procedure SHALL have a previously verified recovery route; if not, reject the HOME pilot rather than assume root, recovery image, or factory reset is safe.

#### Scenario: Android 9 HOME fallback
- **WHEN** validating recovery from a launcher change on API 28
- **THEN** `FallbackHome` or factory test activities MUST NOT count as a working launcher, and reported `set-home-activity` success alone MUST NOT count as verified HOME restoration.

### Requirement: Preserve remote pairing and actual picture settings

The system SHALL preserve factory remote pairing/re-pairing, remote keys and original picture settings, including picture mode and the camera-brightness entry shown in the user's screenshot.

#### Scenario: Remote pairing is not yet verified
- **WHEN** Bluetooth/IR pairing mechanism or re-pairing and fallback input are unverified on MiProjM05
- **THEN** no default HOME modification may be approved, even if the remote's D-pad works before the change.

#### Scenario: Remote long press
- **WHEN** testing the remote before and after changes
- **THEN** Home, Back, D-pad/OK, Settings key, sleep/power, voice if available, and volume-button long press SHALL be part of the acceptance procedure, with actual re-pairing recovery evaluated.

#### Scenario: Picture-screen preservation
- **WHEN** testing a new launcher or native-settings entry point
- **THEN** preserve access to OEM 'Изображение' and record original picture mode and all actually present picture controls without inventing firmware values; do not assume the camera-brightness setting is projector-lamp brightness.

### Requirement: Read-only baseline helper is strictly device-scoped

The owner-facing snapshot tool SHALL collect the original HOME, all installed/enabled/disabled package names and build provenance using only read-only ADB operations; SHALL NOT change system state or save device-identifying serial/IP fields; and SHALL refuse incomplete or contradictory data.

#### Scenario: Audited projector baseline
- **WHEN** exactly one authorized MiProjM05/eva with Android 9 API 28 and build `PQ3B.190705.003.4185` reports the original HOME and consistent package inventories
- **THEN** save a new never-overwritten local JSON record outside the repository and a SHA256 checksum, while explaining that this is not firmware/data/calibration backup.

#### Scenario: Incomplete evidence
- **WHEN** device authorization, exact build, factory HOME, HOME claimant query or the installed/enabled/disabled partition is missing, ambiguous or inconsistent
- **THEN** fail closed without writing a partial snapshot or executing system-changing ADB commands.

#### Scenario: Preserving originally disabled packages
- **WHEN** the device reports an existing disabled package
- **THEN** the baseline SHALL record it as originally disabled instead of treating all packages as enabled.

#### Scenario: Default output in local project workspace
- **WHEN** the Windows read-only snapshot script runs without an explicit output directory and is checked out in `D:\Git\FreeMyProjector\FreeMyProjector-main`
- **THEN** save the new dated private snapshot next to (not inside) the Git checkout, in `D:\Git\FreeMyProjector`, without touching a previous snapshot or contacting any mutating ADB API.

#### Scenario: Backup output path within repository
- **WHEN** an output location is inside the source tree
- **THEN** reject it before contacting ADB, to avoid accidentally committing per-device inventories.

### Requirement: Compare baseline with projector without performing rollback

The owner SHALL be able to validate a saved P-04B snapshot offline and review current HOME/package differences without any device write, file output, firmware operation or claim that HOME rollback is safe.

#### Scenario: Verify before ADB
- **WHEN** the owner requests snapshot verification only
- **THEN** SHA256 and required device metadata SHALL be validated entirely offline, with no ADB command and no saved-file mutation.

#### Scenario: Check current configuration
- **WHEN** the saved snapshot is valid and exactly one authorized projector is present with matching MiProjM05/eva Android 9 build
- **THEN** report current HOME and installed/enabled/disabled package differences, or `matches-baseline`, using read-only commands and displaying non-executable review actions.

#### Scenario: Snapshot tampering or unsupported firmware
- **WHEN** SHA256 mismatches, snapshot structure is malformed, firmware differs or required factory components are missing or disabled
- **THEN** refuse to produce a restoration preview and never attempt to modify the device.

#### Scenario: Changed package states
- **WHEN** a package was disabled in the snapshot and is enabled now
- **THEN** report the original disabled state for separate review; never automatically enable or disable packages, delete added packages or treat `FallbackHome` as working HOME.

### Requirement: Default-deny HOME mutation
The existing source-level safety gate MUST remain closed until a separately approved, firmware-tested rollback protocol exists.

#### Scenario: First APK or audit PR
- **WHEN** FreeMyProjector is built during P-04 investigation
- **THEN** `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED` remains `false` and HOME switching remains unavailable

#### Scenario: Rollback not confirmed on Android 9
- **WHEN** source relies on Android 11+ behavior or an untested fallback to restore HOME on API 28
- **THEN** the project SHALL NOT enable its HOME switch