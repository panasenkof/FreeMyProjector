# Capability: projector-native-settings

## ADDED Requirements

### Requirement: native-only projector capabilities

FreeMyProjector SHALL expose all owner-reported existing MiProjM05 capabilities except 3D as user-invoked navigation shortcuts, without implementing or triggering motor/keystone/HAL/HDMI/BT/system modification itself.

#### Scenario: user opens native projector catalog
- **WHEN** the user navigates FreeMyProjector Settings using a hardware remote
- **THEN** a Projector Features item opens six categories containing the user-confirmed picture, optical, sources, sound, connectivity and system functions; Back returns to the prior category and focus.

#### Scenario: OEM Activity available
- **WHEN** the user explicitly selects Focus, Keystone, HDMI or remote pairing on the audited MiProjM05
- **THEN** an OEM target may be launched only after strict package, firmware, exported, enabled, permission and system guards; unauthorized/unresolved targets fall back to non-mutating Settings navigation.

#### Scenario: exact OEM deep link missing
- **WHEN** a standard Android 9 action is unavailable or a vendor Activity is inaccessible
- **THEN** show the existing settings fallback; never invent native controls or silently change values.

#### Scenario: unavailable 3D or unsafe calibration
- **WHEN** the catalog is rendered or opened
- **THEN** no 3D option or automatic calibration action exists; selecting an auto-calibration label only navigates to the native Keystone page for manual decisions.
