# Projector functions preservation spec

## ADDED Requirements

### Requirement: Keep stock Xiaomi optical functionality
The system SHALL preserve access to the factory focus and vertical keystone functions on Xiaomi MiProjM05 and MUST NOT disable unknown OEM dependencies.

#### Scenario: Unknown factory service dependencies
- **WHEN** stock focus/keystone package dependencies are unknown for MiProjM05
- **THEN** no system package may be disabled, no HOME switch activated, and no unverified focus/keystone Intent invoked.

#### Scenario: Preparing HOME switch
- **WHEN** switching HOME is proposed
- **THEN** identify factory optical component dependencies, preserve them, provide tested rollback, and demonstrate optical functions first without changing HOME.

### Requirement: Confirm factory Activity entry points before UI integration
The project SHALL distinguish OEM component names found in a read-only resolver table from exported, callable and functionally verified Activity entry points. Unknown access MUST NOT trigger privilege bypasses or unreviewed calibration commands.

#### Scenario: Read-only resolver discovery on MiProjM05
- **WHEN** the device owner supplies filtered `dumpsys package` output listing imaging aliases FocusActivity, KeystoneActivity, AutoKeystoneActivity, GuideActivity and ImagingFeatureActivity
- **THEN** document those exact class candidates and their read-only provenance while marking `exported`, required permissions and actual opening as unverified.

#### Scenario: External launching still unverified
- **WHEN** Activity export flags, permission requirements, target aliases or real-device behavior are unknown
- **THEN** do not enable user-visible launcher shortcuts to those components and do not invoke them automatically.

#### Scenario: HDMI settings versus input switching
- **WHEN** `com.droidlogic.tvinput/.settings.HdmiExtendSetupActivity` is found in the resolver
- **THEN** treat it as a candidate for HDMI settings only, not as confirmed HDMI input switching.

### Requirement: Port safe ADB authorization fix for Android 9
The Android ADB client SHALL support bounded signed-only reconnection during first authorization on Android 8–10 without issuing system-modification commands.

#### Scenario: Android 8–10 permission prompt
- **WHEN** the ADB public key is offered
- **THEN** the client periodically tries a signed-only fresh connection until the bounded approval deadline, never using that connection to change settings automatically.

#### Scenario: Android 11+
- **WHEN** authorization starts
- **THEN** retain the previous timeout behavior.

#### Scenario: Unapproved Xiaomi HOME
- **WHEN** the app is built with this partial port
- **THEN** `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED` remains false.
