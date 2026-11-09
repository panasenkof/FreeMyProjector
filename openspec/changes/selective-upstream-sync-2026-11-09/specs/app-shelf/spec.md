# App shelf — selective RU metadata sync

### Requirement: Recognize installed Russian streaming apps
The existing projector app shelf SHALL know the package IDs for
Kinopoisk, Okko, Premier, Amediateka and Wink without installing any apps.

#### Scenario: Service is installed with launcher Activity
- **WHEN** a supported service is installed and exposes a launch intent
- **THEN** it SHALL be available in the existing shelf candidate list
- **AND** the existing card/logo fallback SHALL be used.

#### Scenario: Service is absent
- **WHEN** a service is absent or has no launch intent
- **THEN** it SHALL NOT be inserted into the default shelf.

### Requirement: Preserve existing shelf semantics
#### Scenario: A person has selected their own apps
- **WHEN** a custom shelf preference exists
- **THEN** it SHALL remain authoritative; reference metadata MUST NOT reorder it.

#### Scenario: Default shelf is already full
- **WHEN** 8 earlier default apps are eligible
- **THEN** the new references SHALL NOT increase the default 8-app limit.

### Requirement: No projector system writes
#### Scenario: Reference metadata or CI changes are applied
- **WHEN** the APK is built or the shelf is enumerated
- **THEN** no OEM package SHALL be disabled, no HOME SHALL be changed,
  and both P-04 gates SHALL remain false.
