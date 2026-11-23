#!/usr/bin/env python3
"""
Generate Packages/GezCore/Sources/GezCore/Resources/events1453.json from:
  - data/events/*.txt
  - Packages/GezCore/Sources/GezCore/Resources/scenario1453.json
  - Packages/GezCore/Sources/GezCore/Resources/characters1453.json
  - Packages/GezCore/Sources/GezCore/Resources/government1453.json
  - Packages/GezCore/Sources/GezCore/Resources/military1453.json
  - Packages/GezCore/Sources/GezCore/Resources/technology1453.json

Validates every tag, province, character, trait, estate, modifier, unit,
institution, condition, and effect. Exits with a clear message on mistakes and
produces byte-identical output for the same input.

Run from repo root:
    python3 tools/events/eventgen.py
"""

from __future__ import annotations
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "data" / "events"
RES_DIR = ROOT / "Packages" / "GezCore" / "Sources" / "GezCore" / "Resources"
OUT_PATH = RES_DIR / "events1453.json"

VALID_CATEGORIES = {
    "historical",
    "dynastic",
    "religious",
    "military",
    "diplomatic",
    "internal",
    "calamity",
}

sys.path.insert(0, str(ROOT / "tools"))
from faiths import RELIGIONS as VALID_RELIGIONS, FAMILIES  # noqa: E402

RELIGION_ALIASES = {"tengrist": "tengri"}

VALID_RELIGION_FAMILIES = set(FAMILIES)

VALID_GOVERNMENTS = {"monarchy", "republic", "steppeHorde", "theocracy", "tribal"}

VALID_SKILLS = {"diplomacy", "martial", "stewardship", "intrigue", "learning"}

VALID_TECH_TRACKS = {"administrative", "diplomatic", "military"}

VALID_CBS = {
    "reconquest",
    "claim",
    "holyWar",
    "subjugation",
    "tribute",
    "succession",
    "coalition",
    "noCB",
}

VALID_MODIFIERS = {
    "tax",
    "trade",
    "build_cost",
    "interest",
    "learning",
    "reform_progress",
    "stability_cost",
    "vassal_keep",
    "vassal_opinion",
    "crown_power",
    "mood_nobles",
    "mood_clergy",
    "mood_burghers",
    "mood_peasants",
    "mood_other_faith",
    "tax_nobles",
    "tax_clergy",
    "tax_burghers",
    "tax_peasants",
    "inflation_decay",
    "no_debase",
    "manpower",
    "levy_size",
    "army_quality",
    "fort_defence",
    "accepted_cultures",
}

VALID_SAFAVIYYA_PHASES = {"dormant", "growing", "militant", "triumphant"}

ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")
DATE_RE = re.compile(r"^(\d{4})-(\d{2})-(\d{2})$")
MONTH_DAYS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]


class ReferenceData:
    def __init__(self) -> None:
        sc = json.loads((RES_DIR / "scenario1453.json").read_text(encoding="utf-8"))
        ch = json.loads((RES_DIR / "characters1453.json").read_text(encoding="utf-8"))
        gov = json.loads((RES_DIR / "government1453.json").read_text(encoding="utf-8"))
        mil = json.loads((RES_DIR / "military1453.json").read_text(encoding="utf-8"))
        tech = json.loads((RES_DIR / "technology1453.json").read_text(encoding="utf-8"))

        self.tags: set[str] = {c["tag"] for c in sc["countries"]}
        self.regions: set[str] = set(sc["regions"])
        self.cultures: set[str] = {c["id"] for c in sc["cultures"]}
        self.culture_families: set[str] = {c["family"] for c in sc["cultures"]}
        self.prov_index_by_name: dict[str, list[int]] = {}
        for idx, p in enumerate(sc["provinces"]):
            self.prov_index_by_name.setdefault(p["name"], []).append(idx)

        self.characters: set[str] = {c["id"] for c in ch["characters"]}
        self.traits: set[str] = {t["key"] for t in ch["traits"]}
        self.estates: set[str] = {e["key"] for e in gov["estates"]}
        self.units: set[str] = {u["key"] for u in mil["units"]}
        self.institutions: set[str] = {i["key"] for i in tech["institutions"]}

    def resolve_province(self, name: str, ctx: str) -> int:
        matches = self.prov_index_by_name.get(name, [])
        if len(matches) != 1:
            raise SystemExit(
                f"{ctx}: unknown or ambiguous province '{name}' (matches={len(matches)})"
            )
        return matches[0]


