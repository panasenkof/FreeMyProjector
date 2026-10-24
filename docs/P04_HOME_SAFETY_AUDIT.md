# P-04 — безопасная проверка HOME, оптики и штатных пакетов Xiaomi MiProjM05

## Достоверный результат от владельца (24 октября 2026)
Запущен `tools/read-only-device-info.ps1` на **реальном проекторе** с уже подключённым ADB по доверенной локальной сети; статус `connected`, модель `MiProjM05`, код `eva`, Android `9` (API `28`), сборка `PQ3B.190705.003.4185`, текущий HOME `com.google.android.tvlauncher/.MainActivity`.

Это **не** тест установки FreeMyProjector, безопасности замены HOME или сохранности фокусировки после замены. IP, serial, MAC и имена Wi-Fi здесь не записаны.

## Результат первой инвентаризации OEM (24 октября 2026)

Пользователь выполнил `adb shell pm list packages` с локальным фильтром. **Найдены**:

```text
com.android.tv.settings
com.fengmi.projector135MGN
com.fengmi.autofocustest
com.fengmi.platform
com.fengmi.projector045G
com.fengmi.projector055G
com.google.android.tvrecommendations
com.google.android.leanbacklauncher.recommendations
com.google.android.tvlauncher
com.fengmi.fmsettings
android.autoinstalls.config.xiaomi
com.fengmi.projector.imaging
com.google.android.leanbacklauncher
com.fengmi.testsuite
```

Вторая команда `pm list packages -d` с тем же фильтром совпадений **не дала**. Это значит только отсутствие *совпавших с фильтром* отключённых пакетов, но не доказывает, что вообще все приложения включены. Функции отдельных компонентов **не проверены запуском и не определены инструментально**.

### Вторая инвентаризация OEM — расширенный фильтр (24 октября 2026)

После изучения [CleanYourTV MiProjM05](CLEANYOURTV_MIPROJM05_RESEARCH.md) владелец повторил **только чтение** с фильтром `droidlogic|formovie|fengmi|tvinput|camera2` и подтвердил следующие **18 установленных пакетов**:

```text
com.droidlogic.tvinput
com.fengmi.projector135MGN
com.fengmi.autofocustest
com.droidlogic
com.formovie.gsettings
com.android.camera2
com.formovie.launchboard
com.fengmi.platform
com.fengmi.projector045G
com.fengmi.projector055G
cn.formovie.fengos.usermanual
com.droidlogic.SubTitleService
com.droidlogic.ble
com.formovie.fmutils
com.fengmi.fmsettings
com.fengmi.projector.imaging
com.fengmi.testsuite
com.droidlogic.overlay
```

Наличие пакетов совпадает с несколькими рекомендациями внешнего профиля для другой сборки `.2102`. Это **подтверждение установки на нашей `.4185`**, не доказательство назначения компонентов, наличия внешних Activity или работоспособности интерфейсов после HOME-switch. **Этот новый результат не включает повторную команду `pm list packages -d`; предыдущие выводы об отключённых совпадениях остаются ограничены прежним фильтром.**

Из-за неопределённости добавлены точные обнаруженные пакеты `com.droidlogic*` и `com.android.camera2` в консервативный блокирующий список; весь префикс `com.droidlogic.` и корень `com.droidlogic` считаются защищёнными. Остальные Formovie/Fengmi уже имели защиту префиксов. Эта защита — дополнительная страховка, а не разрешение менять HOME.

### Внешний сопоставимый экземпляр

Для другого `MiProjM05/eva`, Android TV 9, build `PQ3B.190705.003.2102` публично описана защита `com.fengmi.projector.imaging` (focus/keystone), `com.fengmi.fmsettings`, `com.fengmi.platform` и других Formovie/HDMI компонентов. **У нас прошивка заканчивается на `.4185`, не `.2102`**; чужие списки отключений и команды не переносить и не запускать. Источник: https://github.com/Gathin23/cleanyourtv/blob/main/examples/formovie-mprojm05/debloat.txt

### Защита в FreeMyProjector

Добавлены точные обнаруженные кандидаты и штатный TV Launcher в `HomeMode.PROTECTED`. Предусмотрен общий запрет отключения любого `com.fengmi.*`, `com.formovie.*`, `cn.formovie.*`, включая ещё не обнаруженные. CI проверяет, что оба пути выключения используют этот guard. Это **дополнительная страховка**, а не доказательство, что будущая смена HOME безопасна: `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED = false` остаётся без изменения.

## Зачем дополнительная проверка
Оригинальный Free My TV при переключении не только назначает HOME, но и выполняет `pm disable-user`, `settings put secure screensaver_components`, делает фоновые проверки, пытается вернуть HOME через команду `cmd role`. Набор команд и запасной путь восстановления могут быть неподходящими для Android 9 Xiaomi. Пока `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED=false`; блокировку не менять.

Наличие `com.google.android.tvlauncher` как HOME **не означает**, что в нём реализованы фокус и коррекция трапеции. Эти функции могут использовать отдельные сервисы OEM и оборудование.

## Новые факты по Activity — 24.10.2026

