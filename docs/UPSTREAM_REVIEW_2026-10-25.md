# Ревизия связанных проектов 25.10.2026 — Free My TV и CleanYourTV

## Проверенные состояния GitHub

| Источник | Коммит main на момент проверки | Сравнение с прошлой ревизией | Решение |
| --- | --- | --- | --- |
| [Free My TV](https://github.com/simbasjungles/free-my-tv) — истинный upstream | [`57ea46051fc9`](https://github.com/simbasjungles/free-my-tv/commit/57ea46051fc9dc3201da425f858ef2768f1cc1f2) | **54 новых коммита** после `aa34335d25fa` (24.10), **235** после нашего изначального импортированного `62e883b3179c` | Только адресный перенос после ревью |
| [CleanYourTV](https://github.com/Gathin23/cleanyourtv) — независимый проект | [`575d73f0f30c`](https://github.com/Gathin23/cleanyourtv/commit/575d73f0f30c329aa7ebaea2bc863943fd9bf7f9) | **408 коммитов** после рассмотренного `86a69372f988` | Читать идеи, не подтягивать исходники целиком |
| [Профиль MiProjM05](https://github.com/Gathin23/cleanyourtv/tree/main/examples/formovie-mprojm05) | `examples/formovie-mprojm05/debloat.txt` и `tv.json` | По истории файлов последние изменения 22.10 — добавление профиля; обновлялись индексы/таблицы проекта 24.10 | Наше исследование профиля остаётся актуальным, но оно **для .2102**, не для нашей .4185 |

## Что нового в Free My TV 1.2.0

Версия [v1.2.0](https://github.com/simbasjungles/free-my-tv/releases/tag/v1.2.0) опубликована **24.10.2026**. Из коммитов:
- [Исправление HDMI / MIUI TV](https://github.com/simbasjungles/free-my-tv/commit/b93b5c34c): проверка фирменного плеера источников, запросы package visibility. **Не переносить напрямую** на Amlogic/Fengmi, где HDMI обслуживает `com.droidlogic.tvinput`; нужен OEM-специфический путь.
- [Российские сервисы](https://github.com/simbasjungles/free-my-tv/commit/59489bf26): Кинопоиск, Okko, Premier, Amediateka, Wink. **P1 — полезно для RU-интерфейса**, но не влияет на безопасность HOME и не ускоряет YouTube.
- Исправление [screensaver в Android 12](https://github.com/simbasjungles/free-my-tv/commit/a7d56b1f0) — **не применимо** к Android 9/API28, не переносим.
- Таймер сна, расширения полки и переводы — **P1/P2**; не переносить сейчас, чтобы не создавать конфликт с проекторными guards.
- Исправление ADB Android 8–10 `6209fca8e` уже было адресно перенесено нами 24.10; в новых 54 коммитах дополнительных изменений `Adb.java` не обнаружено.

**Вывод:** полное слияние upstream с нашим Java приложением сейчас нецелесообразно: у нас собственный package id, исходно закрытая смена HOME, защищённые компоненты Fengmi/Formovie/Droidlogic и иные ограничения. Версию продукта автоматически не повышать до 1.2.0.

## Новые уроки CleanYourTV

Важное изменение [`7872bf0d2c`](https://github.com/Gathin23/cleanyourtv/commit/7872bf0d2c) от 25.10:
- `recovery.py` теперь сначала читает `pm list packages --user 0` и отключённые пакеты тоже для `--user 0`. На Android 14 запрос без user может объединить нескольких пользователей и ошибочно записать чужие состояния.
- На нашем **Android 9** такой эффект не подтверждён. **P0/P-04E:** только read-only определить поддержку `--user 0` на MiProjM05 и проверить семантику. Не переинтерпретировать ранее созданный (SHA-проверенный) `baseline.private.json` и не менять автоматом все наборы пакетов.
- **Перед реальным восстановлением** строго проверить область пользователя, для которой будут выполняться команды; любые сомнения — STOP.

Из [`92aa4aa302`](https://github.com/Gathin23/cleanyourtv/commit/92aa4aa302):
- HOME chooser `android/com.android.internal.app.ResolverActivity` нельзя запоминать как реальный launcher или восстанавливать через него; наш скрипт уже требует точный оригинальный `com.google.android.tvlauncher/.MainActivity`. В P-04D любой FallbackHome/ResolverActivity — STOP.
- Отказ от ошибочной реставрации лучше догадки. Записи изменённого HOME и enabled/disabled обязаны иметь источник.

Из [`860142f512`](https://github.com/Gathin23/cleanyourtv/commit/860142f512):
- Сервис обработки HOME-клавиши выключается, когда экран погашен. На нашем MiProjM05 **не вводить фоновый перехват кнопок вообще** до отдельного теста: автор другого экземпляра уже сообщил о регрессии удержания Volume Up при helper.

### Что переносим в код сейчас, а что позже

| Приоритет | Решение | Примечание |
| --- | --- | --- |
| P0 | Офлайн симулятор отката из SHA-снимка + явного mock-журнала изменений | Отдельный PR P-04D; **никаких ADB writes** |
| P0 | Пассивный OEM preflight только для алиасов Focus и Keystone | Отдельный PR P-04A; **не вызывать Activity автоматически** |
| P0 | Проверка user 0 в `pm list packages` на Android 9 | Исследование/тест, не менять исходный сохранённый baseline |
| P1 | Штатный доступ к HDMI через `com.droidlogic.tvinput`, настоящий preflight и ручной тест | Нет подтверждённой экспортируемости HDMI Activity |
| P1 | Российские сервисы в app shelf (Кинопоиск, Okko, Premier и т.д.) | После безопасного пилота обычного APK |
| P1/P2 | Таймер, новая полка, язык/темы и улучшения UI | После P-05; выборочный перенос, не upstream merge |

Сохраняем `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED=false` и все OEM-пакеты включёнными. Актуальная read-only точка владельца 25.10: baseline SHA `match`, оригинальный HOME, 114/114 пакетов, 0 отличий.
