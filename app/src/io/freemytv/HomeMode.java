package io.freemytv;

import android.content.Context;
import android.os.Build;
import android.os.SystemClock;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Original ⇄ Free My TV. "free": our home screen and screensaver, and the apps in the lists below turned off
 * (pm disable-user: still installed, back with one button). "original": everything as it came from the factory.
 *
 * It all goes through the TV's own ADB (Adb, 127.0.0.1:5555), which you allow once on the TV. The switches run as
 * background jobs (ModeJob) in the main process; the settings screen (the :home process) asks for them and follows the
 * state file. Only the TV itself asks for switches: nothing here listens to the network.
 */
final class HomeMode {
    private HomeMode() {}

    /** Installed Android package differs from the original Java namespace. */
    static final String PKG = "com.fader.freemyprojector";
    static final String JAVA_CLASS_PREFIX = "io.freemytv.";
    static final String HOME_ACTIVITY = PKG + "/" + JAVA_CLASS_PREFIX + "HomeActivity";
    static final String SETTINGS_ACTIVITY = PKG + "/" + JAVA_CLASS_PREFIX + "SettingsActivity";
    /** Our screensaver: on Android 11 the copy that runs in the main process (ScreensaverAlone, #10). */
    static final String DREAM = PKG + "/" + JAVA_CLASS_PREFIX + (Build.VERSION.SDK_INT == 30 ? "ScreensaverAlone" : "Screensaver");
    static final String FREE = "free", ORIGINAL = "original";

    /** Classic Android TV's home screen; its recommendations service crashes on the screensaver while it's off (#11). */
    static final String TV_LAUNCHER = "com.google.android.tvlauncher";
    static final String TV_RECOMMENDATIONS = "com.google.android.tvrecommendations";
    /** Google TV's home screen: the fallback when the TV's own one wasn't recorded. */
    static final String GOOGLE_HOME = "com.google.android.apps.tv.launcherx/.home.HomeActivity";
    /**
     * Google TV has a RecoveryActivity that would take over the home screen without its launcher. Older Android TV
     * (Android 9) has the same setup app without a home screen: there it is left alone.
     */
    static final String GOOGLE_SETUP = "com.google.android.tungsten.setupwraith";

    /**
     * Turned off in Free My TV mode, when the TV has them. Google extras first, then TV-maker extras (TCL here; add
     * your brand's, see the README). The TV's own home screen and screensaver are added at switch time.
     */
    static final String[] DEBLOAT = {
        "com.google.android.play.games", "com.google.android.youtube.tvmusic",        // Play Games, YouTube Music
        // TCL
        "com.tcl.magiconnectfree", "com.tcl.miracast",                                // screen mirroring apps
        "com.tcl.waterfall.overseas", "com.tcl.channelplus",                          // TCL Channel and its Live TV
        "com.tcl.messagebox", "com.tcl.usercenter",                                   // TCL messages and account
        "com.tcl.exhibit", "com.tcl.esticker", "com.tcl.hotelmenu",                   // store demo, hotel menu
        "com.tcl.repairguide", "com.tcl.ocean.instructions", "com.tcl.logkit",        // repair guide, manual, logs
        // Multilaser (Expressluck / CVTE board)
        "tv.anoki.acr.anokiacroptin",                                                 // Anoki ACR: watches what's on screen
        "fusion.android.tv.demo", "com.expressluck.tvhelpmanual",                     // store demo, manual
        // Philco (Homwee/Changhong)
        "com.homwee.aipont",                                                          // AI PONT: promo channels, app downloads
        "com.homwee.help",                                                            // user manual
        // Xiaomi
        "com.miui.tv.analytics", "com.xiaomi.statistic",                              // telemetry
        "com.mitv.tvhome.mitvplus", "com.xm.webcontent",                              // Mi TV+ promo channels, promo web content
    };

    /** The voice assistant, only with disable_assistant=true in config.properties (the mic button stops working). */
    static final String[] ASSISTANT = {"com.google.android.katniss", "com.android.hotwordenrollment.okgoogle"};

