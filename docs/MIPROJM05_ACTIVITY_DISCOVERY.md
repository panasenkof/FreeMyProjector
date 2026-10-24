# P-04A — найденные штатные Activity оптики и HDMI на MiProjM05/eva

**Источник:** вывод `adb shell dumpsys package <package>` от владельца устройства, 24.10.2026; Android 9 / API 28, сборка `PQ3B.190705.003.4185`. **Метод:** только чтение. Никаких `am start`, установки, переключения HOME и изменения калибровок не выполнялось.

## Непосредственно найденные Activity Resolver Table

Все ниже перечисленное — записи `Activity Resolver Table`, то есть кандидаты на точки входа. **Не установлены:** флаг `android:exported`, разрешения вызывающего приложения, разрешения Activity и alias-target, поведение при запуске из чужого UID. **Точные Action и категория DEFAULT для всех пяти imaging-входов подтверждены** дополнительным выводом от владельца (см. ниже); для Droidlogic фильтры пока не установлены. Отсутствие в отфильтрованном выводе НЕ доказывает отсутствие других Activity.

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

## Второй read-only вывод: точные Intent Action — 24.10.2026

Команда `dumpsys package com.fengmi.projector.imaging | Select-String ... -Context 7,10` показала **зарегистрированные** обработчики с `android.intent.category.DEFAULT`:

| Action в штатном APK | Activity или activity-alias |
|---|---|
| `com.fengmi.projector.imaging.action.START_FOCUS` | `com.fengmi.projector.imaging/.alias.FocusActivity` |
| `com.fengmi.projector.imaging.action.START_KEYSTONE` | `com.fengmi.projector.imaging/.alias.KeystoneActivity` |
| `com.fengmi.projector.imaging.action.START_AUTO_KEYSTONE` | `com.fengmi.projector.imaging/.alias.AutoKeystoneActivity` |
| `com.fengmi.projector.imaging.action.GUIDE_START` | `com.fengmi.projector.imaging/.alias.GuideActivity` |
| `android.intent.action.MAIN` | `com.fengmi.projector.imaging/.access.ImagingFeatureActivity` |

Также найден **отдельный** `com.android.setupwizard.action.HOOK_BEGIN` / `PRE_CORE_SETUP` в `com.fengmi.projector.imaging/.setupwizard.ForMoiveSetupwizard`. **Не запускать**: это установочный мастер устройства, он не нужен для обычной фокусировки и может затронуть первичную настройку.

Наличие action-фильтра и записи resolver **не доказывает**, что запуск разрешён из пакета FreeMyProjector (`com.fader.freemyprojector`). Для каждого `activity-alias` Android манифест может независимо задавать `android:exported`, `android:permission` и `android:targetActivity`. Не считать, что `START_AUTO_KEYSTONE` обязательно означает автоматическую **калибровку** — это может быть другое действие.

Для `com.fengmi.fmsettings` применённый пользователем фильтр не показал раздела `Activity Resolver Table`; это **не подтверждение отсутствия собственных неэкспортируемых экранов и сервисов**.

`android.permission.TV_INPUT_HARDWARE: granted=true` встречается в `dumpsys` пакетов imaging/fmsettings/tvinput. Это сообщение о *разрешениях штатного приложения*, а не о праве FreeMyProjector получать тот же доступ, менять оптические параметры или общаться с TV hardware API.

## Значение для архитектуры

1. Основной путь P-06: после проверки экспортируемости и доступа из обычного APK добавлять **ярлыки на заводские экраны** фокусировки/трапеции, не писать новый оптический драйвер и не менять их действия. Запуск через `Intent` / `ComponentName` должен быть отдельным шагом спецификации и проходить проверку наличия пакета и разрешений.
2. Системный HDMI `com.droidlogic.tvinput` уже защищён P-04; `HdmiExtendSetupActivity` — лишь предполагаемый **экран настроек**, а не доказанная команда смены входа. Список входов изучить через `TvInputManager` отдельно.
3. Возврат назад, D-pad и пульт, поведение сна/перезапуска и сохранение заводской настройки оптики проверять на самом устройстве. Если компонент недоступен из чужого UID, кнопка в оболочке должна быть скрыта/неактивна с безопасным переходом в общие настройки, но не пытаться обходить ограничения.
4. `com.google.android.tvlauncher` продолжает быть заводским HOME. Никаких изменяющих ADB-команд, `pm disable*` или запуска неподтверждённых Activity до отдельной инструкции и разрешения.

## Следующий шаг: исследовать AndroidManifest.xml без запуска оптики

**Прямые Intent Action уже получены.** Повторять поиск resolver не нужно. Следующая задача — определить `exported`, `permission` и `targetActivity` для OEM activity-alias через **локальный анализ** манифеста. Это не запускает ни одну Activity и не меняет состояние Android.

На Windows PowerShell с уже заданной переменной `$adb` и установленным Android SDK Build Tools (`aapt2.exe`):

```powershell
# 1. Узнать путь APK. Команда только читает сведения PackageManager.
& $adb shell pm path com.fengmi.projector.imaging

# 2. Найти aapt2.exe локально (если SDK установлен в типовом каталоге).
Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Filter aapt2.exe -Recurse -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty FullName

# 3. При наличии доступного base.apk: скопировать OEM APK на локальный компьютер,
# НЕ публиковать его; не исполнять и не декомпилировать лишние компоненты.
# Пример: замените <ПУТЬ_ИЗ_pm_path> на точный путь после 'package:'.
# & $adb pull '<ПУТЬ_ИЗ_pm_path>' "$env:TEMP\miprojm05-imaging-base.apk"

# 4. После копирования посмотреть только атрибуты Activity в манифесте:
# & '<ПУТЬ_К_aapt2.exe>' dump xmltree "$env:TEMP\miprojm05-imaging-base.apk" --file AndroidManifest.xml |
#   Select-String -Pattern '(activity-alias|FocusActivity|KeystoneActivity|AutoKeystoneActivity|GuideActivity|ImagingFeatureActivity|android:exported|android:permission|android:targetActivity)' -Context 2,4
```

Для проверки `exported` следует изучить **полные блоки соответствующих `activity-alias` и связанной Activity** в дереве, а не произвольные совпадения по всему файлу. Факт наличия `intent-filter` при отсутствии явного `exported` нужно оценивать с учётом версии Android и приложения. Руководства: https://developer.android.com/guide/topics/manifest/activity-alias-element и https://developer.android.com/tools/aapt2 .

Локальный APK не прикреплять к GitHub, не копировать в каталог проекта, не присылать приватные данные. При необходимости можно прислать **только** очищенные блоки `activity-alias` из манифеста.

### Предыдущая необязательная команда контекста

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

## Что остаётся НЕ проверенным

- Реальный ручной/автоматический фокус и калибровка от нашего приложения (заводские меню сфотографированы, запуск из чужого APK — нет).
- Экспортируемость и доступность этих Activity без привилегий; AndroidManifest пока не получен.
- Реальная работа HDMI и пульта после любого изменения HOME.
- Безопасный откат HOME на Android 9. `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED = false` должен оставаться закрытым.

См. [P-04 аудит](P04_HOME_SAFETY_AUDIT.md), [оптика](PROJECTOR_FUNCTIONS.md) и [CleanYourTV для MiProjM05](CLEANYOURTV_MIPROJM05_RESEARCH.md).
