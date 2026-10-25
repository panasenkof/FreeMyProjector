package io.freemytv;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Build;
import android.provider.Settings;

/**
 * P-06: navigational shortcuts to the firmware's EXISTING settings.
 * Never controls motors, brightness, HDMI state, BT bonds, sleep, or firmware.
 * All activity launches require an explicit OK from the user.
 * Unsupported / OEM-restricted screens fall back to normal TV settings.
 */
final class ProjectorSettingsNavigator {
    private ProjectorSettingsNavigator() {}

    static final int OPTICS = 0, PICTURE = 1, SOURCES = 2,
            SOUND = 3, CONNECTIONS = 4, SYSTEM = 5;
    static final int SECTION_COUNT = 6;

    // Index-aligned PT/EN titles. Russian/German/Spanish via Ui.tr translations.
    private static final String[] SECTION_PT = {
        "Óptica e projeção", "Imagem", "Fontes e HDMI",
        "Som", "Ligações", "Sistema"
    };
    private static final String[] SECTION_EN = {
        "Optics & projection", "Picture", "Sources & HDMI",
        "Sound", "Connections", "System"
    };

    private static final String[][] ITEMS_PT = {
        {"Foco", "Correção trapezoidal", "Correção trapezoidal automática", "Calibração trapezoidal", "Orientação da projeção"},
        {"Modo de imagem", "Brilho da câmera", "Ajustes de imagem"},
        {"Entrada HDMI", "Armazenamento USB", "Google Cast", "Zoom HDMI"},
        {"Saída de áudio", "Modo alto-falante Bluetooth", "Fones de ouvido"},
        {"Rede Wi-Fi", "Controle e Bluetooth", "Google Cast", "Assistente de voz"},
        {"Suspensão e energia", "Sobre e atualizações", "Aplicativos instalados",
         "Idioma do sistema", "Acessibilidade", "Todas as configurações"}
    };
    private static final String[][] ITEMS_EN = {
        {"Focus", "Keystone correction", "Automatic keystone", "Keystone calibration", "Projection orientation"},
        {"Picture mode", "Camera brightness", "Picture settings"},
        {"HDMI input", "USB storage", "Google Cast", "HDMI zoom"},
        {"Audio output", "Bluetooth speaker mode", "Headphones"},
        {"Wi-Fi network", "Remote & Bluetooth", "Google Cast", "Voice assistant"},
        {"Sleep & power", "About & updates", "Installed apps",
         "System language", "Accessibility", "All factory settings"}
    };

    static String sectionTitle(int section) {
        if (section < 0 || section >= SECTION_COUNT) return "";
        return Ui.tr(SECTION_PT[section], SECTION_EN[section]);
    }

    static int itemCount(int section) {
        return section < 0 || section >= SECTION_COUNT ? 0 : ITEMS_EN[section].length;
    }

    static String itemTitle(int section, int item) {
        if (section < 0 || section >= SECTION_COUNT || item < 0 || item >= itemCount(section)) {
            return "";
        }
        return Ui.tr(ITEMS_PT[section][item], ITEMS_EN[section][item]);
    }

    static String itemRoute(int section, int item) {
        // Direct routes are identified here; everything else safely returns to OEM settings.
        if (section == OPTICS && item < 4) return Ui.tr("Tela de fábrica", "Factory screen");
        if (section == SOURCES && (item == 0 || item == 3)) return Ui.tr("Tela de fábrica", "Factory screen");
        if (section == CONNECTIONS && item == 1) return Ui.tr("Tela de fábrica", "Factory screen");
        if ((section == SOURCES && item > 0)
                || (section == SOUND && item != 1)
                || (section == CONNECTIONS && item != 3)
                || (section == SYSTEM && item >= 1 && item <= 4)) {
            return Ui.tr("Ajustes Android", "Android settings");
        }
        return Ui.tr("Menu da TV", "TV settings");
    }

    private static boolean auditedFirmware() {
        return Build.VERSION.SDK_INT == 28
                && "MiProjM05".equals(Build.MODEL)
                && "eva".equals(Build.DEVICE)
                && "PQ3B.190705.003.4185".equals(Build.DISPLAY);
    }

    private static boolean allowedSystem(ActivityInfo info) {
        if (info == null || !info.exported || !info.enabled
                || (info.permission != null && !info.permission.isEmpty())
                || info.applicationInfo == null || !info.applicationInfo.enabled) return false;
        int flags = ApplicationInfo.FLAG_SYSTEM | ApplicationInfo.FLAG_UPDATED_SYSTEM_APP;
        return (info.applicationInfo.flags & flags) != 0;
    }

