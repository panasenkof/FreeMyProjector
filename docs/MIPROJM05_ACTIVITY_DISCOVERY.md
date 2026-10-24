# P-04A — найденные штатные Activity оптики и HDMI на MiProjM05/eva

**Источник:** вывод `adb shell dumpsys package <package>` от владельца устройства, 24.10.2026; Android 9 / API 28, сборка `PQ3B.190705.003.4185`. **Метод:** только чтение. Никаких `am start`, установки, переключения HOME и изменения калибровок не выполнялось.

## Непосредственно найденные Activity Resolver Table

Все ниже перечисленное — записи `Activity Resolver Table`, то есть кандидаты на точки входа. **На первом этапе не были установлены:** экспортируемость, права, targetActivity, фильтры Action и поведение запуска из чужого UID. Затем отдельный локальный манифест и вывод с контекстом подтвердили `targetActivity`, декларативный `exported` и точные Action (подробности ниже). **Практическая работоспособность запуска из чужого приложения до сих пор не проверена.** Отсутствие в отфильтрованном выводе НЕ доказывает отсутствие других Activity.

| Пакет | Запись Activity в `dumpsys` | Вероятное назначение (не проверено запуском) |
|---|---|---|
| `com.fengmi.projector.imaging` | `com.fengmi.projector.imaging/.alias.FocusActivity` | Штатный интерфейс фокусировки |
| тот же | `com.fengmi.projector.imaging/.alias.KeystoneActivity` | Штатная коррекция трапеции |
| тот же | `com.fengmi.projector.imaging/.alias.AutoKeystoneActivity` | Автоматическая коррекция; **не отождествлять с автоматической калибровкой без проверки** |
| тот же | `com.fengmi.projector.imaging/.alias.GuideActivity` | Экран руководства/мастера |
| тот же | `com.fengmi.projector.imaging/.access.ImagingFeatureActivity` | Вход в общие функции изображения (MAIN/DEFAULT) |
| `com.formovie.gsettings` | `com.formovie.gsettings/.ui.activity.MainActivity` | Экран фирменных настроек (MAIN/LAUNCHER) |
| `com.droidlogic.tvinput` | `com.droidlogic.tvinput/.settings.TvSettingsActivity` | Настройки входов ТВ |
| тот же | `com.droidlogic.tvinput/.shortcut.ShortCutActivity` | Служебный быстрый вход; назначение неясно |
| тот же | `com.droidlogic.tvinput/.settings.ChannelSearchActivity` | Поиск каналов, возможно неактуально для проектора |
| тот же | `com.droidlogic.tvinput/.settings.HdmiExtendSetupActivity` | Настройки HDMI; **не является доказательством переключения HDMI источника** |

Для `com.fengmi.fmsettings` применённый пользователем фильтр не показал раздела `Activity Resolver Table`; это **не подтверждение отсутствия собственных неэкспортируемых экранов и сервисов**.

`android.permission.TV_INPUT_HARDWARE: granted=true` встречается в `dumpsys` пакетов imaging/fmsettings/tvinput. Это сообщение о *разрешениях штатного приложения*, а не о праве FreeMyProjector получать тот же доступ, менять оптические параметры или общаться с TV hardware API.

## Значение для архитектуры

1. Основной путь P-06: после проверки экспортируемости и доступа из обычного APK добавлять **ярлыки на заводские экраны** фокусировки/трапеции, не писать новый оптический драйвер и не менять их действия. Запуск через `Intent` / `ComponentName` должен быть отдельным шагом спецификации и проходить проверку наличия пакета и разрешений.
2. Системный HDMI `com.droidlogic.tvinput` уже защищён P-04; `HdmiExtendSetupActivity` — лишь предполагаемый **экран настроек**, а не доказанная команда смены входа. Список входов изучить через `TvInputManager` отдельно.
3. Возврат назад, D-pad и пульт, поведение сна/перезапуска и сохранение заводской настройки оптики проверять на самом устройстве. Если компонент недоступен из чужого UID, кнопка в оболочке должна быть скрыта/неактивна с безопасным переходом в общие настройки, но не пытаться обходить ограничения.
4. `com.google.android.tvlauncher` продолжает быть заводским HOME. Никаких изменяющих ADB-команд, `pm disable*` или запуска неподтверждённых Activity до отдельной инструкции и разрешения.

