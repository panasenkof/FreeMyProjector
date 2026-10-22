# Задачи P-02 — сборка Android в GitHub Actions

## 1. Спецификация и проверка решений
- [x] 1.1 Проанализирован фактический `build.sh`, manifest и путь подписи.
- [x] 1.2 Описаны требования и сценарии, разделение P-02 build / P-03 signing.
- [x] 1.3 OpenSpec validation пройден на PR #5 ([run 39810114759](https://github.com/panasenkof/FreeMyProjector/actions/runs/39810114759)).

## 2. Реализация без изменения Android-функциональности
- [x] 2.1 Добавить только в явном CI-режиме `FMP_BUILD_UNSIGNED=1` переход после `zipalign`, без `keytool` и `apksigner sign`.
- [x] 2.2 Реализовать выбор строго закреплённой платформы 34 и инструментов 34.0.0 в `build.sh` через переменные окружения, с понятной ошибкой.
- [x] 2.3 Создать `.github/workflows/android-build.yml`: JDK17, Android SDK 34, `workflow_dispatch`, push и PR триггеры.
- [x] 2.4 Добавить checks: APK существует, ZIP проходит `unzip -t`, `zipalign -c`, `aapt2 dump badging`, SDK 28/33, SHA256.
- [x] 2.5 Загружать `UNSIGNED-NOT-INSTALLABLE` artifact только по успешному результату; не публиковать в Releases.
- [x] 2.6 Документировать действия в GitHub, ограничения безопасности и связь с P-03.

## 3. Проверки перед слиянием
- [x] 3.1 OpenSpec validation зелёный ([run](https://github.com/panasenkof/FreeMyProjector/actions/runs/39810114759)).
- [x] 3.2 Android build CI зелёный ([run #39810114540](https://github.com/panasenkof/FreeMyProjector/actions/runs/39810114540), head `2faafab766b577b737041881c81128a75c93c315`).
- [x] 3.3 В логах подтверждена загрузка [артефакта #12440365784](https://github.com/panasenkof/FreeMyProjector/actions/runs/39810114540/artifacts/12440365784), 772952 байт ZIP, внутри APK + SHA256SUMS + BUILD-REPORT.
- [x] 3.4 В CI не создан `*.keystore`, не вызваны `apksigner sign`, `adb`, не используются secrets, не изменена идентичность приложения.
- [x] 3.5 Документировать, что ручное аппаратное тестирование/установка не выполнены.

## Отдельная последующая работа

P-03: собственный package ID, название, безопасный, постоянный ключ подписи, подписанные APK на следующих запусках, механизм обновления и публикация релизов.

**Критерии CI пройдены на реализации до итоговой правки документации.** Перед закрытием PR повторно проверить зелёные статусы на актуальном SHA. После слияния синхронизировать подтверждённые требования в `openspec/specs/android-build-ci/spec.md` и архивировать change. Аппаратная проверка остаётся в P-05.