def parse_date(text: str, ctx: str) -> dict[str, int]:
    m = DATE_RE.match(text.strip())
    if not m:
        raise SystemExit(f"{ctx}: invalid date '{text}', expected YYYY-MM-DD")
    y, mo, d = int(m.group(1)), int(m.group(2)), int(m.group(3))
    if not (1400 <= y <= 1900):
        raise SystemExit(f"{ctx}: year {y} out of range (1400..1900)")
    if not (1 <= mo <= 12):
        raise SystemExit(f"{ctx}: month {mo} out of range")
    if not (1 <= d <= MONTH_DAYS[mo - 1]):
        raise SystemExit(f"{ctx}: day {d} out of range for month {mo}")
    return {"year": y, "month": mo, "day": d}


def date_tuple(d: dict[str, int]) -> tuple[int, int, int]:
    return (d["year"], d["month"], d["day"])


def parse_bool(val: str, ctx: str) -> bool:
    low = val.strip().lower()
    if low == "true":
        return True
    if low == "false":
        return False
    raise SystemExit(f"{ctx}: expected true/false, got '{val}'")


def parse_int(val: str, ctx: str) -> int:
    try:
        return int(val.strip())
    except ValueError as exc:
        raise SystemExit(f"{ctx}: expected integer, got '{val}'") from exc


def parse_float(val: str, ctx: str) -> float:
    try:
        return float(val.strip())
    except ValueError as exc:
        raise SystemExit(f"{ctx}: expected number, got '{val}'") from exc


def norm_religion(val: str, ctx: str) -> str:
    r = val.strip()
    if r not in VALID_RELIGIONS:
        raise SystemExit(f"{ctx}: unknown religion '{r}'")
    return RELIGION_ALIASES.get(r, r)


def validate_condition(key: str, val: str, ref: ReferenceData, ctx: str) -> dict:
    v = val.strip()
    if key in ("tag", "not_tag", "exists", "not_exists", "at_war_with", "is_vassal_of"):
        if v not in ref.tags:
            raise SystemExit(f"{ctx}: unknown country tag '{v}'")
        return {"kind": key, "str": v}

    if key in ("owns", "not_owns", "controls"):
        pidx = ref.resolve_province(v, ctx)
        return {"kind": key, "str": v, "int": pidx}

    if key == "province_owner":
        if ":" not in v:
            raise SystemExit(f"{ctx}: province_owner expects 'Province:TAG'")
        pname, tag = [x.strip() for x in v.split(":", 1)]
        pidx = ref.resolve_province(pname, ctx)
        if tag not in ref.tags:
            raise SystemExit(f"{ctx}: unknown country tag '{tag}'")
        return {"kind": key, "str": tag, "int": pidx}

    if key == "province_religion":
        if ":" not in v:
            raise SystemExit(f"{ctx}: province_religion expects 'Province:religion'")
        pname, rel = [x.strip() for x in v.split(":", 1)]
        pidx = ref.resolve_province(pname, ctx)
        rel = norm_religion(rel, ctx)
        return {"kind": key, "str": rel, "int": pidx}

    if key in ("at_war", "is_subject", "is_coastal", "reformation_started"):
        b = parse_bool(v, ctx)
        return {"kind": key, "bool": b}

    if key in ("religion", "not_religion"):
        return {"kind": key, "str": norm_religion(v, ctx)}

    if key == "religion_family":
        if v not in VALID_RELIGION_FAMILIES:
            raise SystemExit(f"{ctx}: unknown religion_family '{v}'")
        return {"kind": key, "str": v}

    if key == "culture":
        if v not in ref.cultures:
            raise SystemExit(f"{ctx}: unknown culture '{v}'")
        return {"kind": key, "str": v}

    if key == "culture_family":
        if v not in ref.culture_families:
            raise SystemExit(f"{ctx}: unknown culture_family '{v}'")
        return {"kind": key, "str": v}

    if key == "government":
        if v not in VALID_GOVERNMENTS:
            raise SystemExit(f"{ctx}: unknown government '{v}'")
        return {"kind": key, "str": v}

    if key == "capital_region":
        if v not in ref.regions:
            raise SystemExit(f"{ctx}: unknown region '{v}'")
        return {"kind": key, "str": v}

    if key in (
        "adm_tech",
        "dip_tech",
        "mil_tech",
        "stability_min",
        "stability_max",
        "development_min",
        "provinces_min",
        "year_min",
        "year_max",
    ):
        n = parse_int(v, ctx)
        return {"kind": key, "int": n}

    if key in ("treasury_min", "treasury_max"):
        num = parse_float(v, ctx)
        return {"kind": key, "num": num}

    if key in ("institution_present", "institution_spawned", "institution_embraced"):
        if v not in ref.institutions:
            raise SystemExit(f"{ctx}: unknown institution '{v}'")
        return {"kind": key, "str": v}

    if key in ("ruler_alive", "not_ruler_alive", "character_alive"):
        if v not in ref.characters:
            raise SystemExit(f"{ctx}: unknown character id '{v}'")
        return {"kind": key, "str": v}

    if key == "ruler_trait":
        if v not in ref.traits:
            raise SystemExit(f"{ctx}: unknown trait '{v}'")
        return {"kind": key, "str": v}

    if key == "ruler_skill_min":
        if ":" not in v:
            raise SystemExit(f"{ctx}: ruler_skill_min expects 'skill:min'")
        sk, n_s = [x.strip() for x in v.split(":", 1)]
        if sk not in VALID_SKILLS:
            raise SystemExit(f"{ctx}: unknown skill '{sk}'")
        n = parse_int(n_s, ctx)
        return {"kind": key, "str": sk, "int": n}

    if key in ("has_flag", "not_flag", "global_flag", "not_global_flag"):
        if not ID_RE.match(v):
            raise SystemExit(f"{ctx}: invalid flag name '{v}' (lowercase snake_case)")
        return {"kind": key, "str": v}

    if key == "safaviyya_phase":
        if v not in VALID_SAFAVIYYA_PHASES:
            raise SystemExit(f"{ctx}: unknown safaviyya_phase '{v}'")
        return {"kind": key, "str": v}

    raise SystemExit(f"{ctx}: unknown condition '{key}'")


