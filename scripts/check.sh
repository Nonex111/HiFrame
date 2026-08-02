#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

swift test --package-path "$PROJECT_ROOT"
"$PROJECT_ROOT/scripts/package-download.sh"
"$PROJECT_ROOT/dist/SteadyFrame.app/Contents/MacOS/SteadyFrame" --diagnose 120 10