    private static boolean launchOEM(Activity activity, String pkg, String cls) {
        if (!auditedFirmware()) return false;
        try {
            PackageManager pm = activity.getPackageManager();
            ComponentName component = new ComponentName(pkg, cls);
            ActivityInfo info = pm.getActivityInfo(component, 0);
            if (!allowedSystem(info) || !pkg.equals(info.packageName) || !cls.equals(info.name)) {
                return false;
            }
            Intent intent = new Intent();
            intent.setComponent(component);
            activity.startActivity(intent);
            return true;
        } catch (RuntimeException | PackageManager.NameNotFoundException ignored) {
            return false;
        }
    }

    private static void openGeneral(Activity activity) {
        try {
            activity.startActivity(new Intent(Settings.ACTION_SETTINGS));
        } catch (RuntimeException ignored) {
            // No OEM Settings activity: remain in our existing settings screen.
        }
    }

    private static void openOEMSettings(Activity activity) {
        if (!launchOEM(activity, "com.formovie.gsettings",
                "com.formovie.gsettings.ui.activity.MainActivity")) {
            openGeneral(activity);
        }
    }

    private static void openSystemSettings(Activity activity, String action) {
        try {
            PackageManager pm = activity.getPackageManager();
            Intent intent = new Intent(action);
            ResolveInfo candidate = pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY);
            ActivityInfo info = candidate == null ? null : candidate.activityInfo;
            if (allowedSystem(info)) {
                // Never allow an unrelated app to intercept Settings actions.
                intent.setClassName(info.packageName, info.name);
                activity.startActivity(intent);
                return;
            }
        } catch (RuntimeException ignored) {
            // OEM ROM may not expose ordinary Android Settings actions.
        }
        openOEMSettings(activity);
    }

    private static void openOptics(Activity activity, ProjectorFactoryScreens.Screen screen) {
        ProjectorFactoryScreens.Preflight check = ProjectorFactoryScreens.inspect(activity, screen);
        if (check.available && check.preparedIntent != null) {
            try {
                activity.startActivity(check.preparedIntent);
                return;
            } catch (RuntimeException ignored) {
                // OEM app rejected outside launch; use its factory settings.
            }
        }
        openOEMSettings(activity);
    }

    /** Called ONLY from explicit remote OK on a displayed projector-settings row. */
    static void openFromUserTap(Activity activity, int section, int item) {
        if (activity == null || item < 0 || item >= itemCount(section)) return;
        switch (section) {
            case OPTICS:
                if (item == 0) openOptics(activity, ProjectorFactoryScreens.Screen.FOCUS);
                else if (item >= 1 && item <= 3) openOptics(activity, ProjectorFactoryScreens.Screen.KEYSTONE);
                else openOEMSettings(activity); // orientation: exact screen not mapped yet
                return;
            case PICTURE:
                openOEMSettings(activity); // use native picture/camera settings, no unverified intents
                return;
            case SOURCES:
                if (item == 0 || item == 3) {
                    if (!launchOEM(activity, "com.droidlogic.tvinput",
                            "com.droidlogic.tvinput.settings.TvSettingsActivity")) {
                        openOEMSettings(activity);
                    }
                } else if (item == 1) {
                    openSystemSettings(activity, Settings.ACTION_INTERNAL_STORAGE_SETTINGS);
                } else {
                    openSystemSettings(activity, Settings.ACTION_CAST_SETTINGS);
                }
                return;
            case SOUND:
                if (item == 1) openOEMSettings(activity); // BT speaker: OEM menu, NOT pairing
                else openSystemSettings(activity, Settings.ACTION_SOUND_SETTINGS);
                return;
            case CONNECTIONS:
                if (item == 0) openSystemSettings(activity, Settings.ACTION_WIFI_SETTINGS);
                else if (item == 1) ProjectorRemoteSettings.openFromUserTap(activity);
                else if (item == 2) openSystemSettings(activity, Settings.ACTION_CAST_SETTINGS);
                else openOEMSettings(activity); // voice: no verified direct screen
                return;
            case SYSTEM:
                switch (item) {
                    case 0: openOEMSettings(activity); return; // power, sleep
                    case 1: openSystemSettings(activity, Settings.ACTION_DEVICE_INFO_SETTINGS); return;
                    case 2: openSystemSettings(activity, Settings.ACTION_APPLICATION_SETTINGS); return;
                    case 3: openSystemSettings(activity, Settings.ACTION_LOCALE_SETTINGS); return;
                    case 4: openSystemSettings(activity, Settings.ACTION_ACCESSIBILITY_SETTINGS); return;
                    default: openGeneral(activity); return;
                }
            default:
                return;
        }
    }
}
