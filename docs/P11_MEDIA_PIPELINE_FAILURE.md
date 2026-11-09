# P-11 — ускоренное видео без звука во всех приложениях: диагностика на MiProjM05

**Дата:** 09.11.2026. **Приоритет:** P0 для диагностики, не P0-разрешение на изменение системных кодеков.
**Устройство:** владелец наблюдает дефект на **штатной** оболочке MiProjM05/eva, Android 9,
`PQ3B.190705.003.4185`, **до установки FreeMyProjector**.

## Признаки, подтверждённые владельцем

- Непредсказуемо начинается в YouTube: ускоренное воспроизведение при отсутствии звука.
- Нет возможности вернуть нормальное воспроизведение средствами плеера.
- После выхода из YouTube дефект сохраняется в **других приложениях с видео**.
- Полная перезагрузка временно восстанавливает нормальную работу.
- **Ещё не измерено:** фактическая кратность скорости, выход звука (динамик/BT/HDMI),
  источник контента и `avc1/vp09/av01`, момент после сна, версия YouTube, ошибки ADB.

### Гипотезы, а не диагноз

1. Сломался общий audio clock / AudioTrack / аппаратная A/V синхронизация в **tunneled** playback;
   Android 9 может брать опорные временные метки для видео из audio track.
2. Аудио HAL / AudioFlinger / AudioPolicy держат неверное состояние (в том числе
   цифровой выход, passthrough, BT routing, PCM/компрессированный звук).
3. MediaCodec/OMX или менеджер декодеров сохранил неисправное состояние после YouTube,
   из-за чего затронуты другие процессы.
4. Реже: конфигурация потока VP9/Opus vs AVC/AAC выявляет vendor баг; недостаток
   памяти и повреждение таймингов тоже не исключены.

**Нет оснований:** утверждать, что причина установлена, что нужен новый набор
видеокодеков, что VPN/ускорение YouTube исправит это, что новый launcher устранит
сбой драйверов или что нужный OEM-firmware есть в доступе.

### Обоснование/аналогии