    /** Never turned off, not even by mistake (picture, sound, inputs, remote, store). Checked before every disable. */
    private static final Set<String> PROTECTED = new HashSet<>(Arrays.asList(
        "com.tcl.ttvs", "com.tvos", "com.tcl.systemserver", "com.tcl.systemui.plugin", "com.tcl.tv", "com.tcl.tvinput",
        "com.tcl.hearaid", "com.dolby.android.audio.service", "com.tcl.globalkeyoverlay", "com.tcl.autopair",
        "com.tcl.UpdatePeripheral", "com.tcl.dashboard", "com.tcl.suspension", "com.tcl.providers.config",
        "com.tcl.gamebar", "com.tcl.airplay2", "com.mirakulo.astrotv.service", "com.tcl.initsetup",
        "com.tcl.useragreement", "com.tcl.factory.view", "com.tcl.guard", "com.tcl.t_solo",
        "com.google.android.gms", "com.google.android.gsf", "com.android.vending", "com.google.android.apps.mediashell",
        "com.google.android.tv.remote.service", "com.google.android.inputmethod.latin", "com.google.android.webview",
        "com.android.tv.settings", "com.android.systemui", "android", PKG,
        // Philips (TP Vision) and MediaTek: system, Ambilight, live TV and inputs, setup, factory menu (#11)
        "org.droidtv", "org.droidtv.ambisvc", "org.droidtv.ui.strings", "org.droidtv.tv.packageinfo", "org.droidtv.icp",
        "org.droidtv.gel", "org.droidtv.eum", "com.mediatek.tv.service", "com.mediatek.tvinput", "com.mediatek.network",
        "com.mediatek.wwtv.tvcenter", "com.mediatek.wwtv.setupwizard", "com.mediatek.tv.factory",
        "mediatek.factorymenu.ui", "com.tpv.xmic.ots.cms.client",
        // Multilaser (Expressluck / CVTE): remote pairing and keys, live TV, media player, factory menus
        "com.express.bt.autopair", "com.mediatek.autopair", "com.mediatek.hotkey.dispatcher",
        "com.mediatek.android.tv.globalkeyoverlay", "com.cltv.fast", "com.mediatek.wwtv.mediaplayer",
        "com.mediatek.androidbox", "com.expressluck.facmenu", "com.express.at.factory.factorymanager",
        "com.at.factory.androidtvaidlservice", "com.cvte.tv.at", "com.cvte.tv.fac.aging", "com.express.fac.test",
        // Philco (Homwee/Changhong, MediaTek): picture tests, overlays, updates, factory menu (pairing is above)
        "com.mediatek.tv.factorykey", "com.mediatek.testpq", "com.mediatek.overlay.tvcenter",
        "com.mediatek.overlay.tvsettings", "com.homwee.overlay.tvservice", "com.homwee.synckey", "com.homwee.upgrade",
        "com.homwee.dmt.upgrade", "com.homwee.factory", "com.homwee.chinstallapk", "com.homwee.chtvmanager",
        "com.mstar.android.tv.disclaimercustomization",
        // Xiaomi (MediaTek): system service, remote pairing, live TV, quick settings, child lock, updates, casting
        "mitv.service", "com.mi.bluetooth", "com.mitv.livetv.ci_mediatek", "com.xiaomi.tvqs.overseas",
        "com.mitv.tvlock", "com.xiaomi.mitv.updateservice", "com.xiaomi.android.tvsetup.partnercustomizer",
        "com.mitv.overseaservice", "com.xiaomi.mitv.tvmanager", "com.xiaomi.wfdsinkhelperservice",
        "com.mitv.milinkservice", "com.xiaomi.mitv.smartshare", "android.autoinstalls.config.xiaomi.amelie",
        // MiProjM05/eva, firmware PQ3B.190705.003.4185: observed installed on 2026-10-24.
        // Keep the OEM stack AND a known-good stock HOME available as recovery.
        // Package names alone do not establish hardware dependencies or safe entry points.
        "com.fengmi.projector.imaging", "com.fengmi.fmsettings", "com.fengmi.platform",
        "com.fengmi.autofocustest", "com.fengmi.projector135MGN",
        "com.fengmi.projector045G", "com.fengmi.projector055G", "com.fengmi.testsuite",
        "com.google.android.tvlauncher", "com.google.android.leanbacklauncher",
        "com.google.android.tvrecommendations", "com.google.android.leanbacklauncher.recommendations",
        "android.autoinstalls.config.xiaomi",
        // MiProjM05/eva build .4185: independently observed through read-only package list.
        // HDMI is linked to Droidlogic in CleanYourTV for .2102; preserve all OEM services
        // on our firmware until exact dependencies and recovery are verified.
        "com.droidlogic", "com.droidlogic.tvinput", "com.droidlogic.SubTitleService",
        "com.droidlogic.ble", "com.droidlogic.overlay",
        "com.formovie.gsettings", "com.formovie.fmutils", "com.formovie.launchboard",
        "cn.formovie.fengos.usermanual", "com.android.camera2"));

