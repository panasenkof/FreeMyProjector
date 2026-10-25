# Ревизия связанных проектов — 25.10.2026

## Источники, проверенные непосредственно через GitHub API

- Основной исходный проект: https://github.com/simbasjungles/free-my-tv ; HEAD main: `57ea46051fc9dc3201da425f858ef2768f1cc1f2`. Последняя опубликованная версия: [v1.2.0](https://github.com/simbasjungles/free-my-tv/releases/tag/v1.2.0), 24.10.2026.
- Независимый проект с **профилем именно MiProjM05/eva**: https://github.com/Gathin23/cleanyourtv ; HEAD main: `575d73f0f30c329aa7ebaea2bc863943fd9bf7f9`.
- Наш порт: FreeMyProjector, установленная модель MiProjM05/eva, Android 9 API 28, build `PQ3B.190705.003.4185`; чужой профиль относится к другой сборке `.2102`, не считать её команды проверенными у нас.
- Наш импорт из Free My TV пока исторически закреплён на `62e883b3179c8cafb7a2b09960eabfe7eea6ef1c`, а Android 8–10 ADB retry из upstream `6209fca8e` перенесён точечно. Это **не полноценное слияние с v1.2.0**.

## Free My TV — релевантные новые изменения

| Коммит | Содержание | Решение для нашего порта |
| --- | --- | --- |
| [`b93b5c3`](https://github.com/simbasjungles/free-my-tv/commit/b93b5c34cb2e318515b50231ac1eb0456e59468c) | MIUI TV input app в `<queries>` и `HomeMode.PROTECTED` | **P1 проверить точечно** после code-review manifest/защитного списка. Наши важные `com.droidlogic.tvinput` / Fengmi не подменять MIUI-пакетом; защищать только фактически установленные компоненты |
| [`a7d56b1`](https://github.com/simbasjungles/free-my-tv/commit/a7d56b1f0dd2a7aa30592c652cf8fdd861d0047a), [`f59c355`](https://github.com/simbasjungles/free-my-tv/commit/f59c3558a5798c1d9cde598080ee5c3193a5aa81) | Исправления заставки для Android 12 | **Не переносить в Android 9 без необходимости**: изменяется подсистема заставки, которая пока для нас заблокирована |
| [`a4273a2`](https://github.com/simbasjungles/free-my-tv/commit/a4273a20b1e60353dd6bb8166024b9fa6de87801) | HY300 Amlogic shortcut через JmLauncher | **Не переносить**: другая модель, не доказано для Fengmi MiProjM05 |
| [`f42dd33`](https://github.com/simbasjungles/free-my-tv/commit/f42dd33a2845a6d8f079046d9fbf0a8cf347ed92) | Релиз 1.2.0, версии и Homebrew Channel | **P1 отдельно исследовать** полезные UI/совместимые функции, не заменяя исходный APK, package ID, локальную подпись и HOME gate |
| [`57ea460`](https://github.com/simbasjungles/free-my-tv/commit/57ea46051fc9dc3201da425f858ef2768f1cc1f2) | Готовый APK и сайт как способ установки | Не использовать готовый чужой APK для эксперимента: сохраняем наш package name, подпись и защиту HOME |

**Проверка сравнения:** GitHub comparison от уже перенесённого `6209fca8e` к текущему upstream main показывает 89 upstream commits; это **не** 89 готовых безопасных cherry-pick для FreeMyProjector и не расстояние от исходного импортированного коммита.

## CleanYourTV — обновления, важные для recovery

| Коммит | Наблюдение | Применение |
| --- | --- | --- |
| [`7872bf0`](https://github.com/Gathin23/cleanyourtv/commit/7872bf0d2c6489378a8881b280adf9333c1f4a29) / [`6a5e76c`](https://github.com/Gathin23/cleanyourtv/commit/6a5e76c5a78c750861424bf13af4d1906f26c800) | Recovery/privacy читает package state для **user 0** | **P0 проверить модель Android multi-user в нашем офлайн rollback**. Текущий baseline через `pm list packages` не является доказательством корректности per-user восстановления. До получения однозначных user-scoped данных НЕ делать реального восстановления пакетов |
| [`92aa4aa`](https://github.com/Gathin23/cleanyourtv/commit/92aa4aa3025d3be0324b27d4a058aa3c83e6c74c) | Recovery больше не считает Android HOME chooser полноценным HOME для возврата | **P0 требование**: не считать chooser, `FallbackHome`, тестовый и setup HOME пригодными для восстановления. У нас уже есть отказ от FallbackHome и строго закреплён Google TV Launcher в P-04B/P-04D; расширить offline tests на chooser |
| [`c334909`](https://github.com/Gathin23/cleanyourtv/commit/c3349095990adb987be6213a5edf25ebcd876634) | Опубликован профиль Formovie/Fengmi MiProjM05 | Профиль модели уже изучен в `docs/CLEANYOURTV_MIPROJM05_RESEARCH.md`; новые изменения таблиц 24.10 не являются новой прошивкой или hardware-доказательством |

## Что делаем по приоритетам

1. **P0 — сначала завершить и проверить PR #21** (offline/mock восстановление HOME и пакетных состояний). Этот PR существует отдельно; не дублировать код и не включать реальный ADB write path.
2. **P0 — дополнительная спецификация и тесты**: определение user-0 enabled state, распознавание HOME chooser, невозможность восстановить ранее отсутствующие пакеты, запрет на изменение OEM, идемпотентность и запись достоверного журнала изменений **до** будущих системных действий.
3. **P0–P1 — интеграция OEM**: на основе локального, проверенного по SHA256 `MiProjM05-imaging.apk` проектировать отдельные точки входа для Focus, Keystone и заводских Settings. Пока только исследование manifest/permissions; не выполнять `am start`, не менять оптику и не добавлять кнопки до подтверждения Android 9-разрешений.
4. **P1 — выборочный перенос полезных upstream изменений** с тестами: TV input visibility/protection, навигация с пульта, internationalization и UX только там, где применимо; Android 12-specific screensaver и HY300 не переносить автоматически.
5. **P-05 — обычная APK установка** только после отдельного согласования и сохранения штатного HOME; системный HOME-пилот требует отдельной приёмки recovery и альтернативного управления.

## Инварианты безопасности

- `ModeJob.PROJECTOR_HOME_SWITCH_AUDITED=false`; без изменений `pm disable-user`, HOME, `settings put`, ADB write, перепрошивки.
- Сохранять защиту `com.fengmi.*`, `com.formovie.*`, `cn.formovie.*`, `com.droidlogic.*`, Google TV Launcher, TV settings, Camera2 и служб ввода/изображения.
- Публиковать только код и обезличенные отчёты. `baseline.private.json`, заводские APK и локальные данные должны оставаться в `D:\Git\FreeMyProjector`, но **вне** Git-репозитория.

**Статус проверки:** ревизия доступных последних upstream коммитов и релиза выполнена 25.10.2026. Реальный проектор этой ревизией не менялся. Все переносы — через отдельные PR после анализа и тестов.
