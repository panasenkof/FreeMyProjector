# FreeMyProjector — каталог исследований и меню MiProjM05

**Актуально: 25.10.2026.** Это **единая точка входа**, а не вторая независимая версия плана: актуальные статусы задач живут в [PLAN.md](../PLAN.md). Модель, прошивка и подтверждения: Xiaomi MiProjM05/eva, Android TV 9, API 28, build `PQ3B.190705.003.4185`.

## Уровни достоверности

| Метка | Значение |
| --- | --- |
| **DEVICE-UI** | Пункт виден на фотографиях/экране **конкретного** MiProjM05 |
| **DEVICE-OWNER** | Владелец сообщил, что функция есть/отсутствует на аппарате, но путь/действие может быть ещё не подтверждено отдельным фото/тестом |
| **DEVICE-ADB** | OEM пакет, Activity, HOME или состояние подтверждены чтением **конкретного** MiProjM05; работа функции не гарантирована |
| **CODE** | Реализовано в исходниках FreeMyProjector и проверено CI; работа на физическом проекторе отдельно не доказана |
| **DOCS** | Описано в руководствах/FAQ/обзорах по семейству Mi Smart Compact Projector; **не** подтверждено на конкретной прошивке |
| **TODO** | Путь меню, разрешение на внешний запуск или фактическое поведение ещё не проверены |

**Подтверждение владельца 25.10.2026:** все исследованные заводские функции, **кроме 3D**, присутствуют на его проекторе. Это уровень **DEVICE-OWNER** (сообщение владельца), но **не** подтверждение конкретной вложенности каждой страницы или её внешней Activity. Новые маршруты в приложении — [P-06](P06_NATIVE_PROJECTOR_SETTINGS.md). 

**Не смешивать:** запись в ADB resolver != пункт меню, и возможность из инструкции != реальная настройка на прошивке. Исходные фотографии и OEM APK **не публиковались в Git**; в документах сохранены текстовые подтверждения и ссылки. Личные snapshot `baseline.private.json` и OEM `MiProjM05-imaging.apk` остаются вне Git, локально у владельца. В репозитории нет полного дампа прошивки и заводских калибровок.

## 1. Подтверждённое дерево штатных меню (неполное)

Следующие элементы действительно различимы на снимках меню проектора, ранее предоставленных владельцем; названия отражают видимый текст, а не предположения по Activity.

```text
Заводское меню / Настройки
├── Проектор                       [DEVICE-UI]
│   ├── Фокусировка                [DEVICE-UI]
│   └── Коррекция трапецеидальных
│       искажений                  [DEVICE-UI]
│       ├── Коррекция трапецеидальных искажений  [DEVICE-UI]
│       ├── Автоматическая коррекция
│       │   трапецеидальных искажений (переключатель) [DEVICE-UI]
│       └── Автоматическая калибровка
│           трапецеидальных искажений [DEVICE-UI]
└── Изображение                    [DEVICE-UI, точный родитель в меню TODO]
    ├── Режим изображения          [DEVICE-UI]
    └── Настройка/пункт яркости камеры [DEVICE-UI; название/смысл уточнить]
```

**Это не полный каталог текущих пунктов!** Пока нет подтверждённого дерева разделов «Звук», «Источники/HDMI», «Bluetooth/Пульт», «Сеть», «Об устройстве», «Система/Обновления», «Режим проекции» и других. Не создавать выдуманные вложенности и не считать Activity `com.formovie.gsettings/.ui.activity.MainActivity` доказанным отдельным видимым пунктом.

Точный исходный источник: [PROJECTOR_FUNCTIONS.md, раздел фотографий](PROJECTOR_FUNCTIONS.md); [ручной чек-лист P-04C](P04C_REMOTE_PICTURE_MANUAL_CHECKLIST.md). Системные компоненты подтверждаются отдельно в [MIPROJM05_ACTIVITY_DISCOVERY.md](MIPROJM05_ACTIVITY_DISCOVERY.md).

## 2. Подтверждённые OEM точки входа, но не испытанные из нашего APK