    /** Protect unverified OEM optical/HDMI/remote components on MiProjM05. */
    private static boolean isProtectedPackage(String pkg) {
        return pkg != null && (PROTECTED.contains(pkg) || pkg.startsWith("com.fengmi.")
                || pkg.startsWith("com.formovie.") || pkg.startsWith("cn.formovie.")
                || pkg.equals("com.droidlogic") || pkg.startsWith("com.droidlogic."));
    }

    /** One switch at a time (jobs can overlap: a boot check and a button press). */
    private static final Object RUN = new Object();
    private static final Object FILE_LOCK = new Object();

    // MARK: - Requests (from any process)

    /** Asks the main process to switch (the settings screen calls this). */
    static void request(Context c, String mode) {
        // P-04 safety gate: no launcher, Wi-Fi, package or screensaver changes
        // until rollback has been audited on Xiaomi MiProjM05.
        if (!ModeJob.PROJECTOR_HOME_SWITCH_AUDITED) {
            notice(c, "Home switching is disabled pending Xiaomi safety verification (P-04).");
            return;
        }
        ModeJob.schedule(c, ModeJob.APPLY, mode, 0);
    }

    /** Our home screen crashed 3 times in 5 minutes: give the home screen back to the TV's own (asked by :home). */
    static void requestRevertHome(Context c) {
        ModeJob.schedule(c, ModeJob.REVERT, null, 0);
    }

    /** After the TV boots (and after a TV update): wait for the system to settle and check Free My TV mode. */
    static void bootCheck(Context c) {
        ensureRemoteService(c, 30_000);
        ModeJob.schedule(c, ModeJob.VERIFY, null, 45_000);
    }

    /** After an update of this app: complete Free My TV mode if anything is missing. */
    static void verify(Context c) {
        ModeJob.schedule(c, ModeJob.VERIFY, null, 0);
    }

    /**
     * The remote's app buttons (RemoteKeys) need an accessibility service that only filters those keys. It is on only
     * on TCL and Vestel TVs in Free My TV mode, and goes off with Original. Android turns it off when this app is updated, so the
     * boot check and an update turn it back on.
     */
    static void ensureRemoteService(Context c, long delayMs) {
        if (RemoteKeys.supported()) ModeJob.schedule(c, ModeJob.REMOTE, null, delayMs);
    }

    static void ensureRemoteServiceNow(Context app) {
        if (!RemoteKeys.supported() || !FREE.equals(state(app).optString("mode"))) return;
        try (Adb adb = Adb.connect(app, 10_000, null)) {
            remoteService(app, adb, true);
        } catch (IOException e) {
            AppLog.w("remote buttons service: " + e.getMessage());
        }
    }

    private static final String REMOTE_SERVICE = PKG + "/" + JAVA_CLASS_PREFIX + "RemoteKeyService";
    private static final Pattern SERVICE = Pattern.compile("[\\w.]+/[\\w.$]+");

    /** Adds ours to the enabled accessibility services (keeping the others, like TalkBack), or takes it out. */
    private static void remoteService(Context c, Adb adb, boolean on) throws IOException {
        String current = adb.shell("settings get secure enabled_accessibility_services").trim();
        if (current.equals("null")) current = "";
        List<String> others = new ArrayList<>();
        for (String one : current.split(":")) {
            if (one.isEmpty() || one.equals(REMOTE_SERVICE)) continue;
            // Only plain component names go back into the shell command; anything else is left alone.
            if (!SERVICE.matcher(one).matches()) {
                AppLog.w("accessibility services left as they are: unexpected entry");
                return;
            }
            others.add(one);
        }
        if (on == current.contains(REMOTE_SERVICE)) return;
        List<String> list = new ArrayList<>(others);
        if (on) {
            JSONObject s = state(c);
            try { s.put("accessibilityWasOff", !"1".equals(adb.shell("settings get secure accessibility_enabled").trim())); }
            catch (JSONException ignored) {}
            save(c, s);
            list.add(REMOTE_SERVICE);
        }
        adb.shell(list.isEmpty() ? "settings delete secure enabled_accessibility_services"
                : "settings put secure enabled_accessibility_services '" + String.join(":", list) + "'");
        if (on) adb.shell("settings put secure accessibility_enabled 1");
        else if (list.isEmpty() && state(c).optBoolean("accessibilityWasOff")) adb.shell("settings put secure accessibility_enabled 0");
        AppLog.w("remote buttons service " + (on ? "on" : "off"));
    }

