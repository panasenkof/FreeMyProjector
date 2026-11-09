#!/usr/bin/env python3
"""Offline static regression checks for the P-10 selective upstream app shelf sync.

The Android build job separately compiles the APK. No device or ADB is required.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HOME_APPS = ROOT / "app/src/io/freemytv/HomeApps.java"
MODE_JOB = ROOT / "app/src/io/freemytv/ModeJob.java"

EXPECTED = {
    "Кинопоиск": "ru.kinopoisk.tv",
    "Okko": "ru.more.play",
    "Premier": "gpm.tnt_premier",
    "Амедиатека": "ru.amediateka",
    "Wink": "ru.rt.video.app.tv",
}


class RussianShelfSyncTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = HOME_APPS.read_text(encoding="utf-8")
        cls.section = cls.source.split("private static final String[][] SHELF = {", 1)[1].split("};", 1)[0]
        cls.entries = re.findall(
            r'\{\s*"([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*"([0-9A-F]{6})",\s*"([^"]*)",\s*"([^"]+)"\s*\}',
            cls.section,
        )

    def test_five_reference_apps_have_exact_known_packages(self):
        for label, package in EXPECTED.items():
            matches = [e for e in self.entries if e[1] == label and e[2] == package]
            self.assertEqual(1, len(matches), label)

    def test_package_ids_are_unique(self):
        packages = [e[2] for e in self.entries]
        self.assertEqual(len(packages), len(set(packages)))

    def test_installed_only_and_user_order_are_preserved(self):
        self.assertIn("if (custom != null) return custom;", self.source)
        self.assertIn("launchIntent(pm, d[2]) != null", self.source)
        self.assertIn("static final int MAX_SHELF = ShelfSizing.MAX_ITEMS;", self.source)
        self.assertIn("static final int DEFAULT_SHELF_SIZE = ShelfSizing.DEFAULT_ITEMS;", self.source)
        self.assertIn("if (items.size() >= MAX_SHELF) break;", self.source)
        self.assertIn("if (out.size() >= MAX_SHELF) break;", self.source)

    def test_any_launchable_play_app_can_be_favorited(self):
        self.assertIn("Intent.CATEGORY_LAUNCHER", self.source)
        self.assertIn("Intent.CATEGORY_LEANBACK_LAUNCHER", self.source)
        self.assertIn("if (launchIntent(pm, pkg) == null) continue;", self.source)
        self.assertIn("if (!pkg.equals(c.getPackageName())", self.source)

    def test_home_switch_and_recovery_remain_locked(self):
        safety = MODE_JOB.read_text(encoding="utf-8")
        self.assertIn("PROJECTOR_HOME_SWITCH_AUDITED = false", safety)
        self.assertIn("PROJECTOR_RECOVERY_AUDITED = false", safety)


if __name__ == "__main__":
    unittest.main()