| Подсистема | Найденное имя / доказательство | Статус |
| --- | --- | --- |
| Focus | `com.fengmi.projector.imaging/.alias.FocusActivity` | DEVICE-ADB: alias/manifest, внешний запуск TODO |
| Keystone | `com.fengmi.projector.imaging/.alias.KeystoneActivity` | DEVICE-ADB: alias/manifest, внешний запуск TODO |
| AutoKeystone | `com.fengmi.projector.imaging/.alias.AutoKeystoneActivity` | DEVICE-ADB; не путать с калибровкой |
| OEM imaging | `com.fengmi.projector.imaging/.access.ImagingFeatureActivity` | DEVICE-ADB; видимое поведение TODO |
| OEM settings | `com.formovie.gsettings/.ui.activity.MainActivity` | DEVICE-ADB; точный состав меню TODO |
| HDMI | `com.droidlogic.tvinput` и его TvSettings/HdmiExtendSetup Activity | DEVICE-ADB; назначение/внешний запуск TODO |
| Добавить пульт/аксессуар | `com.android.tv.settings/.accessories.AddAccessoryActivity` | DEVICE-ADB: найдена на .4185; по AOSP это pairing entry, но exported/permission и внешний запуск на .4185 TODO |
| Служебные диалоги пульта | `BluetoothPairingDialog`, `FMBlePairingDialog`, `BluetoothDevicePickerActivity` | DEVICE-ADB; **не запускать напрямую** |
| Bluetooth speaker mode | `com.android.tv.settings/.formovie.BluetoothSpeakerMode` | DEVICE-ADB; реальное UI поведение TODO |

Детали: [OEM оптика/HDMI](MIPROJM05_ACTIVITY_DISCOVERY.md), [пульт и результат ADB](P04H_REMOTE_PAIRING_DISCOVERY.md), [план сохранения всех подсистем](MIPROJM05_BACKUP_REMOTE_PICTURE_ROLLBACK.md).

## 3. Текущее меню **FreeMyProjector** в коде (не заводское)

Исходники: `SettingsActivity.java`, `ProjectorSettingsNavigator.java`, `ProjectorFactoryScreens.java`, `ProjectorRemoteSettings.java`. **Восемь главных пунктов**, шесть групп в проекторном подменю; открытие на реальном проекторе пока не проверено. [Полная карта и безопасные маршруты P-06](P06_NATIVE_PROJECTOR_SETTINGS.md).

```text
FreeMyProjector → Настройки [CODE; не физический тест]
├── Главный экран (смена HOME запрещена safety lock)
├── Заставка
├── Настройки главного экрана
├── Полка приложений
├── Кнопки пульта (переназначение кнопок приложений)
├── Пульт и Bluetooth (штатная AddAccessoryActivity с fallback)
├── Функции проектора
│   ├── Оптика и проекция → фокус / трапеция / авто / калибровка / ориентация
│   ├── Изображение → режим / яркость камеры / заводское изображение
│   ├── Источники и HDMI → вход / USB-хранилище / Cast / масштаб
│   ├── Звук → выход / Bluetooth-динамик / наушники
│   ├── Подключения → Wi-Fi / пульт и Bluetooth / Cast / голос
│   └── Система → сон / сведения и обновления / приложения /
│                  язык / специальные возможности / все настройки
└── Настройки ТВ → исходный общий системный экран
```

**Не путать каталог ярлыков с гарантированными deep links.** Пока известны точные OEM Focus/Keystone aliases, HDMI TvSettings и pairing candidate; маршруты, не подтверждённые на аппаратуре, открывают проверенный OEM settings root либо обычные Android Settings. **Нет 3D, авто-калибровка не запускается сама, pairing не сбрасывается.** Для подробного QA см. [P-06](P06_NATIVE_PROJECTOR_SETTINGS.md).

## 4. Что изучено по заводским возможностям и источникам

Единая таблица функций с приоритетами находится в [MIPROJM05_STOCK_FEATURE_MATRIX.md](MIPROJM05_STOCK_FEATURE_MATRIX.md). **3D исключено по отчёту владельца; прочие перечисленные функции доступны по его словам.** Указаны и отделены от DEVICE-UI: авто/ручной фокус, вертикальная трапеция, режимы изображения и ориентации, HDMI/USB, 3,5-мм аудио, Bluetooth-динамик/наушники, Wi-Fi 2,4/5 ГГц, Google Cast, голосовое управление, 3D по модели, сон/питание, OTA, температурная защита и установленные приложения. **Доступность каждого переключателя на .4185 не доказана.**