    // MARK: - Switches (main process, from ModeJob)

    static void applyNow(Context c, String mode) {
        synchronized (RUN) {
            if (FREE.equals(mode)) applyFree(c); else applyOriginal(c);
        }
    }

    /** P-04: never debloat, enable OEM packages or modify the OEM screensaver. */
    private static void applyFree(Context c) {
        // Future HOME pilot needs a separately audited journal and rollback.
        // Keeping the original upstream logic reachable by flipping a flag
        // would violate ADR-001. Refuse rather than perform partial changes.
        notice(c, "Projector HOME switch is unavailable until the recovery pilot is audited.");
        done(c, null);
    }

    /** Restore only the exact saved stock HOME; never modify package states. */
    private static void applyOriginal(Context c) {
        JSONObject s = state(c);
        try (Adb adb = connect(c, s)) {
            String home = originalHome(s);
            if (!restoreHome(adb, home)) {
                throw new IOException("Stock HOME not verified; original mode NOT confirmed");
            }
            s = state(c);
            s.put("mode", ORIGINAL).put("homeReverted", true);
            save(c, s);
            notice(c, "Factory HOME restored and independently verified; OEM apps untouched.");
            done(c, null);
        } catch (Exception e) {
            done(c, "Factory HOME rollback unverified: " + e.getMessage());
        }
    }

    /** Only the verified MiProjM05 stock component is an acceptable rollback target. */
    static final String MIPROJ_STOCK_HOME = "com.google.android.tvlauncher/.MainActivity";

    private static String canonicalComponent(String component) {
        component = safeComponent(component);
        if (component.isEmpty()) return "";
        String[] parts = component.split("/", 2);
        String name = parts[1].startsWith(".") ? parts[0] + parts[1] : parts[1];
        return parts[0] + "/" + name;
    }

    private static boolean auditedStockTarget(String home) {
        return Build.VERSION.SDK_INT == 28
                && "MiProjM05".equals(Build.MODEL)
                && "eva".equals(Build.DEVICE)
                && "PQ3B.190705.003.4185".equals(Build.DISPLAY)
                && canonicalComponent(MIPROJ_STOCK_HOME).equals(canonicalComponent(home));
    }

    private static String resolvedHomeComponent(Adb adb) throws IOException {
        String raw = adb.shell("cmd package resolve-activity --brief --user 0 -a android.intent.action.MAIN"
                + " -c android.intent.category.HOME").trim();
        String[] lines = raw.split("\\r?\\n");
        if (lines.length == 0) return "";
        String candidate = lines[lines.length - 1].trim();
        if (candidate.startsWith("android/") || candidate.contains("ResolverActivity")
                || candidate.contains("ChooserActivity") || candidate.contains("FallbackHome")
                || candidate.contains("SetupWizard") || candidate.contains("RecoveryActivity")) return "";
        return canonicalComponent(candidate);
    }

    private static boolean restoreHome(Adb adb, String home) throws IOException {
        // No guesses about current role holder, no Android-10+ cmd role fallback,
        // no pm enable, no default-home success based on absence of our package.
        if (!auditedStockTarget(home)) return false;
        if (!adb.shell("pm path com.google.android.tvlauncher").contains("package:")) return false;
        if (adb.shell("pm list packages -d --user 0")
                .contains("package:com.google.android.tvlauncher")) return false;
        String expected = canonicalComponent(MIPROJ_STOCK_HOME);
        if (expected.equals(resolvedHomeComponent(adb))) return true;
        String result = adb.shell("cmd package set-home-activity --user 0 '" + MIPROJ_STOCK_HOME + "'");
        return result.contains("Success") && expected.equals(resolvedHomeComponent(adb));
    }

