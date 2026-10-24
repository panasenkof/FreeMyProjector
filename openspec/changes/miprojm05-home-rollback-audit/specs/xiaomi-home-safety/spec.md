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

#### Scenario: Initial disabled-package audit
- **WHEN** the owner runs the filtered disabled list `pm list packages -d`
- **THEN** record no matched disabled candidates, without claiming all packages system-wide are enabled

### Requirement: Default-deny HOME mutation
The existing source-level safety gate MUST remain closed until a separately approved, firmware-tested rollback protocol exists.

#### Scenario: First APK or audit PR
- **WHEN** FreeMyProjector is built during P-04 investigation
- **THEN** `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED` remains `false` and HOME switching remains unavailable

#### Scenario: Rollback not confirmed on Android 9
- **WHEN** source relies on Android 11+ behavior or an untested fallback to restore HOME on API 28
- **THEN** the project SHALL NOT enable its HOME switch