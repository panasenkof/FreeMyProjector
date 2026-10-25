# P-04H — безопасное обнаружение заводского экрана сопряжения

**Найден наиболее вероятный заводской экран:** `com.android.tv.settings/.accessories.AddAccessoryActivity` на реальном MiProjM05/eva Android9 build `.4185`. В AOSP Android TV эта Activity прямо предназначена для поиска и сопряжения Bluetooth-устройств и обычно экспортируется для действия `com.google.android.intent.action.CONNECT_INPUT`: [AOSP исходный класс](https://android.googlesource.com/platform/packages/apps/TvSettings/+/293380a/Settings/src/com/android/tv/settings/accessories/AddAccessoryActivity.java), [AOSP Manifest](https://android.googlesource.com/platform/packages/apps/TvSettings/+/29e0208/Settings/AndroidManifest.xml). **На прошивке владельца экспортируемость, permission и реальный запуск пока не испытаны**. Поэтому это обоснованный адресный кандидат, а не доказанная работоспособность.

**Принятый отчёт владельца 25.10.2026:** `status=candidates-found-not-validated`, `user=0`, firmware verified, обе выборки `android.settings.BLUETOOTH_SETTINGS` пусты, кандидаты: `AddAccessoryActivity`, `BluetoothDevicePickerActivity`, `BluetoothPairingDialog`, `BluetoothPairingRequest`, `BluetoothRequestPermissionActivity`, `FMBlePairingDialog`, `BluetoothSpeakerMode`, `DeviceNameSettingsActivity`. `device_writes=0`, HOME blocked. **Диалоги и BluetoothSpeakerMode не открывать напрямую**.

**Точная OEM Activity на MiProjM05/.4185 пока не известна**. Скрипт читает package resolver и три заводских пакета без запуска Activity, изменений Bluetooth, HOME или файлов.

## Команда после обновления main

```powershell
cd D:\Git\FreeMyProjector\FreeMyProjector-main
git pull --ff-only origin main
$folder = "D:\Git\FreeMyProjector\MiProjM05-baseline-20261025-091132-80cc72ea6d"
.\tools\Find-ProjectorRemotePairing.ps1 -SnapshotDirectory $folder -AdbPath $adb
```

Сначала проверяет SHA256 baseline, требует MiProjM05/eva Android 9 build .4185, user 0 и одно authorised device. Затем вызывает только `devices`, `getprop`, `am get-current-user`, `cmd package resolve-activity/query-activities -a android.settings.BLUETOOTH_SETTINGS` и `dumpsys package` для `com.android.tv.settings`, `com.fengmi.fmsettings`, `com.formovie.gsettings`. Возвращает только отфильтрованные имена Activity, никогда serial/IP/MAC.

**Важно:** `oem_pairing_activity_candidates` — только кандидаты по имени, не подтверждение exported/permissions или успешного запуска. После получения результата нужен анализ конкретных Activity, только затем проверка открытия штатного экрана из обычного APK.

## Что уже есть в APK

В `SettingsActivity` добавлена отдельная ручная строка «Пульт и Bluetooth». По нажатию `ProjectorRemoteSettings` пытается открыть `Settings.ACTION_BLUETOOTH_SETTINGS` только через разрешённый, exported OEM Activity без дополнительного permission. В случае отсутствия — открывает `Settings.ACTION_SETTINGS`. Этот fallback **не обязательно экран сопряжения**, но сохраняет доступ к заводским настройкам.

Автоматического открытия pairing, перепривязки пульта или запуска через boot нет. USB-клавиатура исключена из планов резервного ввода по желанию владельца.

Источники: [P-04G](P04G_ADB_RECOVERY_REMOTE_PAIRING_DESIGN.md), [FAQ Xiaomi](https://www.mi.com/ru/support/faq/details/KA-04467/), [Android Settings Intent](https://developer.android.com/reference/android/provider/Settings#ACTION_BLUETOOTH_SETTINGS).
