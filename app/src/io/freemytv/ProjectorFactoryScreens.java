package io.freemytv;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.os.Build;

/**
 * P-04A: strictly passive discovery of factory focus/keystone screens on the
 * audited Xiaomi MiProjM05/eva Android 9 firmware (.4185).
 *
 * No UI uses this bridge yet. It only PREPARES intents after verifying the
 * exported factory aliases are present. Never launches activities, controls
 * motors, changes calibration or switches HOME. External launch must be
 * separately approved and tested as an ordinary app activity.
 */
final class ProjectorFactoryScreens {
    private ProjectorFactoryScreens() {}

    enum Screen {
        FOCUS, KEYSTONE
    }

    private static final String PACKAGE = "com.fengmi.projector.imaging";
    private static final String TARGET = PACKAGE + ".access.ImagingFeatureActivity";

    static final class Preflight {
        final boolean available;
        final String reason;
        final Intent preparedIntent;

        private Preflight(boolean available, String reason, Intent intent) {
            this.available = available;
            this.reason = reason;
            this.preparedIntent = intent;
        }
        static Preflight no(String reason) {
            return new Preflight(false, reason, null);
        }
    }

    private static boolean auditedFirmware() {
        return Build.VERSION.SDK_INT == 28
                && "MiProjM05".equals(Build.MODEL)
                && "eva".equals(Build.DEVICE)
                && "PQ3B.190705.003.4185".equals(Build.DISPLAY);
    }

    /** Read-only PackageManager inspection; no startActivity. */
    static Preflight inspect(Context context, Screen screen) {
        if (context == null || screen == null) return Preflight.no("invalid-argument");
        if (!auditedFirmware()) return Preflight.no("unaudited-firmware");

        final String alias;
        final String action;
        switch (screen) {
            case FOCUS:
                alias = PACKAGE + ".alias.FocusActivity";
                action = PACKAGE + ".action.START_FOCUS";
                break;
            case KEYSTONE:
                alias = PACKAGE + ".alias.KeystoneActivity";
                action = PACKAGE + ".action.START_KEYSTONE";
                break;
            default:
                return Preflight.no("unsupported-screen");
        }

        PackageManager pm = context.getPackageManager();
        try {
            ActivityInfo info = pm.getActivityInfo(new ComponentName(PACKAGE, alias), 0);
            if (!info.exported || !info.enabled || info.applicationInfo == null
                    || !info.applicationInfo.enabled) {
                return Preflight.no("factory-alias-disabled-or-not-exported");
            }
            // Never attempt privileged permission borrowing or bypass.
            if (info.permission != null && !info.permission.isEmpty()) {
                return Preflight.no("factory-alias-requires-permission");
            }
            // Ensure the installed factory alias still targets the audited OEM screen.
            if (!TARGET.equals(info.targetActivity)) {
                return Preflight.no("factory-alias-target-mismatch");
            }

            Intent candidate = new Intent(action);
            candidate.setComponent(new ComponentName(PACKAGE, alias));
            candidate.addCategory(Intent.CATEGORY_DEFAULT);
            // Merely prepares an explicit factory intent. This method NEVER starts it.
            return new Preflight(true, "manifest-preflight-only", candidate);
        } catch (PackageManager.NameNotFoundException e) {
            return Preflight.no("factory-alias-missing");
        } catch (SecurityException e) {
            return Preflight.no("factory-alias-not-accessible");
        }
    }
}