Сохранены как *ссылки и краткие выводы*, а **не полные копии сторонних материалов**:
- [Официальная спецификация Xiaomi](https://www.mi.com/ru/mi-smart-compact-projector/specs/)
- [Официальные особенности Xiaomi](https://www.mi.com/global/product/mi-smart-compact-projector/)
- [FAQ Xiaomi (EN)](https://www.mi.com/uk/support/faq/details/KA-06604/)
- [FAQ Xiaomi (RU)](https://www.mi.com/ru/support/faq/details/KA-04467/)
- [Руководство Mi Smart Compact Projector](https://manualzz.com/doc/64047793/mi-smart-compact-projector-user-manual)
- [Обзор TechRadar](https://www.techradar.com/reviews/xiaomi-mi-smart-compact-projector)
- [Обзор Laurent Willen](https://www.laurentwillen.com/en/test-reviews/projectors-tests-reviews/xiaomi-mi-smart-compact-projector-test-review-mi-youth/)

Не переносить руководство от Xiaomi Mi Smart Projector 2/Pro на MiProjM05 без сверки.

## 5. Исследования смежных проектов и безопасность

| Документ | Что в нём |
| --- | --- |
| [PROJECTOR_COMPATIBILITY.md](PROJECTOR_COMPATIBILITY.md) | Фото модели/сборки и ADB-подтверждение |
| [UPSTREAM_REVIEW_2026-10-25.md](UPSTREAM_REVIEW_2026-10-25.md) | Обновления Free My TV v1.2.0 и CleanYourTV MiProjM05 |
| [CLEANYOURTV_MIPROJM05_RESEARCH.md](CLEANYOURTV_MIPROJM05_RESEARCH.md) | Стандартный профиль для похожей, но **другой сборки** `.2102` |
| [P04B_READONLY_COMPARISON.md](P04B_READONLY_COMPARISON.md) / [P04D_OFFLINE_ROLLBACK_SIMULATION.md](P04D_OFFLINE_ROLLBACK_SIMULATION.md) | SHA снимка, сравнение текущего состояния и PC offline тест восстановления |
| [P04E_USER0_READONLY_AUDIT.md](P04E_USER0_READONLY_AUDIT.md) | Подтверждение 114 пакетов для Android user 0 |
| [P04F_ANDROID9_RECOVERY_GATES.md](P04F_ANDROID9_RECOVERY_GATES.md) | Условия допуска к смене HOME |
| [P04G_ADB_RECOVERY_REMOTE_PAIRING_DESIGN.md](P04G_ADB_RECOVERY_REMOTE_PAIRING_DESIGN.md) | ADB-откат и безопасное сопряжение |
| [P04I_ONE_TIME_WATCHDOG.md](P04I_ONE_TIME_WATCHDOG.md) | Проект одноразового 30-минутного таймера, **не реализован** |
| [P04F_USB_KEYBOARD_FAILURE.md](P04F_USB_KEYBOARD_FAILURE.md) | Исторический результат теста USB, но **USB-клавиатура исключена владельцем** из резервного управления |

## 6. Что ещё нужно для **полной** карты меню

Следующий read-only этап — каталог вида «путь меню → точное название → текущее значение → OEM Activity/Action → источник доказательства → доступно из обычного APK → сохранено после изменения HOME». Для начала нужны **реальные наблюдения**, а не догадки по руководствам. При проверке штатного проектора без любых изменений фиксировать:

| Раздел | Чего именно не хватает |
| --- | --- |
| Проектор | Полный список страниц: фокус, трапеция, автоматическая калибровка, режим проекции, ориентация |
| Изображение | Все режимы/параметры, точный текст «яркости камеры» и выбранные исходные значения |
| Пульт/Bluetooth | Полный путь к паре и аксессуарам, название экрана, поведение при подключённом пульте (без отвязки) |
| Звук | Output, Bluetooth speaker mode, наушники, динамики, предустановки |
| Источники | HDMI input, разрешение, zoom/overscan, USB media и Cast |
| Система/Сеть | Wi-Fi, Bluetooth, Google apps, вход/аккаунты, обновления/OTA, энергосбережение, язык, доступность |
| Дополнительно | 3D и автофункции только если реально существуют в .4185 |

**На данном этапе не просить владельца менять настройки, запускать калибровку, сбрасывать сопряжение или заменять HOME.** Проверка наличия пункта не равнозначна испытанию функции.

### Правило актуализации

1. Новое устройство/фото/ADB наблюдение → обновить соответствующий специализированный документ **и** его статус здесь.
2. Реально добавленное меню FreeMyProjector → пересверить с `SettingsActivity.java`.
3. Новая функция из FAQ/обзора → сначала **DOCS**, пока не проверена на .4185.
4. Порядок/сроки/решения остаются только в [PLAN.md](../PLAN.md); этот каталог не дублирует статус задач.
