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
PACKAGE = "com.panasenkof.freemyprojector"
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
