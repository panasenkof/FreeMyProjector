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
 * P-04H: user-initiated entry to factory remote pairing/settings.
 *
 * Discovery on actual MiProjM05/.4185 found com.android.tv.settings/.accessories.AddAccessoryActivity.
 * AOSP describes this as the "Add accessory" screen. External launch on .4185
 * remains unverified; runtime PackageManager preflight fails closed.
 *
 * No boot-time trigger, Bluetooth state changes, bond manipulation, or
 * automatic re-pairing. A tap can open the OEM Bluetooth scan UI.
 */
final class ProjectorRemoteSettings {
    private ProjectorRemoteSettings() {}

    private static final String TV_SETTINGS_PACKAGE = "com.android.tv.settings";
    private static final String ADD_ACCESSORY_ACTIVITY =
            "com.android.tv.settings.accessories.AddAccessoryActivity";
    private static final String ADD_ACCESSORY_ACTION =
            "com.google.android.intent.action.CONNECT_INPUT";

    private static boolean auditedFirmware() {
        return Build.VERSION.SDK_INT == 28
                && "MiProjM05".equals(Build.MODEL)
                && "eva".equals(Build.DEVICE)
                && "PQ3B.190705.003.4185".equals(Build.DISPLAY);
    }

    private static boolean isTrustedSettingsPackage(String pkg) {
        return "com.android.tv.settings".equals(pkg)
                || "com.fengmi.fmsettings".equals(pkg)
                || "com.formovie.gsettings".equals(pkg);
    }

    private static boolean isUsableFactoryActivity(ActivityInfo info) {
        if (info == null || !info.exported || !info.enabled
                || info.applicationInfo == null || !info.applicationInfo.enabled
                || (info.permission != null && !info.permission.isEmpty())) {
            return false;
        }
        int factoryFlags = ApplicationInfo.FLAG_SYSTEM | ApplicationInfo.FLAG_UPDATED_SYSTEM_APP;
        return (info.applicationInfo.flags & factoryFlags) != 0;
    }

    /** Only the exact audited firmware gets this specific OEM activity path. */
    private static Intent factoryPairingIntent(PackageManager pm) {
        if (!auditedFirmware()) return null;
        ComponentName target = new ComponentName(TV_SETTINGS_PACKAGE, ADD_ACCESSORY_ACTIVITY);
        try {
            ActivityInfo info = pm.getActivityInfo(target, 0);
            if (!isUsableFactoryActivity(info)
                    || !TV_SETTINGS_PACKAGE.equals(info.packageName)
                    || !ADD_ACCESSORY_ACTIVITY.equals(info.name)) {
                return null;
            }
            Intent intent = new Intent(ADD_ACCESSORY_ACTION);
            intent.addCategory(Intent.CATEGORY_DEFAULT);
            intent.setComponent(target);
            // Never pass "no_input_mode" or other hidden pairing/autopairing extras.
            return intent;
        } catch (PackageManager.NameNotFoundException | SecurityException ignored) {
            return null;
        }
    }

    static void openFromUserTap(Activity activity) {
        final PackageManager pm = activity.getPackageManager();
        final Intent factory = factoryPairingIntent(pm);
        if (factory != null) {
            try {
                activity.startActivity(factory);
                return;
            } catch (RuntimeException ignored) {
                // Component could be restricted at launch despite manifest preflight.
            }
        }

        final Intent bluetooth = new Intent(Settings.ACTION_BLUETOOTH_SETTINGS);
        try {
            ResolveInfo resolved = pm.resolveActivity(bluetooth, PackageManager.MATCH_DEFAULT_ONLY);
            ActivityInfo info = resolved == null ? null : resolved.activityInfo;
            if (isUsableFactoryActivity(info) && isTrustedSettingsPackage(info.packageName)) {
                // Explicit target only, to prevent interception by an untrusted app.
                bluetooth.setClassName(info.packageName, info.name);
                activity.startActivity(bluetooth);
                return;
            }
        } catch (RuntimeException ignored) {
            // Missing/privileged standard Bluetooth settings: use all TV settings.
        }

        try {
            activity.startActivity(new Intent(Settings.ACTION_SETTINGS));
        } catch (RuntimeException ignored) {
            // Keep existing UI usable; never try to change pairing state.
        }
    }
}
