#!/usr/bin/env python3
"""Static safety regression for P-07 probe. No projector or adb is contacted."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools" / "Measure-ProjectorMemoryReadOnly.ps1"


class P07Safety(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.code = SOURCE.read_text(encoding="utf-8")

    def test_gate_and_identity(self):
        c = self.code
        for required in (
            "Test-ProjectorUser0Scope.ps1", "user0-matches-baseline",
            "snapshot_sha256", "active_android_user",
            "com.google.android.tvlauncher/.MainActivity",
            "com.fader.freemyprojector", "MiProjM05",
            "PQ3B.190705.003.4185", "device_writes = 0",
        ):
            self.assertIn(required, c)

    def test_no_mutating_operations(self):
        c = self.code
        for command in (
            "shell','pm','disable", "shell','pm','enable",
            "shell','settings','put", "shell','input','keyevent",
            "shell','adb','tcpip", "shell','reboot",
            "shell','cmd','package','set-home-activity",
            "shell','am','start", "shell','pm','install",
        ):
            self.assertNotIn(command, c)
        self.assertIn("Command outside allowlist", c)
        self.assertIn("'shell cat /proc/meminfo'", c)

    def test_no_raw_device_output(self):
        c = self.code
        self.assertNotRegex(c, r'(?m)^\s*(?:Write-Host|Write-Output|echo)\s+\$')
        self.assertIn("ADB read failed", c)
        self.assertIn("Invalid or inconsistent memory counters", c)
        self.assertIn("ProjectorMemoryParsers.ps1", c)

    def test_documented_phase_and_unmeasured_metrics(self):
        c = self.code
        for phase in ("stock-before", "preview-stock-home",
                      "preview-settings", "preview-after-back"):
            self.assertIn(phase, c)
        self.assertIn("cpu = 'not-measured'", c)
        self.assertIn("temperature = 'not-measured'", c)
        self.assertIn("fps = 'not-measured'", c)


if __name__ == "__main__":
    unittest.main()
