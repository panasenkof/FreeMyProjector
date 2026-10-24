# Projector functions preservation spec

## ADDED Requirements

### Requirement: Keep stock Xiaomi optical functionality
#### Scenario: Unknown factory service dependencies
- **WHEN** stock focus/keystone package dependencies are unknown for MiProjM05
- **THEN** no system package may be disabled, no HOME switch activated, and no unverified focus/keystone Intent invoked.

#### Scenario: Preparing HOME switch
- **WHEN** switching HOME is proposed
- **THEN** identify factory optical component dependencies, preserve them, provide tested rollback, and demonstrate optical functions first without changing HOME.

### Requirement: Port safe ADB authorization fix for Android 9
#### Scenario: Android 8–10 permission prompt
- **WHEN** the ADB public key is offered
- **THEN** the client periodically tries a signed-only fresh connection until the bounded approval deadline, never using that connection to change settings automatically.

#### Scenario: Android 11+
- **WHEN** authorization starts
- **THEN** retain the previous timeout behavior.

#### Scenario: Unapproved Xiaomi HOME
- **WHEN** the app is built with this partial port
- **THEN** `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED` remains false.
