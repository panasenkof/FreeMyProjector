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

### Внешний сопоставимый экземпляр

Для другого `MiProjM05/eva`, Android TV 9, build `PQ3B.190705.003.2102` публично описана защита `com.fengmi.projector.imaging` (focus/keystone), `com.fengmi.fmsettings`, `com.fengmi.platform` и других Formovie/HDMI компонентов. **У нас прошивка заканчивается на `.4185`, не `.2102`**; чужие списки отключений и команды не переносить и не запускать. Источник: https://github.com/Gathin23/cleanyourtv/blob/main/examples/formovie-mprojm05/debloat.txt

### Защита в FreeMyProjector

Добавлены точные обнаруженные кандидаты и штатный TV Launcher в `HomeMode.PROTECTED`. Предусмотрен общий запрет отключения любого `com.fengmi.*`, `com.formovie.*`, `cn.formovie.*`, включая ещё не обнаруженные. CI проверяет, что оба пути выключения используют этот guard. Это **дополнительная страховка**, а не доказательство, что будущая смена HOME безопасна: `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED = false` остаётся без изменения.

## Зачем дополнительная проверка
Оригинальный Free My TV при переключении не только назначает HOME, но и выполняет `pm disable-user`, `settings put secure screensaver_components`, делает фоновые проверки, пытается вернуть HOME через команду `cmd role`. Набор команд и запасной путь восстановления могут быть неподходящими для Android 9 Xiaomi. Пока `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED=false`; блокировку не менять.

Наличие `com.google.android.tvlauncher` как HOME **не означает**, что в нём реализованы фокус и коррекция трапеции. Эти функции могут использовать отдельные сервисы OEM и оборудование.

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

## Что будет дальше
Сверяем кандидатов с текущим `HomeMode.PROTECTED` и логикой `targets`, выясняем реальное назначение OEM компонентов, проектируем Android 9 rollback. Первый допустимый тест нового приложения — запуск **как обычного приложения без смены HOME** в отдельном согласованном P-05. Новый подписанный релиз после PR #7 понадобится отдельно: `v0.1.0` был собран до переноса upstream ADB-исправления.

См. [P-04A — сохранение функций проектора](PROJECTOR_FUNCTIONS.md) и [спецификацию P-04](../openspec/changes/miprojm05-home-rollback-audit/specs/xiaomi-home-safety/spec.md).