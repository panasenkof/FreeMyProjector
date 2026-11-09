# P-11: media-pipeline diagnostics on projector Android 9

## ADDED Requirements

### Requirement: Diagnose cross-app no-audio fast-video without changing system state
The project SHALL treat observed fast/silent video across applications as a potentially shared media pipeline failure and SHALL NOT claim a codec-pack APK or launcher switch can fix a vendor decoder without on-device evidence.

#### Scenario: Error occurs in stock launcher
- **WHEN** video accelerates without sound in YouTube and other apps remain affected until reboot
- **THEN** this SHALL be recorded as a stock-system fault, and test conclusions SHALL distinguish AudioTrack/AV sync, AudioFlinger/AudioPolicy, decoder resource state and output routing as separate hypotheses.

### Requirement: Compare normal and broken states with privacy and safety
The project SHALL provide a read-only procedure for collecting normal and broken audio state, with local-only storage and no system mutation.

#### Scenario: Live diagnostic session
- **WHEN** the owner has an already authorized ADB session and the verified stock HOME baseline matches
- **THEN** only fixed read-only `dumpsys` and optional `logcat -d` commands SHALL be suggested, with no package disabling, media-server restart, root, firmware modification or HOME switch.

#### Scenario: The manufacturer omits a media service
- **WHEN** an Android 9 service is unavailable or a status field is absent
- **THEN** the outcome SHALL be recorded as unavailable, NOT as proof that the codec is healthy.

#### Scenario: Diagnostic logs include personal information
- **WHEN** raw logs or dumps are collected
- **THEN** they SHALL stay on the owner's PC outside Git and be reviewed/redacted before any sharing.

### Requirement: Validate only reversible mitigations
The project SHALL require physical verification before recommending any user setting change as a mitigation.

#### Scenario: A proposed audio codec or output workaround
- **WHEN** a manual PCM, audio route or player option is proposed
- **THEN** the previous value SHALL be recorded, a single parameter SHALL be tested, and the original value SHALL be restorable without root or factory reset.
