# P-10S — Readable configurable home shelf

## ADDED Requirements

### Requirement: Preserve the original eight-item default while allowing twelve favorites
The app SHALL initially suggest no more than eight launchable favorites, and SHALL allow the user to select at most twelve launchable installed apps without affecting how many apps can be installed.

#### Scenario: Default launcher view
- **WHEN** the user has never customized the shelf
- **THEN** at most eight installed launchable default favorites SHALL be displayed in their original priority order.

#### Scenario: Selecting any Play-installed app
- **WHEN** an app exposes a standard LAUNCHER or LEANBACK_LAUNCHER entry and a launch intent
- **THEN** it SHALL appear in the existing shelf editor without requiring a compiled catalog entry.

#### Scenario: Shelf is full
- **WHEN** the shelf already contains twelve favorites
- **THEN** the editor SHALL NOT add a thirteenth; deleting or removing an existing favorite SHALL allow adding another.
- **AND** the user SHALL still be able to install and access other apps outside favorites.

### Requirement: Keep every favorite visible and legible without scrolling
The app SHALL place all twelve-or-fewer favorites in one horizontal row and SHALL NOT shrink the reference icon width below 120px at 1920px reference resolution.

#### Scenario: One to eight favorites
- **WHEN** the shelf contains eight or fewer apps
- **THEN** the existing 48px spacing and eight-item dimensions SHALL be preserved.

#### Scenario: Nine through twelve favorites
- **WHEN** the user adds a ninth through twelfth favorite
- **THEN** the app SHALL reduce spacing and icon width/height proportionally, keeping the row within the viewport, never introducing scrolling or negative sizes.

### Requirement: Preserve settings and safety
The app SHALL keep the existing favorite preference format and D-pad/long-OK reorder flow, and SHALL NOT modify the original Xiaomi/Fengmi HOME or OEM system.

#### Scenario: Saved order and app removal
- **WHEN** the user saves a custom shelf, changes an item's position, or removes an installed app
- **THEN** remaining launchable favorites SHALL stay in the saved order and missing apps SHALL not render as broken tiles.

#### Scenario: New APK build
- **WHEN** the shelf changes are compiled or used
- **THEN** both P-04 HOME/recovery safety gates SHALL remain disabled and the stock HOME SHALL remain intact.

