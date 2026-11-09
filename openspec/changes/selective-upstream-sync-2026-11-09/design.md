# Design — P-10 safe shelf delta

- Единственный источник предустановленных известных приложений —
  `HomeApps.SHELF`; **не** создавать второй реестр/адаптер.
- Пять записей добавлены в конец массива, не меняя прежний порядок.
- `shelfPackages()` сохраняет `Prefs.shelf()` как приоритет владельца;
  новые package IDs показываются только с `launchIntent`.
- Ограничение `MAX_SHELF=8` не меняется на 2 ГБ устройстве.
- Режим логотипа `white` из нового upstream не переносим без пересмотра
  старого extractor; fallback на обычный TV tile уже существует.
- `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED=false` и
  `PROJECTOR_RECOVERY_AUDITED=false` инвариантны.
- CI — Python unittest только по источникам и полная Android 9+ сборка
  существующим `build.sh`; никакого `adb` или аппаратных проверок.
