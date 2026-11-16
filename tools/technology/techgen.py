#!/usr/bin/env python3
"""
Generate Packages/GezCore/Sources/GezCore/Resources/technology1453.json from:
  - data/technology/tracks.txt
  - data/technology/starting_levels.txt
  - data/technology/institutions.txt
  - Packages/GezCore/Sources/GezCore/Resources/scenario1453.json

Validates all inputs and writes deterministic, reproducible JSON.
Run from repo root:
    python3 tools/technology/techgen.py
"""

from __future__ import annotations
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "technology"
RES = ROOT / "Packages" / "GezCore" / "Sources" / "GezCore" / "Resources"
SCENARIO = RES / "scenario1453.json"
OUT = RES / "technology1453.json"

TRACKS = ("administrative", "diplomatic", "military")
VALID_EFFECT_KEYS = {
    "tax_eff",
    "prod_eff",
    "trade_eff",
    "trade_range",
    "admin_eff",
    "max_building",
    "max_fort",
    "tactics",
    "land_morale",
    "relations",
    "accepted_cultures",
    "reform_progress",
}
VALID_GOVS = {"monarchy", "republic", "steppeHorde", "theocracy", "tribal"}
VALID_PARAMS = {
    "base_cost",
    "neighbour_bonus_per_level",
    "neighbour_bonus_cap",
    "ahead_of_time_per_year",
    "ahead_of_time_cap",
    "institution_penalty_per_year",
    "institution_penalty_cap",
    "embraced_research_bonus",
    "embrace_min_dev_share",
    "embrace_ducats_per_dev",
    "embrace_min_cost",
}


def rows(name: str):
    path = DATA / name
    if not path.exists():
        raise SystemExit(f"Missing input file: {path}")
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        yield lineno, [p.strip() for p in line.split("|")]


def parse_effects(cell: str, ctx: str) -> dict[str, float]:
    out: dict[str, float] = {}
    if not cell:
        return out
    for part in cell.split(","):
        part = part.strip()
        if not part:
            continue
        if "=" not in part:
            raise SystemExit(f"{ctx}: expected 'key=value' in effects, got '{part}'")
        k, v_s = [x.strip() for x in part.split("=", 1)]
        if k not in VALID_EFFECT_KEYS:
            raise SystemExit(f"{ctx}: unknown effect key '{k}'")
        try:
            v = float(v_s)
        except ValueError as exc:
            raise SystemExit(f"{ctx}: non-numeric effect value '{v_s}'") from exc
        out[k] = v
    return out


def parse_tracks() -> tuple[dict[str, float], dict[str, list[dict]]]:
    params: dict[str, float] = {}
    levels_by_track: dict[str, dict[int, dict]] = {t: {} for t in TRACKS}

    for lineno, cols in rows("tracks.txt"):
        ctx = f"tracks.txt:{lineno}"
        kind = cols[0]
        if kind == "param":
            if len(cols) != 3:
                raise SystemExit(f"{ctx}: expected 'param | key | value'")
            k, v_s = cols[1], cols[2]
            if k not in VALID_PARAMS:
                raise SystemExit(f"{ctx}: unknown param '{k}'")
            try:
                params[k] = float(v_s)
            except ValueError as exc:
                raise SystemExit(f"{ctx}: bad numeric param '{v_s}'") from exc
        elif kind == "level":
            if len(cols) != 7:
                raise SystemExit(
                    f"{ctx}: expected 'level | track | level | target_year | base_cost | effects | summary'"
                )
            track = cols[1]
            if track not in levels_by_track:
                raise SystemExit(f"{ctx}: unknown track '{track}'")
            try:
                lvl = int(cols[2])
                year = int(cols[3])
                cost = float(cols[4])
            except ValueError as exc:
                raise SystemExit(f"{ctx}: invalid number in level row") from exc
            if not (1 <= lvl <= 20):
                raise SystemExit(f"{ctx}: level {lvl} must be 1..20")
            if not (1350 <= year <= 1800):
                raise SystemExit(f"{ctx}: target_year {year} out of range")
            if cost <= 0:
                raise SystemExit(f"{ctx}: base_cost must be positive")
            if lvl in levels_by_track[track]:
                raise SystemExit(f"{ctx}: duplicate {track} level {lvl}")
            effects = parse_effects(cols[5], ctx)
            summary = cols[6]
            if not summary:
                raise SystemExit(f"{ctx}: level needs a summary")
            levels_by_track[track][lvl] = {
                "level": lvl,
                "targetYear": year,
                "baseCost": cost,
                "effects": effects,
                "summary": summary,
            }
        else:
            raise SystemExit(f"{ctx}: unknown row type '{kind}'")

    for k in VALID_PARAMS:
        if k not in params:
            raise SystemExit(f"tracks.txt: missing required param '{k}'")

    ordered_tracks: dict[str, list[dict]] = {}
    for t in TRACKS:
        lvl_map = levels_by_track[t]
        missing = [i for i in range(1, 21) if i not in lvl_map]
        if missing:
            raise SystemExit(f"tracks.txt: track '{t}' missing levels {missing}")
        ordered_tracks[t] = [lvl_map[i] for i in range(1, 21)]

    return params, ordered_tracks


