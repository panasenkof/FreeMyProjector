# P-11: media-pipeline diagnostics on projector Android 9

## ADDED Requirements

### Requirement: Diagnose cross-app no-audio fast-video without changing system state
The project SHALL treat observed fast/silent video across applications as a potentially shared media pipeline failure and SHALL NOT claim a codec-pack APK or launcher switch can fix a vendor decoder without on-device evidence.

#### Scenario: Error occurs in stock launcher
- **WHEN** video accelerates without sound in YouTube and other apps remain affected until reboot
- **THEN** this SHALL be recorded as a stock-system fault, and test conclusions SHALL distinguish AudioTrack/AV sync, AudioFlinger/AudioPolicy, decoder resource state and output routing as separate hypotheses.

### Requirement: Prioritize a reversible Bluetooth A2DP isolation test
When the sound for the failing video is routed through an external Bluetooth audio accessory, the project SHALL prioritize distinguishing an A2DP session/routing/clock failure from a broader system media failure, without disabling Bluetooth globally or affecting remote pairing.

#### Scenario: Fast video with silent Bluetooth speaker
- **WHEN** the stock projector produces fast/silent video while connected to an external Bluetooth audio device
- **THEN** the test SHALL capture the broken state before any restart or route change, if feasible, and SHALL attempt a manual disconnect of only the audio device via the stock interface, followed by playback using the projector speakers.

#### Scenario: Speaker output works without reboot
- **WHEN** playback normalizes immediately on the projector speakers while Bluetooth audio is disconnected
- **THEN** the finding SHALL increase suspicion of A2DP/audio routing; it SHALL NOT be recorded as a proven codec defect without repeatable evidence.

#### Scenario: Speaker output still fails
- **WHEN** playback remains broken on the projector speakers after manual Bluetooth audio disconnection
- **THEN** the project SHALL examine persistent AudioFlinger/AudioPolicy/MediaCodec state rather than installing codec libraries.

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