## Следующий **только читающий** шаг

На Windows/PowerShell с уже настроенным `$adb`:

```powershell
# Показать только окружение найденных записей, без полного dumpsys.
$targets = @(
  @{ Package = 'com.fengmi.projector.imaging'; Regex = '(?i)(\.alias\.(FocusActivity|KeystoneActivity|AutoKeystoneActivity|GuideActivity)|\.access\.ImagingFeatureActivity)' },
  @{ Package = 'com.formovie.gsettings'; Regex = '(?i)\.ui\.activity\.MainActivity' },
  @{ Package = 'com.droidlogic.tvinput'; Regex = '(?i)(\.settings\.(TvSettingsActivity|HdmiExtendSetupActivity)|\.shortcut\.ShortCutActivity)' }
)
foreach ($t in $targets) {
  "=== $($t.Package) ==="
  & $adb shell dumpsys package $t.Package |
    Select-String -Pattern $t.Regex -Context 6,8 |
    Select-Object -First 10
}
```

Этот вывод позволит увидеть соседние Action/Category и, возможно, часть описания компонентов. **Даже если он не показывает `exported` — нельзя автоматически считать активити общедоступными.** Для достоверного ответа о `exported`, `permission` и `targetActivity` потребуется локально прочитать **AndroidManifest.xml заводского APK** (через `pm path`, при допустимости `adb pull`, и Android build-tools `aapt2`/apkanalyzer). APK оставлять только локально, не загружать в открытый GitHub и не пытаться декомпилировать защищённые компоненты DRM.

## Результат чтения AndroidManifest.xml на ПК владельца (24.10.2026)

Владелец выполнил `adb pull /system/priv-app/FengmiImaging/FengmiImaging.apk` (скопирован **только один системный APK**, ~8.36 МБ) и локально просмотрел `aapt2 dump xmltree ... --file AndroidManifest.xml`. Прочтение не изменило проектор; APK в репозиторий не добавлялся. В выводе:

- `com.fengmi.projector.imaging/.access.ImagingFeatureActivity` имеет `android:enabled=true`, **явный `android:exported=true`**, Intent MAIN/DEFAULT.
- `.alias.FocusActivity`, `.alias.KeystoneActivity`, `.alias.AutoKeystoneActivity`, `.alias.GuideActivity` имеют `android:enabled=true`, `targetActivity=".access.ImagingFeatureActivity"` и ранее найденные Action/DEFAULT.
- У этих alias в показанных блоках **нет явного `android:exported`**, но на Android 9 для `activity-alias` с `intent-filter` Android трактует пропущенный `exported` как `true` (см. https://developer.android.com/guide/topics/manifest/activity-alias-element). Это подтверждение **декларативной экспортируемости**, но не успешного вызова извне или безопасного поведения функций.
- По показанным строкам отдельный `android:permission` не обнаружен; при необходимости проверить полный манифест и runtime-ограничения. Даже при успешном `startActivity` нельзя считать определёнными последствия для мотора/калибровки.

**Следующий этап:** подготовить отдельно согласуемый пробный запуск заводского экрана из подписанного обычного APK при сохранённом заводском HOME. Не начинать с `START_AUTO_KEYSTONE`: вызываемая оптика может изменять геометрию автоматически. Перед пилотом соблюдать [P-04B](MIPROJM05_BACKUP_REMOTE_PICTURE_ROLLBACK.md) по пульту, изображению, backup и откату.

## Что остаётся НЕ проверенным

- Реальный ручной/автоматический фокус и калибровка от нашего приложения (заводские меню сфотографированы, запуск из чужого APK — нет).
- Декларативная экспортируемость подтверждена манифестом на Android 9; **практическая** доступность из другого APK и runtime-ограничения пока не проверены.
- Реальная работа HDMI и пульта после любого изменения HOME.
- Безопасный откат HOME на Android 9. `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED = false` должен оставаться закрытым.

См. [P-04 аудит](P04_HOME_SAFETY_AUDIT.md), [оптика](PROJECTOR_FUNCTIONS.md) и [CleanYourTV для MiProjM05](CLEANYOURTV_MIPROJM05_RESEARCH.md).