    /** Crash recovery is independently locked until device-side recovery is audited. */
    static void revertHomeNow(Context app) {
        if (!ModeJob.PROJECTOR_RECOVERY_AUDITED) return;
        synchronized (RUN) {
            JSONObject s = state(app);
            // Never treat a stale or foreign state file as authority to change HOME.
            if (!FREE.equals(s.optString("mode"))) return;
            String home = originalHome(s);
            if (!auditedStockTarget(home)) {
                AppLog.w("rollback refused: stock HOME baseline invalid");
                return;
            }
            try (Adb adb = Adb.connect(app, 10_000, null)) {
                if (!restoreHome(adb, home)) {
                    AppLog.w("rollback refused or result unverified");
                    return;
                }
                s.put("mode", ORIGINAL).put("homeReverted", true);
                save(app, s);
                notice(app, "Factory HOME verified; OEM package and screensaver state unchanged.");
            } catch (Exception e) {
                AppLog.w("rollback failed; success not claimed: " + e.getMessage());
            }
        }
    }

    /** P-04: read-only guard; never re-disable OEM packages or silently reassert HOME. */
    static void verifyNow(Context app) {
        if (!ModeJob.PROJECTOR_HOME_SWITCH_AUDITED) return;
        JSONObject s = state(app);
        if (!FREE.equals(s.optString("mode"))) return;
        try (Adb adb = Adb.connect(app, 10_000, null)) {
            // Diagnostic only. A chooser or unexpected HOME is NOT auto-repaired.
            String observed = resolvedHomeComponent(adb);
            if (!canonicalComponent(HOME_ACTIVITY).equals(observed)) {
                AppLog.w("projector HOME differs from expected; no automatic write performed");
            }
        } catch (Exception e) {
            AppLog.w("projector HOME verification unavailable: " + e.getMessage());
        }
    }

    /** The home screen in use now ("package/activity"): the HOME role holder, among the TV's home screens. */
    private static String currentHome(Adb adb) throws IOException {
        String holder = homeHolder(adb);
        if (holder.isEmpty() || holder.contains(PKG)) return null;
        String list = adb.shell("cmd package query-activities --brief --user 0 -a android.intent.action.MAIN"
                + " -c android.intent.category.HOME");
        for (String line : list.split("\n")) {
            line = line.trim();
            if (line.startsWith(holder + "/")) return line;
        }
        return null;
    }

    /**
     * The package that is the home screen now, or "". Some Android 12 TVs have no `cmd role get-role-holders` (it
     * answers "Unknown command"), so then we ask which activity opens HOME.
     */
    private static String homeHolder(Adb adb) throws IOException {
        String holder = adb.shell("cmd role get-role-holders --user 0 android.app.role.HOME").trim();
        if (holder.matches("[\\w.]+(;[\\w.]+)*")) return holder;
        String[] lines = adb.shell("cmd package resolve-activity --brief --user 0 -a android.intent.action.MAIN"
                + " -c android.intent.category.HOME").trim().split("\n");
        String component = lines[lines.length - 1].trim();
        // With no default home yet, the system's chooser answers ("android/...ResolverActivity"): unknown.
        return component.contains("/") && !component.startsWith("android/") ? packageOf(component) : "";
    }

    /** Whether Google TV's setup app is one of the home screens (its RecoveryActivity), so it must go off too. */
    private static boolean setupIsHome(Adb adb) throws IOException {
        return adb.shell("cmd package query-activities --brief --user 0 -a android.intent.action.MAIN"
                + " -c android.intent.category.HOME").contains(GOOGLE_SETUP + "/");
    }

    /** Apps that saved a Wi-Fi network ("cname" in the Wi-Fi service's list of saved networks). */
    private static Set<String> wifiOwners(Adb adb) throws IOException {
        Set<String> owners = new HashSet<>();
        Matcher m = Pattern.compile("cname=([\\w.]+)").matcher(adb.shell("dumpsys wifi | grep -o 'cname=[^ ]*'"));
        while (m.find()) owners.add(m.group(1));
        return owners;
    }

    /** The recorded home screen of the TV, as {@link #realHome}. */
    private static String originalHome(JSONObject s) {
        return realHome(s.optString("originalHome", ""));
    }

