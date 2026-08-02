#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOWNLOAD_DIR="$PROJECT_ROOT/downloads"
ARCHIVE_PATH="$DOWNLOAD_DIR/SteadyFrame.zip"
CHECKSUM_PATH="$DOWNLOAD_DIR/SteadyFrame.zip.sha256"

if [[ "$DOWNLOAD_DIR" != "$PROJECT_ROOT/downloads" ]]; then
  print -u2 "Refusing to write to an unexpected download directory: $DOWNLOAD_DIR"
  exit 1
fi

"$PROJECT_ROOT/scripts/build-app.sh" release
mkdir -p "$DOWNLOAD_DIR"
rm -f "$ARCHIVE_PATH" "$CHECKSUM_PATH"
ditto -c -k --sequesterRsrc --keepParent \
  "$PROJECT_ROOT/dist/SteadyFrame.app" \
  "$ARCHIVE_PATH"

(
  cd "$DOWNLOAD_DIR"
  shasum -a 256 SteadyFrame.zip > SteadyFrame.zip.sha256
)

print "$ARCHIVE_PATH"
print "$CHECKSUM_PATH"
