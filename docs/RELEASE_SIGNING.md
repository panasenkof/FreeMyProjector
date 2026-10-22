# P-03: личный ключ подписи и первый установочный APK FreeMyProjector

**Перед началом:** [PR P-03](https://github.com/panasenkof/FreeMyProjector/pulls) должен быть слит в `main`. Файлы из P-02 имели название `UNSIGNED-NOT-INSTALLABLE` и **не предназначены для установки**. Для приватного релиза необходим собственный ключ.

## 1. Почему нужен постоянный ключ

Android разрешает обновлять приложение с тем же package ID только при совместимой подписи и увеличенном `versionCode`. Новое приложение имеет идентификатор `com.panasenkof.freemyprojector`. Это **отдельное приложение**, оно не перезаписывает и не импортирует настройки установленного Free My TV (`io.freemytv`).

**Не теряй keystore и пароль.** При потере ключа обычное обновление уже установленного приложения не получится. Не загружай keystore в Git, чат, Issues, PR или обычные артефакты.

## 2. Создай личный ключ на компьютере Windows

Нужен JDK 17+ (`keytool.exe`). Если Java установлена, открой PowerShell и введи:

```powershell
keytool -genkeypair -v -keystore "$env:USERPROFILE\FreeMyProjector-release.p12" -storetype PKCS12 -alias freemyprojector -keyalg RSA -keysize 3072 -validity 10000 -dname "CN=FreeMyProjector"
```

При первом запуске команда **попросит самостоятельно ввести пароль**. Придумай длинный уникальный пароль и сохрани его в менеджере паролей. Никому, включая AI-помощника, не отправляй пароль, ключ или его Base64-строку. Для PKCS12 пароль ключа обычно совпадает с паролем хранилища. Не генерируй ключ повторно для следующих версий приложения.

Сделай **отдельную защищённую резервную копию** `FreeMyProjector-release.p12` до первого выпуска. Храни её вне GitHub и не только на текущем компьютере. Не удаляй файл после добавления секрета.

## 3. Подключи секреты GitHub Actions

Открой [настройки Secrets проекта](https://github.com/panasenkof/FreeMyProjector/settings/secrets/actions) → **New repository secret**. Создай **ровно четыре** секрета:

| Имя | Что вводить |
|---|---|
| `FMP_RELEASE_KEYSTORE_B64` | Base64 содержимого личного `.p12` файла |
| `FMP_RELEASE_STORE_PASSWORD` | Придуманный пароль хранилища |
| `FMP_RELEASE_KEY_ALIAS` | `freemyprojector` |
| `FMP_RELEASE_KEY_PASSWORD` | Пароль ключа (для данного PKCS12 обычно совпадает с паролем хранилища) |

В PowerShell можно **скопировать Base64 сразу в буфер обмена**, не выводя его на экран:

```powershell
$p = "$env:USERPROFILE\FreeMyProjector-release.p12"
[Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) | Set-Clipboard
```

Затем вставь содержимое буфера в GitHub секрет `FMP_RELEASE_KEYSTORE_B64` и **сразу очисти буфер**:

```powershell
Set-Clipboard -Value ""
```

Третьим лицам не сообщай содержимое этих четырёх секретов. GitHub может позволять также хранить секреты в Environment `release-signing`; рекомендуемая базовая схема выше использует **Repository secrets**. Если добавляешь Environment в настройках GitHub, можно настроить ограничение ветки `main` и required reviewers (если доступно на твоём тарифе/в приватном репозитории).

## 4. Запусти сборку установочного APK

После слияния P-03:

1. Открой [GitHub Actions](https://github.com/panasenkof/FreeMyProjector/actions).
2. Выбери **Publish signed FreeMyProjector APK (manual)**.
3. Нажми **Run workflow**, выбери ветку **main**.
4. Запуск проверит package ID, версию `0.1.0` и `versionCode=1000`, наличие всех секретов, подпишет APK твоим личным ключом и проверит подпись `apksigner verify`.
5. В случае успеха появится новый **prerelease `v0.1.0`** в [GitHub Releases](https://github.com/panasenkof/FreeMyProjector/releases) с файлами `FreeMyProjector-v0.1.0.apk`, `SHA256SUMS.txt`, `BUILD-REPORT.txt`.
6. **Только этот подписанный APK** рассчитан на установку; неподписанные CI-артефакты для этого не подходят.

Если секретов нет/они неверны, релиз должен завершиться **ошибкой без публикации**. Попроси проверить название недостающего секрета, но не присылай его значение.

Выпуск преднамеренно помечается prerelease: проектор MiProjM05 ещё не тестировался. Создание APK не устанавливает приложение на проектор.

## 5. Обновления

Каждый будущий APK требует **тот же ключ и тот же package ID**. Версия в `app/AndroidManifest.xml` изменяется отдельным PR:

| Версия | versionCode |
|---|---:|
| `0.1.0` | 1000 |
| `0.1.1` | 1001 |
| `0.2.0` | 2000 |
| `1.0.0` | 1000000 |

Формула: major × 1 000 000 + minor × 1 000 + patch, minor/patch от 0 до 999. Скрипты отклоняют противоречие versionName/versionCode и релиз с неувеличивающейся семантической версией. Не меняй package ID или ключ ради «новой версии» — тогда обычное обновление не получится.

Подлинность можно проверить локально:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\34.0.0\apksigner.bat" verify --verbose --print-certs "FreeMyProjector-v0.1.0.apk"
```

Это пример для типичного расположения Android SDK в Windows. Если SDK находится в другом каталоге, используй фактический путь к `build-tools\34.0.0\apksigner.bat`.

## 6. Пока нельзя менять домашний экран Xiaomi

В P-03 включён **программный запрет переключения HOME и ADB-фоновых задач**, пока мы не закончим аудит восстановления оригинального Launcher (P-04). Даже после установки приложения не пытайся обходить запрет и не отключай системные пакеты Xiaomi вручную.

P-05 — отдельная инструкция по контролируемой установке, кнопкам пульта, сну/перезапуску и безопасному удалению. **Мы ещё не проверили установку на настоящем устройстве.**

## Ограничения и источники

- В CI выпуск не должен использовать TMDB API-токены и не должен помещать личные данные в APK.
- В GitHub Releases публикуются только APK, checksum и отчёт; приватный keystore отсутствует.
- Android apksigner: https://developer.android.com/tools/apksigner
- GitHub release workflow: https://cli.github.com/manual/gh_release_create
