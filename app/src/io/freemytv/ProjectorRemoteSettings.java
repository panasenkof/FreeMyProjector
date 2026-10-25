package io.freemytv;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Build;
import android.provider.Settings;

/**
 * User-initiated link to OEM-managed Bluetooth/accessory settings.
 *
 * This does not start pairing, enable Bluetooth, alter bonds, or call
 * projector service APIs. The exact MiProjM05 OEM pairing Activity is NOT
 * known until physical read-only P-04H discovery confirms it.
 */
final class ProjectorRemoteSettings {
    private ProjectorRemoteSettings() {}

    private static boolean isTrustedSettingsPackage(String pkg) {
        return "com.android.tv.settings".equals(pkg)
                || "com.fengmi.fmsettings".equals(pkg)
                || "com.formovie.gsettings".equals(pkg);
    }

    static void openFromUserTap(Activity activity) {
        final PackageManager pm = activity.getPackageManager();
        final Intent bluetooth = new Intent(Settings.ACTION_BLUETOOTH_SETTINGS);
        try {
            final ResolveInfo resolved = pm.resolveActivity(bluetooth, PackageManager.MATCH_DEFAULT_ONLY);
            final ActivityInfo info = resolved == null ? null : resolved.activityInfo;
            if (info != null && info.exported && info.enabled
                    && info.applicationInfo != null && info.applicationInfo.enabled
                    && info.permission == null && isTrustedSettingsPackage(info.packageName)) {
                // Pin resolved system component; do not let an untrusted app intercept the action.
                bluetooth.setClassName(info.packageName, info.name);
                activity.startActivity(bluetooth);
                return;
            }
        } catch (RuntimeException ignored) {
            // Not present or inaccessible on this vendor build: use general OEM settings.
        }

        // Existing generic TV settings entry point. It is not a confirmed pairing screen.
        final Intent fallback = new Intent(Settings.ACTION_SETTINGS);
        try {
            activity.startActivity(fallback);
        } catch (RuntimeException ignored) {
            // No vendor settings available. Stay in FreeMyProjector without any mutation.
        }
    }
}
