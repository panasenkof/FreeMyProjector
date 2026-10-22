#!/usr/bin/env python3
"""Reject duplicate or non-increasing release tags before signing/publishing."""
import argparse
import re
import subprocess
import sys

def semver(tag: str):
    found = re.fullmatch(r"v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", tag)
    return tuple(map(int, found.groups())) if found else None

def main():
    p = argparse.ArgumentParser()
    p.add_argument("tag")
    args = p.parse_args()
    target = semver(args.tag)
    if target is None:
        sys.exit("Invalid release tag format; expected vMAJOR.MINOR.PATCH")
    tags = subprocess.check_output(["git", "tag", "--list", "v*"], text=True).splitlines()
    for tag in tags:
        prior = semver(tag)
        if prior is None:
            continue
        if prior >= target:
            sys.exit(f"Refusing non-increasing release version {args.tag}; found {tag}")
    print(f"PASS: release tag {args.tag} is greater than existing semver tags.")

if __name__ == "__main__":
    main()