Следующий read-only запрос `dumpsys package` показал в `Activity Resolver Table` штатные записи `.alias.FocusActivity`, `.alias.KeystoneActivity`, `.alias.AutoKeystoneActivity`, `.alias.GuideActivity`, `.access.ImagingFeatureActivity` пакета `com.fengmi.projector.imaging`; `.ui.activity.MainActivity` в `com.formovie.gsettings`; `TvSettingsActivity`, `HdmiExtendSetupActivity` и другие у `com.droidlogic.tvinput`. Списки и ограничения подробно приведены в [P-04A activity discovery](MIPROJM05_ACTIVITY_DISCOVERY.md). **Степень экспортируемости, права и возможность запуска из обычного приложения ещё не установлены; команды запуска на устройстве не выполнялись**. `TV_INPUT_HARDWARE: granted=true` относится к OEM-пакетам, а не к нашему лаунчеру.

## Что выполнить на Windows — ТОЛЬКО ЧТЕНИЕ
Требуется уже установленное и разрешённое ADB-соединение; если оно больше не установлено, см. `docs/DEVICE_DIAGNOSTICS_WINDOWS.md`. PowerShell из любого каталога:

```powershell
$adb = "D:\Git\platform-tools\adb.exe"
$pattern = '(?i)(xiaomi|miui|mitv|fengmi|focus|keystone|projector|calib|optical|launcher|tvrecommendations|tv\.settings)'

# 1. Повторно прочитать текущий HOME
& $adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME

# 2. Показать только пакеты-кандидаты: без путей, UID и установочных данных
& $adb shell pm list packages | Select-String -Pattern $pattern

# 3. Узнать, нет ли уже отключённых кандидатов. Ничего не включает!
& $adb shell pm list packages -d | Select-String -Pattern $pattern
```

**Не присылай** полный результат `pm list packages`, `dumpsys`, `adb devices`, IP или serial. Передай только найденные строки `package:...` после `Select-String` и отметь, в каком из двух списков они встретились. Если совпадений нет — так и напиши; отсутствие совпадений не означает отсутствие OEM-служб. Перенаправление в файл не требуется.

## Визуальное подтверждение меню (фотографии владельца 24.10.2026)

Получены четыре фотографии системного интерфейса **Настройки → Проектор → Фокусировка / Коррекция трапецеидальных искажений**, а также **Изображение**. Видны ручная коррекция, переключатель автоматической коррекции и пункт автоматической калибровки. Это подтверждает доступность соответствующих **экранов меню в текущем заводском HOME**, но не успешность аппаратной регулировки, не работоспособность после смены лаунчера и не имена точных Activity. Критерии P-04 остаются невыполненными, запрет `PROJECTOR_HOME_SWITCH_AUDITED=false` сохраняется.

## Ручная проверка штатных функций
1. Пока штатный HOME активен, открой **обычные** системные настройки фокусировки и коррекции трапеции через пульт.
2. Зафиксируй **названия пунктов меню**, есть ли автофокус, ручной фокус и вертикальная коррекция, доступны ли они вне главного экрана. Не меняй значения калибровки.
3. Убедись, что кнопка «Home» возвращает в привычный экран, а настройки всё ещё доступны. Опиши словами или пришли фото только самого интерфейса, без личных данных.
4. Не отключай системные приложения. Не запускай внешние команды фокусировки, если для этой прошивки они не проверены.

## Что ЗАПРЕЩЕНО до отдельного согласования
- `cmd package set-home-activity`, `cmd role`, `pm disable-user` / `pm enable`, `pm uninstall`;
- `settings put`, изменения заставки и Wi-Fi, `am start` непроверенных служебных Activity/Intent;
- root, bootloader, OTA/recovery/перепрошивка и копирование OEM APK в общедоступный репозиторий.

## Дополнительный источник по точной модели

Сохранена ссылка на [CleanYourTV](https://github.com/Gathin23/cleanyourtv/tree/main/examples/formovie-mprojm05) и [наш подробный анализ](CLEANYOURTV_MIPROJM05_RESEARCH.md). Вторая сборка MiProjM05/eva (`.2102`) подтверждает важность `com.droidlogic.tvinput`, сохранения настроек Formovie и осторожности с `FallbackHome`, пультом и состоянием после reboot. Для нашей `.4185` это **кандидаты на read-only проверку**, не подтверждённые зависимости и не список для выполнения. Концепция записи enabled/disabled/HOME *до изменения* полезна для будущего P-04 rollback; действия по HOME всё ещё запрещены.

## Что будет дальше
Сверяем кандидатов с текущим `HomeMode.PROTECTED` и логикой `targets`, выясняем реальное назначение OEM компонентов, проектируем Android 9 rollback. Первый допустимый тест нового приложения — запуск **как обычного приложения без смены HOME** в отдельном согласованном P-05. Новый подписанный релиз после PR #7 понадобится отдельно: `v0.1.0` был собран до переноса upstream ADB-исправления.

См. [P-04A — сохранение функций проектора](PROJECTOR_FUNCTIONS.md) и [спецификацию P-04](../openspec/changes/miprojm05-home-rollback-audit/specs/xiaomi-home-safety/spec.md).