- [AOSP, мультимедийный tunneled режим](https://source.android.com/docs/devices/tv/multimedia-tunneling):
  связь Android video timestamp c audio clock и Audio HAL.
- [AOSP, обновляемые кодеки](https://source.android.com/docs/core/media/media-modules):
  Android 9 OMX vendor implementation не заменяется пользовательским APK.
- [AOSP, debug AudioFlinger](https://source.android.com/docs/core/audio/debugging):
  `dumpsys media.audio_flinger`; продвинутый tee sink потребовал бы root/userdebug/изменения
  системы — **не применять**.
- [Похожий пользовательский дефект Onn 4K Plus](https://www.reddit.com/r/AndroidTV/comments/1lnvwih/onn_4k_plus_youtube_app_is_fast_forwarding_with/):
  YouTube fast/no audio затем Prime/Max. Другой аппарат, без доказанной причины.
- [Патчи NVIDIA Shield Dolby Audio](https://www.flatpanelshd.com/news.php?id=1667366743):
  исправляли отсутствие звука до reboot и ускоренное аудио. Другой аппарат.
- [Xiaomi FAQ: нет звука](https://www.mi.com/global/support/faq/details/KA-125226/):
  проверка аудиовыхода, нескольких источников, restart, firmware.
- [Android TV Guide — MiProjM05](https://www.androidtv-guide.com/streaming-gaming/xiaomi-mi-smart-compact-projector/):
  аппаратные VP9/H.264/H.265, Amlogic T962X — **справочные**, не
  измерены на нашей прошивке.

## A. Сначала ручное наблюдение (пульт, без ADB)

1. В исправном состоянии запишите час и факт: какой аудиовыход, звук системного
   меню есть или нет, видео YouTube обычной скорости, играет ли локальное AVC/AAC
   видео в другом приложении; проверьте одну и ту же сцену.
2. При следующем сбое **не перезагружайте сразу**. Зафиксируйте время, название
   приложения и какое видео / качество вызвало проблему (без ссылки, если она личная).
3. Проверьте отдельно: системные звуки меню слышны? звук вообще (например,
   в музыкальном приложении) есть? одно и то же локальное видео (не потоковое)
   тоже идёт ускоренно? другие приложения запускаются нормально?
4. В YouTube при наличии «Статистика для сисадминов / Stats for nerds» запишите
   только `Codecs` (`avc1`, `vp09`, `av01` и аудио, если показано) и
   разрешение/частоту. **Наличие/состав меню зависит от версии YouTube**.
5. Отметьте, был ли перед ошибкой сон/пробуждение, BT pairing, HDMI source/ARC,
   смена языка/аудиовыхода, пауза, перемотка или переключение приложения.
6. Если нужно вернуть работоспособность, перезагрузите **штатной опцией** после
   сохранения показаний. Не сбрасывайте приложение и проектор к заводским настройкам.

**Диагностическое разделение:** системные звуки есть, но все видео идут быстро
без звука -> повышает приоритет A/V sync; нет никаких звуков и выбран не тот
аудиовыход -> приоритет AudioPolicy/маршрутизация. Это гипотезы для проверки,
не автоматические выводы.

## B. Пассивный ADB-снимок исправного и неисправного состояния

**Условие:** уже авторизованный ADB с доверенного ПК, ровно одно устройство.
Не включать Wi-Fi debug и не открывать порты ради этого протокола. Сначала
должен пройти существующий **P-04E preflight** со сверкой локального backup
и штaтного HOME. Без `user0-matches-baseline` — STOP.

Команды ниже для **Windows PowerShell на ПК**; они пишут файлы **только на ПК**.
До воспроизведения дефекта сделать `good`, при дефекте до reboot — `bad`.
Укажите реальный путь к `adb.exe` или уже доступную команду `adb`:

```powershell
$adb = 'adb'
$folder = 'D:\Git\FreeMyProjector\local-media-diagnostics'
$phase = 'good' # позже заменить на 'bad'
New-Item -ItemType Directory -Force -Path $folder | Out-Null

# P-04E: сначала проверить эталон; $snapshot — путь к прежнему локальному снимку
.\tools\Test-ProjectorUser0Scope.ps1 -SnapshotDirectory $snapshot -AdbPath $adb

# Только dumpsys — это запрос состояния, ничего не перезапускаем
& $adb shell dumpsys audio               | Out-File -Encoding UTF8 "$folder\$phase-audio.txt"
& $adb shell dumpsys media.audio_policy  | Out-File -Encoding UTF8 "$folder\$phase-audio-policy.txt"
& $adb shell dumpsys media.audio_flinger | Out-File -Encoding UTF8 "$folder\$phase-audio-flinger.txt"
& $adb shell dumpsys media.codec         | Out-File -Encoding UTF8 "$folder\$phase-codec.txt"
& $adb shell dumpsys media.resource_manager | Out-File -Encoding UTF8 "$folder\$phase-resources.txt"

# Дополнительно только при необходимости, локально и с контролем приватности:
& $adb logcat -d -t 300 -v brief -s AudioTrack AudioFlinger AudioPolicyManager MediaCodec ACodec NuPlayer AudioService |
    Out-File -Encoding UTF8 "$folder\$phase-media-events-PRIVATE.txt"
```

Проверяйте код завершения/содержимое каждого снимка. `media.codec` /
`media.resource_manager` могут отсутствовать на конкретной прошивке:
сообщение `Can't find service` ≠ доказательство неисправности. Выводы
`dumpsys` зависят от производителя и версии Android. Не запускать
несколько команд одновременно при нестабильной системе.

**Приватность:** в raw dumpsys/logcat могут быть имена пакетов, UID,
имена аудиоустройств, URI или фрагменты событий. Файлы хранятся
**исключительно локально** в папке, игнорируемой Git (не выполнять `git add`
для папки). Перед передачей ИИ-агенту очистить IP, serial, MAC, SSID,
учётные данные, частные URL и посторонние логи. Не публиковать сырые логи
в открытом PR/Issue и не собирать поимённую историю использования приложений.

### Что сравнивать в good и bad

- `audio_policy`: ожидаемый физический выход vs фактически выбранный
  (speaker / A2DP / HDMI ARC); passthrough/direct flags, активные output profiles.
- `audio_flinger`: активные output threads, `standby`, состояние
  `AudioTrack`, frames written/rendered и errors/underrun;
  желательно два последовательных read-only снимка при продолжающемся видео.
- `media.codec`, `resource_manager`: `OMX` декодеры,
  `reclaim`, `RESOURCE_BUSY`, неосвобождённый decoder;
  service missing следует отдельно отмечать.
- `logcat`: `AudioTrack`, `AudioFlinger`, `MediaCodec`, `ACodec`,
  `OMX`, vendor errors, timestamps вокруг начала сбоя.
- Исправная/неисправная запись на **одном** output device и одном локальном
  AVC/AAC-ролике полезнее сравнения двух разных видеосервисов.

## C. Обратимые ручные проверки после сохранения снимка

Без root и `adb shell setprop`:
- Попробовать **остановить** YouTube средствами Android Settings → Apps →
  YouTube → Force stop, затем отдельно другое приложение. Сохранить результат.
- Если доступны родные настройки звука, **зафиксировать исходные значения**
  и по одной проверять PCM/stereo vs auto/surround/passthrough, либо
  временно отсоединить BT-колонку/HDMI-аудиоустройство. Не менять их
  без добровольного разрешения владельца; затем вернуть исходные значения.
- Сравнить YouTube 720p/1080p и, когда доступен такой выбор, VP9 vs AVC;
  наличие выбора кодека не гарантируется.
- Проверить, обычный ли reboot действительно очищает ошибку или требуется
  полное отключение питания, не делая power-cycle во время ADB-снимка.
- Если ошибка сохраняется после reboot или появляется регулярно, отдельно
  исследовать только **официальные прошивки для точной модели и сборки**,
  не прошивать ничего самостоятельно.

## Запрещено делать в FreeMyProjector ради «починки кодеков»

- Добавлять в launcher APK чужие `.so`, OMX/HAL, писать `media_codecs.xml`,
  `audio_policy.conf`/XML или подменять `/vendor`, `/system`.
- `adb root`, `remount`, `pm disable-user`, `killall audioserver`,
  `stop/start media`, `setprop`, отключение штатных сервисов.
- Автоматический «перезапуск аудио» через Accessibility, root или hidden API:
  может нарушить Cast, HDCP, Bluetooth, фокус и стабильность системы.
- Приписывать новому launcher исправление багов Audio HAL/OMX, пока не
  продемонстрирован воспроизводимый тест на реальном устройстве.

## Критерии закрытия P-11

1. Есть **хотя бы один** зафиксированный `good/bad` кейс с аудиовыходом,
   видеокодеком/типом потока и проверкой другого приложения.
2. Результат сравнения A/V clocks, AudioPolicy/Flinger и MediaCodec
   классифицирован: подтверждено / подозревается / исключено / недоступно.
3. Подобран и аппаратно проверен **безопасный обход** (если найден) без
   системных файлов, root, отключения OEM или смены HOME.
4. Если обхода нет, проблема задокументирована как OEM/firmware issue
   с данными для обращения Xiaomi; `P-11` не выдаётся за реализованный фикс.
5. Цикл сравнения выполнен на **штатном HOME** до FreeMyProjector и
   повторяется при preview APK, чтобы обнаружить регрессии, не подменяя
   корреляцию причинностью.
