#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
swift build --package-path "$PROJECT_ROOT" -c "$CONFIGURATION"
BINARY_PATH="$(swift build --package-path "$PROJECT_ROOT" -c "$CONFIGURATION" --show-bin-path)/HiFrame"
APP_PATH="$PROJECT_ROOT/dist/HiFrame.app"
CONTENTS_PATH="$APP_PATH/Contents"

if [[ "$APP_PATH" != "$PROJECT_ROOT/dist/HiFrame.app" ]]; then
  print -u2 "Refusing to replace an unexpected app path: $APP_PATH"
  exit 1
fi

rm -rf "$APP_PATH"
mkdir -p "$CONTENTS_PATH/MacOS" "$CONTENTS_PATH/Resources"
cp "$BINARY_PATH" "$CONTENTS_PATH/MacOS/HiFrame"
cp "$PROJECT_ROOT/Packaging/Info.plist" "$CONTENTS_PATH/Info.plist"
# Release jobs stamp the built bundle without changing the checked-in defaults.
if [[ -n "${HIFRAME_RELEASE_VERSION:-}" ]]; then
  python3 "$PROJECT_ROOT/scripts/stamp-release-version.py" \
    "$CONTENTS_PATH/Info.plist" "$HIFRAME_RELEASE_VERSION"
fi
cp "$PROJECT_ROOT/Packaging/SteadyFrame-v3.icns" "$CONTENTS_PATH/Resources/SteadyFrame-v3.icns"
cp -R "$PROJECT_ROOT/Packaging/Resources/." "$CONTENTS_PATH/Resources/"
codesign --force --deep --sign - "$APP_PATH"

print "$APP_PATH"
