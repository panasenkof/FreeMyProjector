# Design P-03

## Идентичность
- APK package: `com.fader.freemyprojector`; Android display name: `FreeMyProjector`.
- Java namespace исходника остаётся `io.freemytv`: это минимизирует большой ненужный рефакторинг. В AndroidManifest **все class android:name абсолютные**, например `io.freemytv.HomeActivity` и `io.freemytv.App`.
- `HomeMode.PKG` меняется на новый ID, а построение ComponentName использует отдельный `COMPONENT_CLASS_PREFIX="io.freemytv."`; не смешивать package и Java-class.
- Никаких команд смены HOME, подстраиваем только имена и намеренно сохраняем rollback-этап P-04.
- AndroidManifest versionCode: `1`, versionName: `0.1.0`, дальнейшие увеличения контролируются вручную на PR перед новым релизом.

## Ключи
- Удалить генерацию `freemytv.keystore` и `pass:freemytv` из `build.sh`.
- `FMP_BUILD_UNSIGNED=1` должен работать без подписывающих переменных.
- В signed-режиме обязательны `FMP_SIGNING_KEYSTORE`, `FMP_SIGNING_KEY_ALIAS`, `FMP_SIGNING_STORE_PASSWORD`, `FMP_SIGNING_KEY_PASSWORD`. Пароли считываются Android `apksigner` через `env:<name>` (не командная строка с открытым значением).
- `apksigner sign` вызывается после zipalign, затем `apksigner verify --min-sdk-version 28`.
- GitHub workflow с `workflow_dispatch`, без `pull_request`, без `push`/tag auto-trigger и без секретов в обычных PR. Только `main` и только при наличии секретов.
- Секреты: `FMP_RELEASE_KEYSTORE_B64`, `FMP_RELEASE_STORE_PASSWORD`, `FMP_RELEASE_KEY_ALIAS`, `FMP_RELEASE_KEY_PASSWORD`. Сертификат/ключ пользователь генерирует на собственном компьютере и хранит офлайн.
- Decode `FMP_RELEASE_KEYSTORE_B64` в `$RUNNER_TEMP`, не в рабочую папку; cleanup независимо от результата. `GITHUB_TOKEN` с write только для manual-release job; release tag `v<versionName>` создаётся после успешных проверок с закреплённым SHA. Workflow публикует **prerelease** до ручных испытаний.
- Runtime runtime secrets не вводим в APK. TMDB key пуст в CI; optional personal API keys только через безопасный отдельный план, не в публичном release.

## Проверки
- Static: имена компонентов в манифесте и `HomeMode`, запрет опасных старых паролей, hash/signing paths, `.gitignore`.
- Dynamic CI: `build.sh` unsigned с `aapt2 dump badging`, наличие классов, манифест и `zipalign`; проверка без keystore.
- Release CI: сверка версии, блока секретов, `apksigner verify --print-certs`, sha256, отсутствие дублирования тега.
- Реальный Android 9 MiProjM05: **не проверяется** в этом изменении. P-05 — установка без HOME switch.

## Критерии принятия
1. CI успешен и нигде не передаёт signing secret в обычные PR.
2. Выпуск возможен только через manual GitHub Actions и только после пользовательского создания/подключения ключа.
3. Ни Releases, ни installable APK не объявлять готовыми, пока нет подтверждённого signed build.
4. P-04 остаётся обязательным перед любым запуском переключения HOME.