def parse_starting_levels(known_regions: set[str], known_tags: set[str]) -> dict:
    regions: dict[str, list[int]] = {}
    gov_caps: dict[str, list[int]] = {}
    countries: dict[str, list[int]] = {}

    for lineno, cols in rows("starting_levels.txt"):
        ctx = f"starting_levels.txt:{lineno}"
        if len(cols) != 5:
            raise SystemExit(f"{ctx}: expected 5 fields, got {len(cols)}")
        kind, key = cols[0], cols[1]
        try:
            vals = [int(cols[2]), int(cols[3]), int(cols[4])]
        except ValueError as exc:
            raise SystemExit(f"{ctx}: tech levels must be integers") from exc
        if any(v < 1 or v > 20 for v in vals):
            raise SystemExit(f"{ctx}: starting tech levels must be in 1..20, got {vals}")

        if kind == "region":
            if key not in known_regions:
                raise SystemExit(f"{ctx}: unknown region '{key}'")
            if key in regions:
                raise SystemExit(f"{ctx}: duplicate region '{key}'")
            regions[key] = vals
        elif kind == "gov_cap":
            if key not in VALID_GOVS:
                raise SystemExit(f"{ctx}: unknown government '{key}'")
            if key in gov_caps:
                raise SystemExit(f"{ctx}: duplicate gov_cap '{key}'")
            gov_caps[key] = vals
        elif kind == "country":
            if key not in known_tags:
                raise SystemExit(f"{ctx}: unknown country tag '{key}'")
            if key in countries:
                raise SystemExit(f"{ctx}: duplicate country override '{key}'")
            countries[key] = vals
        else:
            raise SystemExit(f"{ctx}: unknown row type '{kind}'")

    missing_regions = sorted(known_regions - set(regions.keys()))
    if missing_regions:
        raise SystemExit(f"starting_levels.txt: missing regions: {missing_regions}")

    return {
        "regions": {r: regions[r] for r in sorted(regions)},
        "govCaps": {g: gov_caps[g] for g in sorted(gov_caps)},
        "countries": {t: countries[t] for t in sorted(countries)},
    }


def parse_institutions(known_regions: set[str], prov_by_name: dict[str, list[int]]) -> list[dict]:
    out: list[dict] = []
    seen: set[str] = set()

    for lineno, cols in rows("institutions.txt"):
        ctx = f"institutions.txt:{lineno}"
        if len(cols) != 9 or cols[0] != "institution":
            raise SystemExit(
                f"{ctx}: expected 'institution | key | Name | spawn_year | origin_rule | "
                f"spread_neighbour | spread_trade | spread_burgher | summary'"
            )
        _, key, name, year_s, origin_rule, sn_s, st_s, sb_s, summary = cols
        if not key or key in seen:
            raise SystemExit(f"{ctx}: missing or duplicate institution key '{key}'")
        seen.add(key)
        try:
            spawn_year = int(year_s)
            sn = float(sn_s)
            st = float(st_s)
            sb = float(sb_s)
        except ValueError as exc:
            raise SystemExit(f"{ctx}: invalid numeric field") from exc
        if not (1400 <= spawn_year <= 1800):
            raise SystemExit(f"{ctx}: spawn_year {spawn_year} out of range")
        if min(sn, st, sb) < 0 or max(sn, st, sb) > 1:
            raise SystemExit(f"{ctx}: spread rates must be in 0..1")

        origin: dict
        if origin_rule.startswith("region:"):
            reg = origin_rule.split(":", 1)[1].strip()
            if reg not in known_regions:
                raise SystemExit(f"{ctx}: unknown region '{reg}'")
            origin = {"kind": "region", "value": reg}
        elif origin_rule.startswith("province:"):
            pname = origin_rule.split(":", 1)[1].strip()
            matches = prov_by_name.get(pname, [])
            if len(matches) != 1:
                raise SystemExit(f"{ctx}: province '{pname}' matches {len(matches)} provinces")
            origin = {"kind": "province", "value": pname, "provinceIndex": matches[0]}
        elif origin_rule.startswith("dynamic:"):
            dkind = origin_rule.split(":", 1)[1].strip()
            if dkind not in {"richest_port_market", "top_workshops"}:
                raise SystemExit(f"{ctx}: unknown dynamic origin '{dkind}'")
            origin = {"kind": "dynamic", "value": dkind}
        else:
            raise SystemExit(f"{ctx}: unknown origin_rule '{origin_rule}'")

        if not name or not summary:
            raise SystemExit(f"{ctx}: institution needs name and summary")

        out.append({
            "key": key,
            "name": name,
            "spawnYear": spawn_year,
            "origin": origin,
            "spreadNeighbour": sn,
            "spreadTrade": st,
            "spreadBurgher": sb,
            "summary": summary,
        })

    if not out:
        raise SystemExit("institutions.txt: no institutions defined")
    return out


def main():
    scen = json.loads(SCENARIO.read_text(encoding="utf-8"))
    known_regions = set(scen["regions"])
    known_tags = {c["tag"] for c in scen["countries"]}
    prov_by_name: dict[str, list[int]] = {}
    for idx, p in enumerate(scen["provinces"]):
        prov_by_name.setdefault(p["name"], []).append(idx)

    params, tracks = parse_tracks()
    starting = parse_starting_levels(known_regions, known_tags)
    institutions = parse_institutions(known_regions, prov_by_name)

    payload = {
        "provinceCount": len(scen["provinces"]),
        "params": {k: params[k] for k in sorted(params)},
        "tracks": tracks,
        "startingLevels": starting,
        "institutions": institutions,
    }
    OUT.write_text(json.dumps(payload, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"techgen: {len(TRACKS)} tracks (20 levels each), "
        f"{len(starting['regions'])} regions, {len(starting['countries'])} overrides, "
        f"{len(institutions)} institutions -> {OUT.name}"
    )


if __name__ == "__main__":
    main()