    /**
     * Some TVs (TCL, Android 14) leave the HOME role with Google TV's recovery home, while launcherx is the one that
     * answers the Home button. Treat that as launcherx, or it stays on and "original" restores the recovery screen.
     */
    private static String realHome(String home) {
        return home.startsWith(GOOGLE_SETUP + "/") ? GOOGLE_HOME : safeComponent(home);
    }

    private static String originalDream(JSONObject s) {
        return safeComponent(s.optString("originalDream", ""));
    }

    // Nested classes ("Outer$Inner") are valid; every shell command that takes one quotes it, so $ stays literal.
    private static final Pattern COMPONENT = Pattern.compile("[A-Za-z][\\w.]*/[\\w.$]+");

    private static String safeComponent(String component) {
        return COMPONENT.matcher(component).matches() ? component : "";
    }

    private static String safeComponents(String components) {
        for (String one : components.split(",")) {
            if (safeComponent(one).isEmpty()) return "";
        }
        return components;
    }

    /** The system's default screensaver ("package/service"), or "". */
    private static String defaultDream(Adb adb) throws IOException {
        String d = adb.shell("settings get secure screensaver_default_component").trim();
        return d.contains("/") && !d.startsWith(PKG + "/") ? safeComponent(d) : "";
    }

    private static String packageOf(String component) {
        if (component == null || component.isEmpty()) return null;
        int slash = component.indexOf('/');
        return slash > 0 ? component.substring(0, slash) : component;
    }

    /** Packages the shell sees (all; "-d" = only the disabled ones). The app alone can't see the ones it doesn't declare. */
    private static Set<String> packages(Adb adb, String flags) throws IOException {
        Set<String> out = new HashSet<>();
        for (String line : adb.shell("pm list packages " + flags).split("\n")) {
            line = line.trim();
            if (line.startsWith("package:")) out.add(line.substring(8));
        }
        return out;
    }

    private static Adb connect(Context c, JSONObject s) throws IOException {
        busy(c, Ui.tr("Conectando…", "Connecting…"));
        Adb adb = Adb.connect(c, 120_000, () -> busy(c, Ui.tr("Aceite o aviso “Permitir depuração” na TV (marque “Sempre permitir”).",
                "Accept “Allow USB debugging?” on the TV (tick “Always allow”).")));
        if (!s.optBoolean("adbAuthorized")) {
            JSONObject latest = state(c);
            try { latest.put("adbAuthorized", true); } catch (JSONException ignored) {}
            save(c, latest);
        }
        return adb;
    }

    private static void check(String output, String expected, String error) throws IOException {
        if (!output.contains(expected)) throw new IOException(error + " (" + output.trim() + ")");
    }

    // MARK: - Measurements (without opening apps: memory and the home button)

    private static void measureHomeTime(Context c, Adb adb, String mode) throws IOException, JSONException {
        List<Integer> samples = new ArrayList<>();
        Pattern total = Pattern.compile("TotalTime: (\\d+)");
        for (int i = 0; i < 3; i++) {
            adb.shell("am start -W -n " + SETTINGS_ACTIVITY);
            SystemClock.sleep(500);
            Matcher m = total.matcher(adb.shell("am start -W -a android.intent.action.MAIN -c android.intent.category.HOME"));
            if (m.find()) samples.add(Integer.parseInt(m.group(1)));
            SystemClock.sleep(600);
        }
        adb.shell("am start -W -n " + SETTINGS_ACTIVITY);
        if (samples.isEmpty()) return;
        Collections.sort(samples);
        putMetric(c, mode, "homeMs", samples.get(samples.size() / 2));
    }

    /** Two minutes after a switch (the home screen settled, caches trimmed). */
    static void measureMemoryNow(Context c, String mode) {
        synchronized (RUN) {
            if (!mode.equals(state(c).optString("mode"))) return;
            try (Adb adb = Adb.connect(c, 10_000, null)) {
                measureMemory(c, adb, mode);
            } catch (Exception e) {
                AppLog.w("memory measurement failed: " + e.getMessage());
            }
        }
    }

