#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
# ProMotion MacBooks use Apple Silicon; never publish an Intel-only build.
test "$(uname -m)" = arm64
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests/ReleaseTools
swift test -Xswiftc -warnings-as-errors
./scripts/package-download.sh
codesign --verify --deep --strict dist/HiFrame.app
plutil -lint dist/HiFrame.app/Contents/Info.plist \
  dist/HiFrame.app/Contents/Resources/en.lproj/Localizable.strings \
  dist/HiFrame.app/Contents/Resources/zh-Hans.lproj/Localizable.strings
test "$(lipo -archs dist/HiFrame.app/Contents/MacOS/HiFrame)" = arm64
python3 - <<'PY'
import os
import plistlib
import zipfile
from pathlib import Path

root = Path('dist/HiFrame.app/Contents')
info = plistlib.loads((root / 'Info.plist').read_bytes())
assert info['CFBundleName'] == info['CFBundleDisplayName'] == info['CFBundleExecutable'] == 'HiFrame'
assert info['CFBundleIdentifier'] == 'com.local.SteadyFrame'
if os.environ.get('HIFRAME_RELEASE_VERSION'):
    assert info['CFBundleShortVersionString'] == os.environ['HIFRAME_RELEASE_VERSION']
with zipfile.ZipFile('downloads/HiFrame.zip') as archive:
    assert archive.testzip() is None
    assert archive.read('HiFrame.app/Contents/Info.plist') == (root / 'Info.plist').read_bytes()
    assert archive.read('HiFrame.app/Contents/MacOS/HiFrame') == (root / 'MacOS/HiFrame').read_bytes()
print('Verified app identity, version, and archive contents.')
PY
(cd downloads && shasum -a 256 -c HiFrame.zip.sha256)
