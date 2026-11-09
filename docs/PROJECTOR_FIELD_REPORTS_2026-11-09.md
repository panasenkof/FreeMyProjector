# Полевые отчёты о сторонних Launcher на проекторах — 09.11.2026

Это дополнение к [ревизии upstream](UPSTREAM_REVIEW_2026-11-09.md), основанное на
**сообщениях пользователей и измерениях на чужом оборудовании**, а не
результатах нашего `MiProjM05/eva` с `PQ3B.190705.003.4185`.

## Уровни достоверности

- **FIELD** — конкретный владелец / автор отчёта описал аппарат, прошивку и наблюдавшийся результат.
  Не переносить без проверки на нашу `.4185`.
- **ANECDOTE** — отзывы в Reddit без независимых логов, принимать как подсказку для теста.
- **GUIDE** — статья/официальная инструкция, **не** равнозначна проведённому испытанию.
- **TODO ON .4185** — нет прямого аппаратного подтверждения на нашем проекторе.

## Наиболее релевантные случаи

| Аппарат / проект | Доказательство | Практический вывод |
|---|---|---|
| **MiProjM05/eva**, Android 9, `.2102` и `.1912`, CleanYourTV | **FIELD**: запуск `com.fengmi.projector.imaging/.alias.FocusActivity` с физической кнопки сработал на `.1912`. Долгое удержание Volume Up перестало плавно менять громкость после включения HomeKeyService; выключение helper возвращает повтор. KEYCODE_ALL_APPS = 284, а не гарантированно Settings. [Аппаратные заметки](https://github.com/Gathin23/cleanyourtv/blob/main/examples/formovie-mprojm05/README.md) | Сохранять `com.fengmi.projector.imaging` и OEM-службы. Не перехватывать кнопки глобально. Наличие alias не доказывает работоспособность из APK на `.4185`. Auto-keystone и manual keystone из этого отчёта **не проверялись**. |
| **Wanbo T6 Max**, Android 9 / API 28, CleanYourTV | **FIELD**: `cmd package set-home-activity` печатал `Success`, но HOME оставался заводским. После отключения OEM launcher + RecoveryActivity Android возвращал новую компоненту в resolver, однако имитация HOME не выходила из HDMI/Settings. Оба вернули; обход через оконный Accessibility observer с `key_filter=false` работал в одной сессии, но физический пульт не проверялся. ADB слушал **3333**, не 5555. [Отчёт](https://github.com/Gathin23/cleanyourtv/blob/main/docs/devices/wanbo-t6-max.md) | `Success` / наличие APK / `resolve-activity` **не считать доказательством** смены HOME. Проверять фактический выход из Settings и HDMI, cold boot, пульт. Обход через Accessibility на нашем устройстве не разрешён. ADB-порт и доступ после reboot — отдельно. |
| **Xiaomi Laser Cinema 2 4K / nemo**, Android 9, CleanYourTV | **FIELD**: `PackageManager` OEM исключает **несистемные** APK из HOME-кандидатов на PatchWall; `set-home-activity` отвечает `cannot be home on user 0`. Установленный APK работает как обычное приложение; Android HOME — нет. Исследовали `services.jar` точной firmware `2.1.3.4134`; stock launcher оставили. [Issue #2415](https://github.com/Gathin23/cleanyourtv/issues/2415) | Проверить HOME-фильтрацию в **точной** `.4185` пассивно до любого switch. Нельзя лечить отключением OEM launcher: может остаться только FallbackHome. Никаких root/прошивки и `setprop` для обхода. Это **другая** модель/прошивка. |
| **XGIMI Horizon Pro 4K** / **Halo+**, Android 11, CleanYourTV | **ANECDOTE**: владельцы Reddit сообщают об успешной установке, двух reboot, сохранении HDMI и оптики у Halo+ при сохранённых OEM сервисах. Другая ветка сообщает об обнаружении проблем с обнаружением проектора приложением даже при USB debugging; на Elfin потребовалась повторная синхронизация пульта. [Обсуждение](https://www.reddit.com/r/xgimi/comments/1xf16mx/has_anyone_used_the_clean_your_tv_claude_code_on/) | Аппаратные функции могут сохраниться при бережном наборе системных пакетов, но remote pairing, ADB connection и HDMI необходимо испытывать **реально**, не только эмуляцией кнопок. |
| **Formovie XMing Page One** Android 11 / Google TV, CleanYourTV | **FIELD**: шесть дней ежедневного использования, OEM и Wi-Fi держат заводские launcher/setupwizard; HOME у альтернативного достигнут Accessibility redirect. Тот же недостаток — исчезает непрерывная регулировка Volume Up. [Каталог испытаний](https://github.com/Gathin23/cleanyourtv/blob/main/examples/README.md) | Длительность испытаний важна; не копировать HOME workaround и не жертвовать работой пульта ради "завершённой" смены лаунчера. |
| **Xiaomi MiProjA1 / rainman**, Android 6.0.1, CleanYourTV | **FIELD**: фирменная прошивка поглощает Home и Source до Accessibility, OEM screensaver не управляется обычным Settings, `TvInputManager` не показывает HDMI passthrough; TCP ADB закрывается после перезагрузки. [Каталог испытаний](https://github.com/Gathin23/cleanyourtv/blob/main/examples/README.md) | Не считать HDMI TV input или Android screensaver универсальными API; измерить альтернативный независимый rollback, не полагаясь на постоянный localhost:5555. Совсем другое поколение проектора. |
| **HY300 / Allwinner** с Free My TV | **FIELD/maintainer notes**: у части прошивок HDMI отображается некорректно (несколько портов на одном физическом), а настройки Keystone в чужом OEM экране вызывают `SecurityException`; некоторыми версиями HOME управляет прошивочный property, а не обычный default HOME. [Заметки проекта](https://github.com/simbasjungles/free-my-tv/blob/main/CLAUDE.md) | OEM Activity надо проверять как точный компонент с правами, не переносить настройки/HDMI маршруты других моделей. |
| **Wanbo T2 Ultra**, Android 11, Free My TV | **GUIDE/вопрос**, не завершённая полевая проверка: автор подтвердил успех на TCL, спросил о Wanbo; разработчик предложил read-only инвентаризацию OEM-пакетов до переноса. [Issue #157](https://github.com/simbasjungles/free-my-tv/issues/157) | Не включать в статистику успешных **проекторов** лишь по заявлению о совместимости Android 8+. |

## Что статьи действительно подтверждают

- [Обзор Free My TV от Kevin Singh (26.10)](https://www.kevinsingh.com/p/free-my-tv-an-ad-free-home-screen) — полезный **гайд**, но в основном пересказывает инструкции проекта, не содержит собственного испытания Xiaomi `.4185`. Сохранение factory HOME и 60% экономии памяти — **обещания/измерения других TV**, не наши метрики.
- [Общая статья The Verge](https://www.theverge.com/tech/1016116/vibe-coding-tv-os) — контекст практики ADB/кастомных оболочек и общих рисков. Не подтверждает аппаратную совместимость конкретного проектора.
- **Не найдено** независимого опубликованного испытания FreeMyProjector или Free My TV с **нашей точной прошивкой `.4185`**. Не подменять отсутствующий результат похожей моделью.

## P0/P-04/P-05 — дополнительные критерии допуска, вытекающие из наблюдений

1. **Физический preview**: APK можно установить, открыть/закрыть, удалить, при этом заводской HOME и все OEM остаются активны; Back/ Home / Apps / Volume (короткое и удержание) / микрофон / питание / сопряжение пульта проверены руками, не только `adb input keyevent`.
2. **Аудит HOME-кандидатов**: перед потенциальным отдельным HOME-пилотом пассивно определить, видит ли именно `.4185` наш APK как `HOME` для user 0. Preview-only APK, у которого HOME выключен манифестом, **не пригоден для такого теста**; не выдавать его отсутствие в результатах за OEM-фильтр. Любые изменения манифеста только как отдельный безопасный эксперимент с согласованием.
3. **Не верить одному Success**: после будущего разрешённого switch требуются проверки фактической HOME Activity, перехода HOME из стороннего приложения/Settings/HDMI, cold boot, wake и обратного возврата. Если HOME chooser, RecoveryActivity, FallbackHome или чужой кандидат — STOP.
4. **Независимый rollback**: наличие локального ADB клиента в APK недостаточно; после reboot/standby TCP ADB может закрыться или слушать другой порт, а Accessibility может быть отключён. Заранее согласованный способ вернуться к заводскому HOME без нашего APK обязателен.
5. **Оптика и HDMI**: проверять фактическую картинку, ручной и автофокус, ручную/автокоррекцию трапеции, настройку изображения, HDMI-сигнал/звук/CEC, Cast, Bluetooth, USB, охлаждение, сон; успешное `startActivity` не значит работающий мотор или изображение.
6. **Стабильность**: тест не заканчивать одним включением и одним успешным CI. Разделять install/open, warm reboot, полноценное снятие питания, пробуждение, длительную сессию и независимый откат. Отмечать факт тестирования каждой функции.
7. **Не заимствовать debloat**: не отключать `com.fengmi.*`, `com.formovie.*`, `com.droidlogic.*` и заводской HOME; не делать автоматическое `pm disable-user`, `setprop`, перехват HOME/volume или перенос APK из другого устройства. Это соответствует нашему ADR-001.

Ни один пункт не разрешает менять систему устройства до отдельной P0 приёмки.