def parse_prov_target(target: str, ref: ReferenceData, ctx: str) -> tuple[str, int]:
    t = target.strip()
    if t in ("capital", "all", "context"):
        return t, -1
    pidx = ref.resolve_province(t, ctx)
    return "province", pidx


def validate_effect(key: str, val: str, ref: ReferenceData, ctx: str) -> dict:
    v = val.strip()
    if key in ("ducats", "months_income", "prestige", "manpower", "sailors"):
        return {"kind": key, "num": parse_float(v, ctx)}

    if key == "stability":
        return {"kind": key, "int": parse_int(v, ctx)}

    if key == "estate_loyalty":
        if ":" not in v:
            raise SystemExit(f"{ctx}: estate_loyalty expects 'estate:delta'")
        est, d_s = [x.strip() for x in v.split(":", 1)]
        if est not in ref.estates:
            raise SystemExit(f"{ctx}: unknown estate '{est}'")
        return {"kind": key, "str": est, "num": parse_float(d_s, ctx)}

    if key == "unrest":
        if ":" not in v:
            raise SystemExit(f"{ctx}: unrest expects 'target:delta' (target=capital|all|Province)")
        tgt, d_s = [x.strip() for x in v.split(":", 1)]
        t_kind, pidx = parse_prov_target(tgt, ref, ctx)
        return {"kind": key, "target": t_kind, "int": pidx, "num": parse_float(d_s, ctx)}

    if key == "pops_convert":
        parts = [x.strip() for x in v.split(":")]
        if len(parts) != 3 or "->" not in parts[1]:
            raise SystemExit(f"{ctx}: pops_convert expects 'target:from->to:fraction'")
        tgt, conv, frac_s = parts
        t_kind, pidx = parse_prov_target(tgt, ref, ctx)
        f_rel, t_rel = [x.strip() for x in conv.split("->", 1)]
        if f_rel != "*":
            f_rel = norm_religion(f_rel, ctx)
        t_rel = norm_religion(t_rel, ctx)
        frac = parse_float(frac_s, ctx)
        if not (0.0 < frac <= 1.0):
            raise SystemExit(f"{ctx}: pops_convert fraction must be in (0, 1], got {frac}")
        return {
            "kind": key,
            "target": t_kind,
            "int": pidx,
            "str": f_rel,
            "str2": t_rel,
            "num": frac,
        }

    if key in ("add_claim", "add_core"):
        pidx = ref.resolve_province(v, ctx)
        return {"kind": key, "str": v, "int": pidx}

    if key == "add_cb":
        parts = [x.strip() for x in v.split(":")]
        if len(parts) not in (2, 3):
            raise SystemExit(f"{ctx}: add_cb expects 'TAG:cb_kind[:months]'")
        tag, cb = parts[0], parts[1]
        months = parse_int(parts[2], ctx) if len(parts) == 3 else 60
        if tag not in ref.tags:
            raise SystemExit(f"{ctx}: unknown country tag '{tag}'")
        if cb not in VALID_CBS:
            raise SystemExit(f"{ctx}: unknown CB '{cb}'")
        if months <= 0:
            raise SystemExit(f"{ctx}: add_cb months must be positive")
        return {"kind": key, "str": tag, "str2": cb, "int": months}

    if key == "declare_war":
        parts = [x.strip() for x in v.split(":")]
        if len(parts) != 2:
            raise SystemExit(f"{ctx}: declare_war expects 'TAG:cb_kind'")
        tag, cb = parts
        if tag not in ref.tags:
            raise SystemExit(f"{ctx}: unknown country tag '{tag}'")
        if cb not in VALID_CBS:
            raise SystemExit(f"{ctx}: unknown CB '{cb}'")
        return {"kind": key, "str": tag, "str2": cb}

    if key == "spawn_units":
        parts = [x.strip() for x in v.split(":")]
        if len(parts) != 3:
            raise SystemExit(f"{ctx}: spawn_units expects 'target:unit_key:count'")
        tgt, unit, cnt_s = parts
        if tgt == "all":
            raise SystemExit(f"{ctx}: spawn_units target cannot be 'all'")
        t_kind, pidx = parse_prov_target(tgt, ref, ctx)
        if unit not in ref.units:
            raise SystemExit(f"{ctx}: unknown unit '{unit}'")
        cnt = parse_int(cnt_s, ctx)
        if not (1 <= cnt <= 20):
            raise SystemExit(f"{ctx}: spawn_units count {cnt} must be 1..20")
        return {"kind": key, "target": t_kind, "int": pidx, "str": unit, "int2": cnt}

    if key in ("set_flag", "clear_flag", "set_global_flag", "clear_global_flag"):
        if not ID_RE.match(v):
            raise SystemExit(f"{ctx}: invalid flag name '{v}'")
        return {"kind": key, "str": v}

    if key == "add_modifier":
        parts = [x.strip() for x in v.split(":")]
        if len(parts) != 4:
            raise SystemExit(f"{ctx}: add_modifier expects 'key:Name:months:mod=val,mod=val'")
        mkey, mname, months_s, stats_s = parts
        if not ID_RE.match(mkey):
            raise SystemExit(f"{ctx}: invalid modifier key '{mkey}'")
        if not mname:
            raise SystemExit(f"{ctx}: modifier needs a display name")
        months = parse_int(months_s, ctx)
        if months <= 0:
            raise SystemExit(f"{ctx}: modifier months must be positive")
        stats: dict[str, float] = {}
        for item in stats_s.split(","):
            item = item.strip()
            if not item:
                continue
            if "=" not in item:
                raise SystemExit(f"{ctx}: modifier stat expects 'key=val', got '{item}'")
            sk, sv = [x.strip() for x in item.split("=", 1)]
            if sk not in VALID_MODIFIERS:
                raise SystemExit(f"{ctx}: unknown modifier stat '{sk}'")
            stats[sk] = parse_float(sv, ctx)
        if not stats:
            raise SystemExit(f"{ctx}: modifier needs at least one stat")
        return {
            "kind": key,
            "str": mkey,
            "str2": mname,
            "int": months,
            "mods": {k: stats[k] for k in sorted(stats)},
        }

    if key in ("change_opinion", "change_opinion_both"):
        if ":" not in v:
            raise SystemExit(f"{ctx}: {key} expects 'TAG:delta'")
        tag, d_s = [x.strip() for x in v.split(":", 1)]
        if tag not in ref.tags:
            raise SystemExit(f"{ctx}: unknown country tag '{tag}'")
        return {"kind": key, "str": tag, "int": parse_int(d_s, ctx)}

    if key == "change_religion":
        return {"kind": key, "str": norm_religion(v, ctx)}

    if key == "accept_culture":
        if v not in ref.cultures:
            raise SystemExit(f"{ctx}: unknown culture '{v}'")
        return {"kind": key, "str": v}

    if key == "tech_progress":
        if ":" not in v:
            raise SystemExit(f"{ctx}: tech_progress expects 'track:amount'")
        tr, amt_s = [x.strip() for x in v.split(":", 1)]
        if tr not in VALID_TECH_TRACKS:
            raise SystemExit(f"{ctx}: unknown tech track '{tr}'")
        return {"kind": key, "str": tr, "num": parse_float(amt_s, ctx)}

    if key == "ruler_skill":
        if ":" not in v:
            raise SystemExit(f"{ctx}: ruler_skill expects 'skill:delta'")
        sk, d_s = [x.strip() for x in v.split(":", 1)]
        if sk not in VALID_SKILLS:
            raise SystemExit(f"{ctx}: unknown skill '{sk}'")
        return {"kind": key, "str": sk, "int": parse_int(d_s, ctx)}

    if key == "add_ruler_trait":
        if v not in ref.traits:
            raise SystemExit(f"{ctx}: unknown trait '{v}'")
        return {"kind": key, "str": v}

    if key == "kill_character":
        if v not in ("ruler", "heir") and v not in ref.characters:
            raise SystemExit(f"{ctx}: unknown character '{v}' (expected char id, 'ruler', or 'heir')")
        return {"kind": key, "str": v}

    if key == "add_vassal_favour":
        return {"kind": key, "int": parse_int(v, ctx)}

    if key in ("province_dev", "province_fort"):
        if ":" not in v:
            raise SystemExit(f"{ctx}: {key} expects 'target:delta'")
        tgt, d_s = [x.strip() for x in v.split(":", 1)]
        if tgt == "all":
            raise SystemExit(f"{ctx}: {key} target cannot be 'all'")
        t_kind, pidx = parse_prov_target(tgt, ref, ctx)
        return {"kind": key, "target": t_kind, "int": pidx, "int2": parse_int(d_s, ctx)}

    if key == "institution_spread":
        parts = [x.strip() for x in v.split(":")]
        if len(parts) != 3:
            raise SystemExit(f"{ctx}: institution_spread expects 'target:inst_key:amount'")
        tgt, ikey, amt_s = parts
        if tgt == "all":
            raise SystemExit(f"{ctx}: institution_spread target cannot be 'all'")
        t_kind, pidx = parse_prov_target(tgt, ref, ctx)
        if ikey not in ref.institutions:
            raise SystemExit(f"{ctx}: unknown institution '{ikey}'")
        return {"kind": key, "target": t_kind, "int": pidx, "str": ikey, "num": parse_float(amt_s, ctx)}

    if key == "spawn_reformation":
        if ":" not in v:
            raise SystemExit(f"{ctx}: spawn_reformation expects 'target:protestant|reformed'")
        tgt, rel = [x.strip() for x in v.split(":", 1)]
        if tgt == "all":
            raise SystemExit(f"{ctx}: spawn_reformation target cannot be 'all'")
        t_kind, pidx = parse_prov_target(tgt, ref, ctx)
        if rel not in ("protestant", "reformed"):
            raise SystemExit(f"{ctx}: spawn_reformation religion must be protestant or reformed")
        return {"kind": key, "target": t_kind, "int": pidx, "str": rel}

    if key == "advance_safaviyya":
        if v not in ("growing", "militant", "triumphant"):
            raise SystemExit(f"{ctx}: advance_safaviyya expects growing|militant|triumphant")
        return {"kind": key, "str": v}

    if key == "cede_province":
        if ":" not in v:
            raise SystemExit(f"{ctx}: cede_province expects 'Province:TAG'")
        pname, tag = [x.strip() for x in v.split(":", 1)]
        pidx = ref.resolve_province(pname, ctx)
        if tag not in ref.tags:
            raise SystemExit(f"{ctx}: unknown country tag '{tag}'")
        return {"kind": key, "str": tag, "int": pidx}

    raise SystemExit(f"{ctx}: unknown effect '{key}'")


