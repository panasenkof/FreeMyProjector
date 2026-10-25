#!/usr/bin/env python3
"""Fail closed if a built P-05 APK exposes dangerous Android components.

Input is aapt2 dump xmltree <apk> AndroidManifest.xml text; this is OFF-DEVICE.
"""
import pathlib
import re
import sys

def main():
    if len(sys.argv) != 2:
        sys.exit("Usage: verify_trial_manifest.py <aapt2-xmltree.txt>")
    manifest = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    if not manifest.strip():
        sys.exit("P-05: empty compiled manifest")
    names = {
        "io.freemytv.SettingsActivity": ("activity", True),
        "io.freemytv.HomeActivity": ("activity", False),
        "io.freemytv.RemoteKeyService": ("service", False),
        "io.freemytv.HomeReceiver": ("receiver", False),
    }
    # Child intent-filter E: nodes are deeper than the component E: node.
    blocks = []
    matches = list(re.finditer(r"(?m)^(\s*)E: (activity|service|receiver)\s+\(", manifest))
    for i, match in enumerate(matches):
        end = matches[i+1].start() if i+1 < len(matches) else len(manifest)
        blocks.append((match.group(2), manifest[match.end():end]))
    for component, (kind, expected_enabled) in names.items():
        found = [body for typ, body in blocks
                 if typ == kind and re.search(
                     r'android:name(?:\([^)]+\))?\s*=\s*"' + re.escape(component) + r'"',
                     body)]
        if len(found) != 1:
            sys.exit(f"P-05: compiled component missing or duplicated: {component}")
        enabled = re.search(r"android:enabled(?:\([^)]+\))?\s*=\s*([^\r\n]+)", found[0])
        if expected_enabled:
            if enabled and (re.search(r"\b0x0\b|false", enabled.group(1), re.I)):
                sys.exit("P-05: SettingsActivity is unexpectedly disabled")
        else:
            if not enabled:
                sys.exit(f"P-05: compiled component lacks explicit disabled flag: {component}")
            val = enabled.group(1)
            if not re.search(r"\b0x0\b|false", val, re.I):
                sys.exit(f"P-05: compiled component is not disabled: {component}")
    print("PASS: compiled Android 9 trial APK has only ordinary Settings enabled; "
          "HOME, remote-key service and boot receiver are disabled.")

if __name__ == "__main__":
    main()
