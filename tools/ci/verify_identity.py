#!/usr/bin/env python3
"""Validate FreeMyProjector identity, version policy and P-04 safety lock.

This is static inspection. It never signs, installs or changes any device.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[2]
ANDROID = "{http://schemas.android.com/apk/res/android}"
PACKAGE = "com.fader.freemyprojector"
CLASSES = {
    "App", "SettingsActivity", "HomeActivity", "Screensaver", "ScreensaverAlone",
    "ModeJob", "RemoteKeyService", "HomeReceiver",
}


def verify() -> tuple[str, int]:
    root = ET.parse(ROOT / "app/AndroidManifest.xml").getroot()
    assert root.attrib.get("package") == PACKAGE, "Wrong Android package"
    name = root.attrib.get(ANDROID + "versionName", "")
    assert re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", name), "VersionName must be x.y.z"
    major, minor, patch = [int(x) for x in name.split(".")]
    assert minor < 1000 and patch < 1000, "Version minor and patch must be < 1000"
    code = major * 1000000 + minor * 1000 + patch
    assert 1 <= code <= 2100000000, "Invalid versionCode bounds"
    assert root.attrib.get(ANDROID + "versionCode") == str(code), "VersionCode must match x.y.z calculation"

    application = root.find("application")
    assert application is not None, "Missing Android application element"
    assert application.attrib.get(ANDROID + "label") == "FreeMyProjector", "Wrong application label"
    app_class = application.attrib.get(ANDROID + "name", "")
    assert app_class == "io.freemytv.App", f"Wrong application Java class: {app_class}"
    assert (ROOT / "app/src/io/freemytv/App.java").is_file(), "Missing Application Java class"
    seen = {"App"}
    for component in application:
        if component.tag not in ("activity", "service", "receiver"):
            continue
        cls = component.attrib.get(ANDROID + "name", "")
        assert cls.startswith("io.freemytv."), f"Use absolute class names: {cls}"
        assert (ROOT / "app/src" / pathlib.Path(*cls.split(".")).with_suffix(".java")).is_file(), f"Missing Java class: {cls}"
        seen.add(cls.removeprefix("io.freemytv."))
        label = component.attrib.get(ANDROID + "label")
        if label is not None:
            assert label == "FreeMyProjector", f"Unexpected Android label: {label}"
    assert seen == CLASSES, f"Unexpected manifest classes; missing {CLASSES - seen}, extra {seen - CLASSES}"

    homemode = (ROOT / "app/src/io/freemytv/HomeMode.java").read_text(encoding="utf-8")
    job = (ROOT / "app/src/io/freemytv/ModeJob.java").read_text(encoding="utf-8")
    build = (ROOT / "build.sh").read_text(encoding="utf-8")
    assert f'static final String PKG = "{PACKAGE}"' in homemode, "Incorrect HOME app ID"
    assert 'static final String JAVA_CLASS_PREFIX = "io.freemytv."' in homemode, "Incorrect HOME class namespace"
    assert 'PROJECTOR_HOME_SWITCH_AUDITED = false' in job, "P-04 HOME safety lock unexpectedly enabled"
    assert "if (!PROJECTOR_HOME_SWITCH_AUDITED) return;" in job, "ADB schedule guard missing"
    assert "if (!PROJECTOR_HOME_SWITCH_AUDITED) return false;" in job, "ADB execution guard missing"
    assert "freemytv.keystore" not in build, "Legacy keystore usage still exists"
    assert "pass:freemytv" not in build, "Legacy static signing password still exists"
    assert 'keytool -genkeypair' not in build.lower(), "Build must not generate signing keys"
    assert "env:FMP_SIGNING_STORE_PASSWORD" in build, "Keystore password must come from env"
    assert "env:FMP_SIGNING_KEY_PASSWORD" in build, "Key password must come from env"
    assert "FMP_BUILD_UNSIGNED" in build, "Unsigned PR CI mode removed"
    assert "--custom-package io.freemytv" in build, "Java R namespace does not match sources"
    assert "if (!ModeJob.PROJECTOR_HOME_SWITCH_AUDITED)" in homemode, "User-facing HOME request guard missing"
    # MiProjM05 protections must remain effective even when future HOME work starts.
    guard = homemode.split("private static boolean isProtectedPackage(String pkg)", 1)
    assert len(guard) == 2, "Missing OEM package protection helper"
    for prefix in ('com.fengmi.', 'com.formovie.', 'cn.formovie.', 'com.droidlogic.'):
        assert f'pkg.startsWith("{prefix}")' in guard[1], f"Missing OEM prefix protection: {prefix}"
    assert 'pkg.equals("com.droidlogic")' in guard[1], "Droidlogic root package must be protected"
    assert homemode.count("if (isProtectedPackage(pkg) ||") == 2, "Disabling path bypasses OEM guard"
    protected = homemode.split("private static final Set<String> PROTECTED =", 1)
    assert len(protected) == 2, "Missing protected package list"
    protected = protected[1].split("));", 1)[0]
    mi_proj_keep = (
        "com.fengmi.projector.imaging", "com.fengmi.fmsettings", "com.fengmi.platform",
        "com.fengmi.autofocustest", "com.fengmi.projector135MGN",
        "com.fengmi.projector045G", "com.fengmi.projector055G", "com.fengmi.testsuite",
        "com.google.android.tvlauncher", "com.google.android.leanbacklauncher",
        "com.google.android.tvrecommendations", "com.google.android.leanbacklauncher.recommendations",
        "android.autoinstalls.config.xiaomi",
        "com.droidlogic", "com.droidlogic.tvinput", "com.droidlogic.SubTitleService",
        "com.droidlogic.ble", "com.droidlogic.overlay",
        "com.formovie.gsettings", "com.formovie.fmutils", "com.formovie.launchboard",
        "cn.formovie.fengos.usermanual", "com.android.camera2",
    )
    for pkg in mi_proj_keep:
        assert f'"{pkg}"' in protected, f"MiProjM05 package must remain protected: {pkg}"
    # P-04A: factory imaging bridge is a passive metadata probe, not an OEM launch.
    oem = (ROOT / "app/src/io/freemytv/ProjectorFactoryScreens.java").read_text(encoding="utf-8")
    for required in (
        'Build.VERSION.SDK_INT == 28',
        '"MiProjM05".equals(Build.MODEL)',
        '"eva".equals(Build.DEVICE)',
        '"PQ3B.190705.003.4185".equals(Build.DISPLAY)',
        'pm.getActivityInfo(', '!info.exported', 'info.permission != null',
        'TARGET.equals(info.targetActivity)',
        'START_FOCUS', 'START_KEYSTONE',
        'case FOCUS:', 'case KEYSTONE:',
    ):
        assert required in oem, f"OEM passive preflight guard missing: {required}"
    for forbidden in ('START_AUTO_KEYSTONE', 'AutoKeystoneActivity',
                      'Runtime.getRuntime', 'ProcessBuilder', 'settings put',
                      'set-home-activity', 'pm disable'):
        assert forbidden not in oem, f"Forbidden OEM/ADB operation in passive preflight: {forbidden}"
    oem_without_comments = re.sub(r"/\*.*?\*/|//[^\n]*", "", oem, flags=re.DOTALL)
    assert re.search(r"\bstartActivity\s*\(", oem_without_comments) is None, (
        "OEM bridge must never start an OEM Activity"
    )

    # P-04H: factory Bluetooth entry must be a user-triggered, runtime-gated
    # OEM activity. These static checks complement (not replace) physical testing.
    pairing = (ROOT / "app/src/io/freemytv/ProjectorRemoteSettings.java").read_text(encoding="utf-8")
    pairing_without_comments = re.sub(r"/\*.*?\*/|//[^\n]*", "", pairing, flags=re.DOTALL)
    for required in (
        '"com.android.tv.settings.accessories.AddAccessoryActivity"',
        '"com.google.android.intent.action.CONNECT_INPUT"',
        'Build.VERSION.SDK_INT == 28',
        '"MiProjM05".equals(Build.MODEL)',
        '"eva".equals(Build.DEVICE)',
        '"PQ3B.190705.003.4185".equals(Build.DISPLAY)',
        'pm.getActivityInfo(target, 0)',
        'info.exported', 'info.enabled', 'info.permission',
        'ApplicationInfo.FLAG_SYSTEM', 'ApplicationInfo.FLAG_UPDATED_SYSTEM_APP',
        'intent.setComponent(target)',
        'static void openFromUserTap(Activity activity)',
        'Settings.ACTION_BLUETOOTH_SETTINGS', 'Settings.ACTION_SETTINGS',
    ):
        assert required in pairing_without_comments, f"Missing OEM pairing preflight: {required}"
    for forbidden in (
        'BluetoothPairingDialog', 'BluetoothDevicePickerActivity',
        'FMBlePairingDialog', 'BluetoothPairingRequest',
        'createBond(', 'removeBond(', 'setHome', 'set-home-activity',
        'Runtime.getRuntime(', 'ProcessBuilder', 'am start', 'settings put',
        'no_input_mode', 'startDiscovery(', 'ACTION_PAIRING_REQUEST',
    ):
        assert forbidden not in pairing_without_comments, f"Unsafe pairing bridge action: {forbidden}"
    settings_ui = (ROOT / "app/src/io/freemytv/SettingsActivity.java").read_text(encoding="utf-8")
    assert settings_ui.count("ProjectorRemoteSettings.openFromUserTap(activity);") == 1, (
        "Remote entry point must only be invoked from the settings OK handler"
    )

    release = (ROOT / ".github/workflows/signed-release.yml").read_text(encoding="utf-8")
    ci = (ROOT / ".github/workflows/android-build.yml").read_text(encoding="utf-8")
    assert "workflow_dispatch:" in release, "Release workflow is not manually triggered"
    assert "pull_request:" not in release, "PR must never trigger signed releases"
    assert "push:" not in release, "Push must never trigger signed releases"
    assert "github.ref == 'refs/heads/main'" in release, "Release workflow must be main-only"
    assert "--prerelease" in release, "Release must remain pre-release until manual device testing"
    assert "FMP_RELEASE_KEYSTORE_B64" in release, "Signing secret must be supplied by owner"
    # Protect release metadata and package regex checks against partial renames.
    assert r"com\.fader\.freemyprojector" in release, "Signed release checks wrong package"
    assert r"com\.fader\.freemyprojector" in ci, "Unsigned build checks wrong package"
    for package_file in (
        "app/AndroidManifest.xml",
        "app/src/io/freemytv/HomeMode.java",
        ".github/workflows/android-build.yml",
        ".github/workflows/signed-release.yml",
    ):
        assert "com.panasenkof.freemyprojector" not in (
            ROOT / package_file
        ).read_text(encoding="utf-8"), f"Stale package ID in {package_file}"
    assert re.search(r"\$\{\{\s*secrets\.", ci) is None, "PR build must never receive release secrets"
    return name, code


def main() -> None:
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument("--github-output", type=pathlib.Path)
    options = args_parser.parse_args()
    version, code = verify()
    print(f"PASS: package={PACKAGE}; version={version}; code={code}; P-04 gate locked")
    if options.github_output:
        with options.github_output.open("a", encoding="utf-8") as f:
            f.write(f"version={version}\nversion_code={code}\ntag=v{version}\n")


if __name__ == "__main__":
    main()
