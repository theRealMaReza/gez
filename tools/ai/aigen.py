#!/usr/bin/env python3
"""
Generate Packages/GezCore/Sources/GezCore/Resources/ai_goals1453.json from:
  - data/ai/goals_1453.txt
  - Packages/GezCore/Sources/GezCore/Resources/scenario1453.json

Validates every country tag, province name, goal type, target, date range,
priority, and unique goal ID. Produces byte-identical JSON on repeated runs.

Run from repo root:
    python3 tools/ai/aigen.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IN_PATH = ROOT / "data" / "ai" / "goals_1453.txt"
SCENARIO_PATH = ROOT / "Packages" / "GezCore" / "Sources" / "GezCore" / "Resources" / "scenario1453.json"
OUT_PATH = ROOT / "Packages" / "GezCore" / "Sources" / "GezCore" / "Resources" / "ai_goals1453.json"

VALID_TYPES = {
    "conquer_province",
    "defend_province",
    "ally_with",
    "vassalize",
    "keep_peace_with",
    "build_up",
}

BUILD_TARGETS = {"army", "economy"}
DATE_RE = re.compile(r"^(\d{4})-(\d{2})-(\d{2})$")


def parse_date(raw: str, line_no: int, field: str) -> tuple[dict[str, int], tuple[int, int, int]]:
    m = DATE_RE.match(raw)
    if not m:
        raise ValueError(f"Line {line_no}: invalid {field} '{raw}' (expected YYYY-MM-DD)")
    y, mo, d = int(m.group(1)), int(m.group(2)), int(m.group(3))
    if not (1400 <= y <= 1850 and 1 <= mo <= 12 and 1 <= d <= 31):
        raise ValueError(f"Line {line_no}: out-of-range {field} '{raw}'")
    return {"year": y, "month": mo, "day": d}, (y, mo, d)


def main() -> int:
    if not IN_PATH.exists():
        print(f"ERROR: Missing input file {IN_PATH}", file=sys.stderr)
        return 1
    if not SCENARIO_PATH.exists():
        print(f"ERROR: Missing scenario file {SCENARIO_PATH}", file=sys.stderr)
        return 1

    scenario = json.loads(SCENARIO_PATH.read_text(encoding="utf-8"))
    country_tags = {c["tag"] for c in scenario["countries"]}
    province_names = {p["name"] for p in scenario["provinces"]}
    province_count = len(scenario["provinces"])

    seen_ids: set[str] = set()
    goals: list[dict[str, object]] = []

    for line_no, raw_line in enumerate(IN_PATH.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) < 7 or len(parts) > 8:
            raise ValueError(
                f"Line {line_no}: expected 7 or 8 pipe-separated fields, got {len(parts)}: {raw_line}"
            )
        country, gid, gtype, target, earliest_raw, give_up_raw, prio_raw = parts[:7]
        note = parts[7] if len(parts) == 8 else ""

        if country not in country_tags:
            raise ValueError(f"Line {line_no}: unknown country tag '{country}'")
        if not gid or not re.match(r"^[a-z0-9_]+$", gid):
            raise ValueError(f"Line {line_no}: invalid goal id '{gid}' (use lowercase alphanumeric + _)")
        if gid in seen_ids:
            raise ValueError(f"Line {line_no}: duplicate goal id '{gid}'")
        seen_ids.add(gid)

        if gtype not in VALID_TYPES:
            raise ValueError(f"Line {line_no}: invalid goal type '{gtype}'")

        if gtype in ("conquer_province", "defend_province"):
            if target not in province_names:
                raise ValueError(f"Line {line_no}: unknown province '{target}' for {gtype}")
        elif gtype in ("ally_with", "vassalize", "keep_peace_with"):
            if target not in country_tags:
                raise ValueError(f"Line {line_no}: unknown target tag '{target}' for {gtype}")
            if target == country:
                raise ValueError(f"Line {line_no}: country '{country}' cannot target itself for {gtype}")
        elif gtype == "build_up":
            if target not in BUILD_TARGETS:
                raise ValueError(f"Line {line_no}: build_up target must be 'army' or 'economy', got '{target}'")

        earliest_obj, earliest_tup = parse_date(earliest_raw, line_no, "earliest_date")
        give_up_obj, give_up_tup = parse_date(give_up_raw, line_no, "give_up_date")
        if earliest_tup > give_up_tup:
            raise ValueError(f"Line {line_no}: earliest_date {earliest_raw} > give_up_date {give_up_raw}")

        try:
            priority = int(prio_raw)
        except ValueError as exc:
            raise ValueError(f"Line {line_no}: priority must be integer, got '{prio_raw}'") from exc
        if not (1 <= priority <= 100):
            raise ValueError(f"Line {line_no}: priority {priority} out of 1..100")

        goals.append(
            {
                "id": gid,
                "country": country,
                "type": gtype,
                "target": target,
                "earliestDate": earliest_obj,
                "giveUpDate": give_up_obj,
                "priority": priority,
                "note": note,
            }
        )

    payload = {
        "provinceCount": province_count,
        "goals": goals,
    }
    OUT_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    countries_covered = len({g["country"] for g in goals})
    print(f"Generated {OUT_PATH.relative_to(ROOT)}: {len(goals)} goals across {countries_covered} countries.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as err:
        print(f"ERROR: {err}", file=sys.stderr)
        raise SystemExit(1)
