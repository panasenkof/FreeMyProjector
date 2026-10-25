# P-04H — безопасное обнаружение заводского экрана сопряжения

**Найден наиболее вероятный заводской экран:** `com.android.tv.settings/.accessories.AddAccessoryActivity` на реальном MiProjM05/eva Android9 build `.4185`. В AOSP Android TV эта Activity прямо предназначена для поиска и сопряжения Bluetooth-устройств и обычно экспортируется для действия `com.google.android.intent.action.CONNECT_INPUT`: [AOSP исходный класс](https://android.googlesource.com/platform/packages/apps/TvSettings/+/293380a/Settings/src/com/android/tv/settings/accessories/AddAccessoryActivity.java), [AOSP Manifest](https://android.googlesource.com/platform/packages/apps/TvSettings/+/29e0208/Settings/AndroidManifest.xml). **На прошивке владельца экспортируемость, permission и реальный запуск пока не испытаны**. Поэтому это обоснованный адресный кандидат, а не доказанная работоспособность.

**Принятый отчёт владельца 25.10.2026:** `status=candidates-found-not-validated`, `user=0`, firmware verified, обе выборки `android.settings.BLUETOOTH_SETTINGS` пусты, кандидаты: `AddAccessoryActivity`, `BluetoothDevicePickerActivity`, `BluetoothPairingDialog`, `BluetoothPairingRequest`, `BluetoothRequestPermissionActivity`, `FMBlePairingDialog`, `BluetoothSpeakerMode`, `DeviceNameSettingsActivity`. `device_writes=0`, HOME blocked. **Диалоги и BluetoothSpeakerMode не открывать напрямую**.

**Назначение компонента установлено по AOSP; его внешняя доступность на OEM `.4185` пока не подтверждена.** Скрипт собирает кандидатов без запуска Activity, изменений Bluetooth, HOME или файлов.

## Команда после обновления main

```powershell
cd D:\Git\FreeMyProjector\FreeMyProjector-main
git pull --ff-only origin main
$folder = "D:\Git\FreeMyProjector\MiProjM05-baseline-20261025-091132-80cc72ea6d"
.\tools\Find-ProjectorRemotePairing.ps1 -SnapshotDirectory $folder -AdbPath $adb
```

Сначала проверяет SHA256 baseline, требует MiProjM05/eva Android 9 build .4185, user 0 и одно authorised device. Затем вызывает только `devices`, `getprop`, `am get-current-user`, `cmd package resolve-activity/query-activities -a android.settings.BLUETOOTH_SETTINGS` и `dumpsys package` для `com.android.tv.settings`, `com.fengmi.fmsettings`, `com.formovie.gsettings`. Возвращает только отфильтрованные имена Activity, никогда serial/IP/MAC.

**Важно:** `oem_pairing_activity_candidates` — только кандидаты по имени, не подтверждение exported/permissions или успешного запуска. После получения результата нужен анализ конкретных Activity, только затем проверка открытия штатного экрана из обычного APK.

## Реализовано после этого отчёта

В ручной кнопке «Пульт и Bluetooth» теперь сначала используется **явный компонент** `AddAccessoryActivity`, но исключительно на `MiProjM05/eva` Android 9 с display build `.4185`, и только после runtime `PackageManager.getActivityInfo` с условиями `exported`, `enabled`, `permission` отсутствует, OEM/system package, точное имя Activity. Intent использует AOSP action `CONNECT_INPUT`, без дополнительных флагов автоматического pairing.

При ошибке открытия, недоступности или другой прошивке остаются проверка обычного Bluetooth Settings Intent (в отчёте не разрешился) и переход в общие заводские Settings. Вызов не происходит автоматически при запуске или загрузке. **Открытие страницы штатного сопряжения по явному нажатию** может инициировать обнаружение Bluetooth-устройств самим заводским экраном; оно не удаляет существующую пару по нашей команде.

До готового подписанного APK и отдельного пользовательского аппаратного теста мы **не можем** отметить `vendor_activity_launch_verified=true`.

## Что уже есть в APK

В `SettingsActivity` есть строка «Пульт и Bluetooth». Текущая реализация сначала проверяет адресный OEM `AddAccessoryActivity`, а при отказе — стандартный Bluetooth Intent и общие настройки; эта последняя ступень не обязательно открывает сопряжение.

Автоматического открытия pairing, перепривязки пульта или запуска через boot нет. USB-клавиатура исключена из планов резервного ввода по желанию владельца.

Источники: [P-04G](P04G_ADB_RECOVERY_REMOTE_PAIRING_DESIGN.md), [FAQ Xiaomi](https://www.mi.com/ru/support/faq/details/KA-04467/), [Android Settings Intent](https://developer.android.com/reference/android/provider/Settings#ACTION_BLUETOOTH_SETTINGS).