    private static void measureMemory(Context c, Adb adb, String mode) throws IOException, JSONException {
        Matcher avail = Pattern.compile("MemAvailable:\\s+(\\d+) kB").matcher(adb.shell("cat /proc/meminfo"));
        if (avail.find()) putMetric(c, mode, "memAvailableMB", Long.parseLong(avail.group(1)) / 1024);
        long pss = 0;
        String home = packageOf(originalHome(state(c)));
        String[] processes = FREE.equals(mode) ? new String[] {PKG + ":home"}
                : home == null ? new String[0] : new String[] {home, home + ":coreservices"};
        Pattern total = Pattern.compile("TOTAL PSS:\\s+(\\d+)");
        for (String p : processes) {
            Matcher m = total.matcher(adb.shell("dumpsys meminfo " + p));
            if (m.find()) pss += Long.parseLong(m.group(1));
        }
        if (pss > 0) putMetric(c, mode, "homePssMB", pss / 1024);
    }

    private static void putMetric(Context c, String mode, String key, long value) throws JSONException {
        JSONObject s = state(c);
        JSONObject metrics = s.optJSONObject("metrics");
        if (metrics == null) metrics = new JSONObject();
        JSONObject m = metrics.optJSONObject(mode);
        if (m == null) m = new JSONObject();
        m.put(key, value).put("at", System.currentTimeMillis());
        metrics.put(mode, m);
        s.put("metrics", metrics);
        save(c, s);
    }

    private static JSONObject metrics(JSONObject s, String mode) {
        JSONObject metrics = s.optJSONObject("metrics");
        return metrics == null ? null : metrics.optJSONObject(mode);
    }

    // MARK: - State (a file shared by the two processes; atomic writes)

    static JSONObject state(Context c) {
        synchronized (FILE_LOCK) {
            File f = new File(c.getFilesDir(), "home-state.json");
            if (!f.exists()) return defaults();
            try (FileInputStream in = new FileInputStream(f)) {
                byte[] data = new byte[(int) f.length()];
                int read = 0;
                while (read < data.length) {
                    int n = in.read(data, read, data.length - read);
                    if (n < 0) break;
                    read += n;
                }
                return new JSONObject(new String(data, 0, read, StandardCharsets.UTF_8));
            } catch (IOException | JSONException e) {
                return defaults();
            }
        }
    }

    private static JSONObject defaults() {
        try {
            return new JSONObject().put("mode", ORIGINAL);
        } catch (JSONException e) {
            return new JSONObject();
        }
    }

    static void save(Context c, JSONObject s) {
        synchronized (FILE_LOCK) {
            File dir = c.getFilesDir();
            File tmp = new File(dir, "home-state.json.tmp");
            try (FileOutputStream out = new FileOutputStream(tmp)) {
                out.write(s.toString().getBytes(StandardCharsets.UTF_8));
                out.getFD().sync();
            } catch (IOException e) {
                AppLog.w("could not save the state: " + e.getMessage());
                return;
            }
            if (!tmp.renameTo(new File(dir, "home-state.json"))) AppLog.w("could not replace the state file");
        }
    }

    private static void busy(Context c, String text) {
        JSONObject s = state(c);
        try { s.put("busy", text).put("busyAt", SystemClock.elapsedRealtime()).put("error", ""); } catch (JSONException ignored) {}
        save(c, s);
    }

    private static void done(Context c, String error) {
        JSONObject s = state(c);
        s.remove("busy");
        try { s.put("error", error == null ? "" : error); } catch (JSONException ignored) {}
        save(c, s);
        if (error != null) {
            AppLog.w(error);
            notice(c, error);
        }
    }

    /** A notice for the home screen (a bubble) and the settings screen. Keeps the last 20. */
    static void notice(Context c, String text) {
        AppLog.w("notice: " + text);
        JSONObject s = state(c);
        JSONArray old = s.optJSONArray("notices");
        JSONArray list = new JSONArray();
        try {
            list.put(new JSONObject().put("at", System.currentTimeMillis()).put("text", text));
            if (old != null) for (int i = 0; i < old.length() && list.length() < 20; i++) list.put(old.get(i));
            s.put("notices", list);
        } catch (JSONException ignored) {}
        save(c, s);
    }

    // MARK: - Helpers

    static List<String> stringList(JSONObject s, String key) {
        List<String> out = new ArrayList<>();
        JSONArray a = s.optJSONArray(key);
        if (a != null) for (int i = 0; i < a.length(); i++) out.add(a.optString(i));
        return out;
    }

    private static List<String> sorted(Set<String> set) {
        List<String> list = new ArrayList<>(set);
        Collections.sort(list);
        return list;
    }
}