def parse_ai_mod(val: str, ref: ReferenceData, ctx: str) -> dict:
    if "->" not in val or "=" not in val:
        raise SystemExit(f"{ctx}: ai_mod expects 'cond_key=cond_val -> *mult|+add'")
    left, right = [x.strip() for x in val.split("->", 1)]
    ck, cv = [x.strip() for x in left.split("=", 1)]
    cond = validate_condition(ck, cv, ref, ctx)
    if right.startswith("*"):
        op = "mul"
        num = parse_float(right[1:], ctx)
        if num < 0:
            raise SystemExit(f"{ctx}: ai_mod multiplier cannot be negative")
    elif right.startswith("+") or right.startswith("-"):
        op = "add"
        num = parse_float(right, ctx)
    else:
        raise SystemExit(f"{ctx}: ai_mod right side must start with '*', '+', or '-'")
    return {"condition": cond, "op": op, "value": num}


def parse_mtth_mod(val: str, ref: ReferenceData, ctx: str) -> dict:
    if "->" not in val or "=" not in val:
        raise SystemExit(f"{ctx}: mtth_mod expects 'cond_key=cond_val -> *mult'")
    left, right = [x.strip() for x in val.split("->", 1)]
    ck, cv = [x.strip() for x in left.split("=", 1)]
    cond = validate_condition(ck, cv, ref, ctx)
    if not right.startswith("*"):
        raise SystemExit(f"{ctx}: mtth_mod multiplier must start with '*'")
    num = parse_float(right[1:], ctx)
    if num <= 0:
        raise SystemExit(f"{ctx}: mtth_mod multiplier must be positive")
    return {"condition": cond, "factor": num}


