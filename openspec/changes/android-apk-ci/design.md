# Дизайн P-02 — GitHub Actions для неподписанного Android APK

## Проверенные исходные условия

- `build.sh`: цепочка `aapt2 compile/link → javac → d8 → zipalign → apksigner`, без Gradle.
- Android manifest: `package="io.freemytv"`, `minSdkVersion=28` и `targetSdkVersion=33` задаются из `build.sh`.
- В конце `build.sh` исходник генерирует `freemytv.keystore` с паролем `freemytv`. Это **не** релизный способ подписи для FreeMyProjector; P-03 устранит этот риск и определит постоянную идентичность.
- Подтверждённое устройство: Xiaomi Android 9, системная модель `MiProjM05`. APK ещё не установлен.
- `config.example.properties` не содержит TMDB API-ключа; приватный `config.properties` исключён из Git.

## Выбор реализации

1. Доработать `build.sh`: явный opt-in `FMP_BUILD_UNSIGNED=1`, который выходит после `zipalign` без генерации/использования ключа и без создания `FreeMyTV.apk`. Без флага прежний локальный путь остаётся прежним.
2. Зафиксировать в workflow `FMP_BUILD_TOOLS_VERSION=34.0.0` и `FMP_ANDROID_PLATFORM=34`; `build.sh` использует версии из этих переменных только если они заданы. Проверять, что все инструменты реально найдены.
3. GitHub Actions workflow `.github/workflows/android-build.yml`: `pull_request` по Android/build файлам; `push` в `main`; `workflow_dispatch`.
4. Runner: `ubuntu-latest`, Temurin JDK 17 и `android-actions/setup-android`; скачать `platforms;android-34` и `build-tools;34.0.0`.
5. Безопасные проверки результата `out/aligned.apk`: `test -s`, `unzip -t`, `zipalign -c -p 4`, `aapt2 dump badging` (SDK API 28/33, package `io.freemytv` до P-03), SHA-256.
6. Скопировать неподписанный APK + метаданные в `out/ci-artifacts`; загрузить через `actions/upload-artifact` с небольшим retention и явной пометкой `UNSIGNED-NOT-INSTALLABLE`.
7. Логи GitHub Actions сохраняются автоматически; при ошибках артефакт не должен сообщать «успех». Избегать раскрытия конфигурации, полных environment variables и signing keys.

## Непременные ограничения

- **Никакой GitHub Release** и никакого `apk install` в этом PR.
- **Никакого постоянного ключа** или известного пароля для CI. Закрытая подпись и имя пакета — P-03.
- В CI использовать неинтерактивные команды, без root на проекторе, без сетевых подключений к пользовательским устройствам.
- Не выдавать валидный ZIP за успешно работающее приложение. Установка и пульт проверяются в P-05.
- Изменения относятся только к инфраструктуре и существующей сборке, не должны менять исходники `app/`.

## Риски

- GitHub-hosted Android SDK может меняться: версии платформы и build-tools закрепляются явно, а в логах пишутся только версии компонентов.
- Подключаемые Actions могут обновляться: использовать проверенные стабильные major versions и read-only permissions; пинning по SHA — возможное дальнейшее улучшение безопасности.
- В `aapt2` текст dump может отличаться: тестируем на CI и не ослабляем проверку SDK ради зелёного статуса.
- CI не проверяет работу `MiProjM05`.

## Источники

- Android [апк-командная сборка](https://developer.android.com/build/building-cmdline) и [apksigner](https://developer.android.com/tools/apksigner)
- [Android SDK setup action](https://github.com/android-actions/setup-android)
- [GitHub upload-artifact](https://github.com/actions/upload-artifact)
