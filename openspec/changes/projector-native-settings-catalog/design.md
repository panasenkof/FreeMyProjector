# P-06 design

- Не расширять 8 пунктов главного экрана ещё на 20+ строк: один пункт «Функции проектора» → 6 категорий → 3–6 опций в каждой. Уменьшить высоту главной строки до 68 и промежуток до 4 виртуальных пикселей; сохранить работающий DPAD/OK/Back, Tab/TalkBack focus. На узких экранах длинные названия обрезаются ellipsize.
- Источник данных UI и индексной маршрутизации: ProjectorSettingsNavigator с двуязычными ключами для существующего Ui.tr и переводами RU/DE/ES. Ни один пункт не относится к 3D.
- Мотор и трапеция: использовать существующий **неизменённый** ProjectorFactoryScreens.inspect (он проверяет OEM target), запуск только из user-tap; авто-коррекция и калибровка показывают **экран**, не активируют процесс.
- HDMI: разрешать только известный OEM TvSettingsActivity на точной сборке после system/exported/permission. Остальные OEM встроенные опции: корень com.formovie.gsettings только если доверенный system component, иначе общие Android Settings.
- Settings.ACTION_*: запускать только в system/updated-system Activity, явно закрепляя разрешённый компонент, чтобы не позволить внешнему приложению подменять обработчик; OEM fallback.
- Bluetooth: прежний ProjectorRemoteSettings; связь не сбрасывать. USB Storage: настройки хранилища, не файловый браузер. Никаких signed APK/ADB writes в CI.
- Технические вопросы только после ручного QA: где в OEM меню лежит Bluetooth speaker/HDMI zoom/camera brightness и существуют ли отдельные экспортируемые Activity. Не утверждать стопроцентные deep-links по одному названию опции.