def parse_file(path: Path, ref: ReferenceData) -> list[dict]:
    events: list[dict] = []
    cur: dict | None = None
    cur_opt: dict | None = None
    section: str | None = None  # "trigger" | "option" | "effect"

    def finish_option() -> None:
        nonlocal cur_opt
        if cur is None or cur_opt is None:
            return
        if not cur_opt["label"]:
            raise SystemExit(f"{cur_opt['_ctx']}: option is missing 'label'")
        if cur_opt["aiWeight"] is None:
            raise SystemExit(f"{cur_opt['_ctx']}: option '{cur_opt['label']}' is missing 'ai_weight'")
        cur_opt.pop("_ctx", None)
        cur["options"].append(cur_opt)
        cur_opt = None

    def finish_event() -> None:
        nonlocal cur, section
        if cur is None:
            return
        finish_option()
        ectx = cur["_ctx"]
        for req in ("title", "text", "category"):
            if not cur.get(req):
                raise SystemExit(f"{ectx}: event '{cur['id']}' missing '{req}'")
        if not (2 <= len(cur["options"]) <= 4):
            raise SystemExit(
                f"{ectx}: event '{cur['id']}' must have 2..4 options (got {len(cur['options'])})"
            )
        if not cur["triggeredOnly"]:
            if cur["dateFrom"] is None or cur["dateTo"] is None:
                raise SystemExit(
                    f"{ectx}: non-triggered event '{cur['id']}' requires date_from and date_to"
                )
            if date_tuple(cur["dateFrom"]) > date_tuple(cur["dateTo"]):
                raise SystemExit(f"{ectx}: date_from > date_to in '{cur['id']}'")
            if cur["exactDate"] is not None:
                if not (
                    date_tuple(cur["dateFrom"])
                    <= date_tuple(cur["exactDate"])
                    <= date_tuple(cur["dateTo"])
                ):
                    raise SystemExit(
                        f"{ectx}: exact_date outside [date_from, date_to] in '{cur['id']}'"
                    )
        cur.pop("_ctx", None)
        events.append(cur)
        cur = None
        section = None

    lines = path.read_text(encoding="utf-8").splitlines()
    for lineno, raw in enumerate(lines, 1):
        stripped = raw.split("#", 1)[0].strip()
        if not stripped:
            continue
        ctx = f"{path.name}:{lineno}"

        if stripped.startswith("event "):
            finish_event()
            eid = stripped[6:].strip()
            if not ID_RE.match(eid):
                raise SystemExit(f"{ctx}: invalid event id '{eid}'")
            cur = {
                "_ctx": ctx,
                "id": eid,
                "title": "",
                "text": "",
                "category": "historical",
                "countries": [],
                "dateFrom": None,
                "dateTo": None,
                "exactDate": None,
                "mtth": 12.0,
                "mtthModifiers": [],
                "fireOnce": True,
                "perCountry": False,
                "triggeredOnly": False,
                "major": False,
                "trigger": [],
                "options": [],
            }
            section = "header"
            continue

        if cur is None:
            raise SystemExit(f"{ctx}: unexpected content before first 'event <id>'")

        if stripped == "trigger:":
            finish_option()
            section = "trigger"
            continue
        if stripped == "option:":
            finish_option()
            cur_opt = {
                "_ctx": ctx,
                "label": "",
                "aiWeight": None,
                "aiModifiers": [],
                "effects": [],
            }
            section = "option"
            continue
        if stripped == "effect:":
            if cur_opt is None:
                raise SystemExit(f"{ctx}: 'effect:' outside an 'option:' block")
            section = "effect"
            continue

        if "=" not in stripped:
            raise SystemExit(f"{ctx}: expected 'key = value', got '{stripped}'")
        k, v = [x.strip() for x in stripped.split("=", 1)]

        if section == "header":
            if k == "title":
                cur["title"] = v
            elif k == "text":
                cur["text"] = v
            elif k == "category":
                if v not in VALID_CATEGORIES:
                    raise SystemExit(f"{ctx}: unknown category '{v}'")
                cur["category"] = v
            elif k == "countries":
                tags = [t.strip() for t in v.split(",") if t.strip()]
                for t in tags:
                    if t not in ref.tags:
                        raise SystemExit(f"{ctx}: unknown country tag '{t}'")
                cur["countries"] = tags
            elif k == "date_from":
                cur["dateFrom"] = parse_date(v, ctx)
            elif k == "date_to":
                cur["dateTo"] = parse_date(v, ctx)
            elif k == "exact_date":
                cur["exactDate"] = parse_date(v, ctx)
            elif k == "mtth":
                mtth = parse_float(v, ctx)
                if mtth < 0:
                    raise SystemExit(f"{ctx}: mtth must be >= 0")
                cur["mtth"] = mtth
            elif k == "mtth_mod":
                cur["mtthModifiers"].append(parse_mtth_mod(v, ref, ctx))
            elif k == "fire_once":
                cur["fireOnce"] = parse_bool(v, ctx)
            elif k == "per_country":
                cur["perCountry"] = parse_bool(v, ctx)
            elif k == "triggered_only":
                cur["triggeredOnly"] = parse_bool(v, ctx)
            elif k == "major":
                cur["major"] = parse_bool(v, ctx)
            else:
                raise SystemExit(f"{ctx}: unknown header field '{k}'")
        elif section == "trigger":
            cur["trigger"].append(validate_condition(k, v, ref, ctx))
        elif section == "option":
            assert cur_opt is not None
            if k == "label":
                cur_opt["label"] = v
            elif k == "ai_weight":
                w = parse_float(v, ctx)
                if w < 0:
                    raise SystemExit(f"{ctx}: ai_weight must be >= 0")
                cur_opt["aiWeight"] = w
            elif k == "ai_mod":
                cur_opt["aiModifiers"].append(parse_ai_mod(v, ref, ctx))
            else:
                raise SystemExit(f"{ctx}: unknown option field '{k}'")
        elif section == "effect":
            assert cur_opt is not None
            cur_opt["effects"].append(validate_effect(k, v, ref, ctx))

    finish_event()
    return events


def main() -> None:
    if not DATA_DIR.exists():
        raise SystemExit(f"Missing events directory: {DATA_DIR}")
    files = sorted(DATA_DIR.glob("*.txt"))
    if not files:
        raise SystemExit(f"No .txt event files found in {DATA_DIR}")

    ref = ReferenceData()
    all_events: list[dict] = []
    seen_ids: set[str] = set()
    for f in files:
        for ev in parse_file(f, ref):
            if ev["id"] in seen_ids:
                raise SystemExit(f"{f.name}: duplicate event id '{ev['id']}'")
            seen_ids.add(ev["id"])
            all_events.append(ev)

    payload = {
        "provinceCount": sum(len(v) for v in ref.prov_index_by_name.values()),
        "events": all_events,
    }
    OUT_PATH.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {OUT_PATH.relative_to(ROOT)} ({len(all_events)} events from {len(files)} files)")


if __name__ == "__main__":
    main()
