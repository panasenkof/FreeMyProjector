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

### Requirement: OEM optical/picture entry points are not a substitute for rollback

An external launcher SHALL not invoke automatic calibration or change picture settings merely because an OEM manifest declares a callable alias. Future launcher entry points SHALL preserve the native picture-mode UI and remote input/pairing independently of the custom HOME.

#### Scenario: OEM manifest read-only verification
- **WHEN** a local `aapt2 dump xmltree` of `FengmiImaging.apk` confirms target `ImagingFeatureActivity` exported=true, and enabled focus/keystone/auto-keystone/guide aliases each have intent filters without an explicit exported attribute
- **THEN** document their Android 9 default exported=true status as **manifest-level evidence** but not as proof of runtime accessibility or motor behavior.

#### Scenario: Picture controls present in a photo
- **WHEN** the OEM 'Изображение' menu shows picture mode and camera brightness
- **THEN** require discovery and preservation of those settings through OEM UI instead of inventing numeric adjustments or assuming camera brightness equals projector lamp brightness.

#### Scenario: Consent for calibration
- **WHEN** an alias such as `START_AUTO_KEYSTONE` may initiate a hardware action
- **THEN** do not auto-run it on installation or navigation; reserve actual tests for a separate consented and reversible device pilot.

### Requirement: Strictly passive OEM alias preflight

The application MAY inspect factory `com.fengmi.projector.imaging` component metadata only on exact audited MiProjM05/eva Android 9 build `.4185`. Inspection SHALL NOT start activities, trigger autofocus/autocalibration or silently elevate permissions.

#### Scenario: Focus/keystone aliases exist
- **WHEN** the factory focus/keystone alias matches the manifest-observed target `ImagingFeatureActivity`, is enabled/exported and requires no OEM permission
- **THEN** prepare an explicit Intent as inert data; do not launch the screen or expose a UI shortcut until a separate approval and live test.

#### Scenario: Firmware or access differs
- **WHEN** firmware is not exact, aliases are missing, disabled, nonexported, retargeted or permission-protected
- **THEN** return fail-closed and do not attempt any OEM action.

#### Scenario: Automated calibration remains blocked
- **WHEN** a developer attempts to add AutoKeystone/Guide or hardware adjustment to this passive bridge
- **THEN** static safety tests SHALL reject the change, and the existing HOME safety gate remains closed.

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
