#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONDITION="${1:?condition name required}"
DURATION_SECONDS="${2:-180}"
RUN_DIRECTORY="${3:-$PROJECT_ROOT/ab-results/$(date +%Y%m%d-%H%M%S)-$CONDITION}"
KEEP_ALIVE="${4:-off}"
APP_BINARY="$PROJECT_ROOT/dist/HiFrame.app/Contents/MacOS/HiFrame"
METRICS_FILE="$RUN_DIRECTORY/metrics.csv"
SCENE_LOG="$RUN_DIRECTORY/scene.log"

mkdir -p "$RUN_DIRECTORY"

SCENE_ARGUMENTS=(--ab-scene "$DURATION_SECONDS")
if [[ "$KEEP_ALIVE" == "on" ]]; then
  SCENE_ARGUMENTS+=(--keep-alive)
fi

"$APP_BINARY" "${SCENE_ARGUMENTS[@]}" >"$SCENE_LOG" 2>&1 &
SCENE_PID=$!

cleanup() {
  if kill -0 "$SCENE_PID" 2>/dev/null; then
    kill "$SCENE_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

for _ in {1..20}; do
  if rg -q '"event":"ready"' "$SCENE_LOG" 2>/dev/null; then
    break
  fi
  sleep 0.25
done

if ! rg -q '"event":"ready"' "$SCENE_LOG" 2>/dev/null; then
  print -u2 "A/B scene failed to become ready"
  exit 1
fi

print 'timestamp,elapsed_seconds,system_power_in_mw_raw,system_load_mw_raw,gpu_device_percent,gpu_renderer_percent,process_cpu_percent,process_rss_kb,battery_percent,battery_temperature_c,virtual_temperature_c' >"$METRICS_FILE"

START_SECONDS=$SECONDS
while kill -0 "$SCENE_PID" 2>/dev/null; do
  ELAPSED=$((SECONDS - START_SECONDS))
  BATTERY_TEXT="$(ioreg -r -c AppleSmartBattery -l -w 0 2>/dev/null)"
  GPU_TEXT="$(ioreg -r -c IOAccelerator -l -w 0 2>/dev/null)"
  PROCESS_TEXT="$(ps -p "$SCENE_PID" -o %cpu=,rss= 2>/dev/null | xargs || true)"

  SYSTEM_POWER="$(print -r -- "$BATTERY_TEXT" | rg -o '"SystemPowerIn"=[0-9]+' | head -n 1 | cut -d= -f2 || true)"
  SYSTEM_LOAD="$(print -r -- "$BATTERY_TEXT" | rg -o '"SystemLoad"=[0-9]+' | head -n 1 | cut -d= -f2 || true)"
  BATTERY_PERCENT="$(print -r -- "$BATTERY_TEXT" | rg -o '"CurrentCapacity" = [0-9]+' | head -n 1 | awk '{print $3}' || true)"
  BATTERY_TEMP_RAW="$(print -r -- "$BATTERY_TEXT" | rg -o '"Temperature" = [0-9]+' | head -n 1 | awk '{print $3}' || true)"
  VIRTUAL_TEMP_RAW="$(print -r -- "$BATTERY_TEXT" | rg -o '"VirtualTemperature" = [0-9]+' | head -n 1 | awk '{print $3}' || true)"
  GPU_DEVICE="$(print -r -- "$GPU_TEXT" | rg -o '"Device Utilization %"=[0-9]+' | head -n 1 | cut -d= -f2 || true)"
  GPU_RENDERER="$(print -r -- "$GPU_TEXT" | rg -o '"Renderer Utilization %"=[0-9]+' | head -n 1 | cut -d= -f2 || true)"
  PROCESS_CPU="${PROCESS_TEXT%% *}"
  PROCESS_RSS="${PROCESS_TEXT##* }"

  BATTERY_TEMP="$(awk -v value="${BATTERY_TEMP_RAW:-0}" 'BEGIN { printf "%.2f", value / 100 }')"
  VIRTUAL_TEMP="$(awk -v value="${VIRTUAL_TEMP_RAW:-0}" 'BEGIN { printf "%.2f", value / 100 }')"

  print "$(date -Iseconds),$ELAPSED,${SYSTEM_POWER:-},${SYSTEM_LOAD:-},${GPU_DEVICE:-},${GPU_RENDERER:-},${PROCESS_CPU:-},${PROCESS_RSS:-},${BATTERY_PERCENT:-},$BATTERY_TEMP,$VIRTUAL_TEMP" >>"$METRICS_FILE"
  sleep 5
done

wait "$SCENE_PID"
trap - EXIT INT TERM
pmset -g therm >"$RUN_DIRECTORY/thermal.txt" 2>&1 || true
python3 "$PROJECT_ROOT/scripts/summarize-ab.py" "$METRICS_FILE" "$CONDITION" >"$RUN_DIRECTORY/summary.json"
print "$RUN_DIRECTORY"
