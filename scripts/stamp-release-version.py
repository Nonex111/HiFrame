#!/usr/bin/env python3
"""Set a numeric release version in a built application before code signing."""

import argparse
import plistlib
import re
from pathlib import Path


def stamp(path: Path, version: str) -> None:
    if not re.fullmatch(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", version):
        raise ValueError("Release version must have the form 1.2.3")
    with path.open("rb") as stream:
        info = plistlib.load(stream)
    if info.get("CFBundleIdentifier") != "com.local.SteadyFrame":
        raise ValueError("Unexpected app bundle identifier")
    info["CFBundleShortVersionString"] = version
    # Keep the build version ordered with the release version as well.
    info["CFBundleVersion"] = version
    with path.open("wb") as stream:
        plistlib.dump(info, stream, sort_keys=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plist", type=Path)
    parser.add_argument("version")
    args = parser.parse_args()
    stamp(args.plist, args.version)
