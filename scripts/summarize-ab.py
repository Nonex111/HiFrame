#!/usr/bin/env python3
import csv
import json
import statistics
import sys
from pathlib import Path


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    position = fraction * (len(ordered) - 1)
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    weight = position - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * weight


metrics_path = Path(sys.argv[1])
condition = sys.argv[2]
with metrics_path.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))

numeric_columns = [
    "system_power_in_mw_raw",
    "system_load_mw_raw",
    "gpu_device_percent",
    "gpu_renderer_percent",
    "process_cpu_percent",
    "process_rss_kb",
    "battery_percent",
    "battery_temperature_c",
    "virtual_temperature_c",
]

summary: dict[str, object] = {
    "condition": condition,
    "sampleCount": len(rows),
    "sampledDurationSeconds": float(rows[-1]["elapsed_seconds"]) if rows else 0,
    "metrics": {},
}

for column in numeric_columns:
    values = [float(row[column]) for row in rows if row.get(column)]
    if not values:
        continue
    summary["metrics"][column] = {
        "mean": statistics.fmean(values),
        "median": statistics.median(values),
        "p10": percentile(values, 0.1),
        "p90": percentile(values, 0.9),
        "minimum": min(values),
        "maximum": max(values),
    }

power = summary["metrics"].get("system_power_in_mw_raw")
if power and rows:
    duration_hours = float(rows[-1]["elapsed_seconds"]) / 3600
    summary["estimatedEnergyWhFromRawPower"] = power["mean"] / 1000 * duration_hours

print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
