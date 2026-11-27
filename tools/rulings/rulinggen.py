#!/usr/bin/env python3
"""
Generate Packages/GezCore/Sources/GezCore/Resources/rulings1453.json from:
  - data/rulings/systems/*.txt    (ruling systems: HRE, Shogunate, ...)
  - data/rulings/formables/*.txt  (formable nations)
and the generated scenario, character, government, military and technology
JSON (for validation, through tools/events/eventgen.py).

Run from the repo root, after govgen and before eventgen:
    python3 tools/rulings/rulinggen.py

Validates every tag, province, role, value, modifier, government, reform,
condition and effect, exits with a clear message on mistakes, and writes
byte-identical output for the same input. Format: docs/RULING_SYSTEMS.md.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SYSTEMS_DIR = ROOT / "data" / "rulings" / "systems"
FORMABLES_DIR = ROOT / "data" / "rulings" / "formables"
RES_DIR = ROOT / "Packages" / "GezCore" / "Sources" / "GezCore" / "Resources"
OUT_PATH = RES_DIR / "rulings1453.json"

sys.path.insert(0, str(ROOT / "tools" / "events"))
import eventgen  # noqa: E402

ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")
FORMABLE_RE = re.compile(r"^[A-Z][A-Z0-9_]{1,7}$")
NUM_RE = re.compile(r"^-?\d+(\.\d+)?$")
RANGE_RE = re.compile(r"^(-?\d+(?:\.\d+)?)\s*\.\.\s*(-?\d+(?:\.\d+)?)$")


def num(text: str, ctx: str) -> float:
    t = text.strip()
    if not NUM_RE.match(t):
        raise SystemExit(f"{ctx}: '{text}' is not a number")
    v = float(t)
    return int(v) if v.is_integer() else v


def tags_list(text: str, ref: eventgen.ReferenceData, ctx: str) -> list[str]:
    out: list[str] = []
    for t in [x.strip() for x in text.split(",") if x.strip()]:
        if t not in ref.tags:
            raise SystemExit(f"{ctx}: unknown country tag '{t}'")
        if t in out:
            raise SystemExit(f"{ctx}: '{t}' listed twice")
        out.append(t)
    return out


def mods(text: str, ctx: str) -> dict[str, float]:
    out: dict[str, float] = {}
    for part in [x.strip() for x in text.split(",") if x.strip()]:
        if "=" not in part:
            raise SystemExit(f"{ctx}: modifier '{part}' must be 'name=value'")
        k, v = [x.strip() for x in part.split("=", 1)]
        if k not in eventgen.VALID_MODIFIERS:
            raise SystemExit(f"{ctx}: unknown modifier '{k}'")
        out[k] = num(v, ctx)
    if not out:
        raise SystemExit(f"{ctx}: effect needs at least one modifier")
    return dict(sorted(out.items()))


def blocks(path: Path, head: str) -> list[tuple[str, list[tuple[int, str]]]]:
    """Splits a file into `head <id>` blocks of (line number, text) lines."""
    out: list[tuple[str, list[tuple[int, str]]]] = []
    for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if line.startswith(head + " "):
            out.append((line[len(head) + 1:].strip(), []))
            continue
        if not out:
            raise SystemExit(f"{path.name}:{n}: text before the first '{head}' line")
        out[-1][1].append((n, line))
    return out


# --- Ruling systems ---------------------------------------------------------

def parse_system(path: Path, key: str, lines, ref) -> dict:
    ctx0 = f"{path.name} system {key}"
    if not ID_RE.match(key):
        raise SystemExit(f"{ctx0}: system key must be lowercase snake_case")
    sy = {
        "key": key, "name": None, "leader": None, "roles": [], "values": [],
        "params": [], "provinces": [], "roleEffects": [],
        "roleNames": [], "valueNames": [], "countryValueNames": [],
    }
    declared_roles: list[str] = []
    for n, line in lines:
        ctx = f"{path.name}:{n}"
        text = line.strip()
        if text.startswith("effect "):
            # effect ROLE: mods      or   effect ROLE scaled VALUE/DIV: mods
            head, _, rest = text[len("effect "):].partition(":")
            if not rest.strip():
                raise SystemExit(f"{ctx}: effect expects 'effect role: name=value, ...'")
            words = head.split()
            entry = {"role": words[0] if words else "", "mods": mods(rest, ctx)}
            if len(words) == 3 and words[1] == "scaled" and "/" in words[2]:
                vname, div = words[2].split("/", 1)
                entry["scaleBy"] = vname
                entry["divisor"] = num(div, ctx)
                if entry["divisor"] == 0:
                    raise SystemExit(f"{ctx}: scale divisor cannot be 0")
            elif len(words) != 1:
                raise SystemExit(f"{ctx}: effect expects 'effect role:' or 'effect role scaled value/divisor:'")
            sy["roleEffects"].append((n, entry))
            continue
        if "=" not in text:
            raise SystemExit(f"{ctx}: expected 'name = value'")
        k, v = [x.strip() for x in text.split("=", 1)]
        words = k.split()
        if k == "name":
            sy["name"] = v
        elif k == "leader":
            if v not in ref.tags:
                raise SystemExit(f"{ctx}: unknown country tag '{v}'")
            sy["leader"] = v
        elif k == "members":
            sy["roles"].append({"role": "member", "tags": tags_list(v, ref, ctx)})
        elif k == "roles":
            for r in [x.strip() for x in v.split(",") if x.strip()]:
                if not ID_RE.match(r) or r in ("member", "leader"):
                    raise SystemExit(f"{ctx}: bad role name '{r}'")
                if r not in declared_roles:
                    declared_roles.append(r)
        elif len(words) == 2 and words[0] == "role":
            r = words[1]
            if not ID_RE.match(r) or r in ("member", "leader"):
                raise SystemExit(f"{ctx}: bad role name '{r}' (members use 'members =', the leader 'leader =')")
            if r not in declared_roles:
                declared_roles.append(r)
            sy["roles"].append({"role": r, "tags": tags_list(v, ref, ctx)})
        elif len(words) == 2 and words[0] == "value":
            name = words[1]
            if not ID_RE.match(name) or name in sy["valueNames"]:
                raise SystemExit(f"{ctx}: bad or repeated value name '{name}'")
            start, _, rng = v.partition("|")
            entry = {"key": name, "value": num(start, ctx)}
            if rng.strip():
                m = RANGE_RE.match(rng.strip())
                if not m:
                    raise SystemExit(f"{ctx}: range must be 'min..max'")
                lo, hi = num(m.group(1), ctx), num(m.group(2), ctx)
                if lo > hi or not (lo <= entry["value"] <= hi):
                    raise SystemExit(f"{ctx}: start {entry['value']} must lie in {lo}..{hi}")
                entry["min"], entry["max"] = lo, hi
            sy["values"].append(entry)
            sy["valueNames"].append(name)
        elif len(words) == 2 and words[0] == "country_value":
            name = words[1]
            if not ID_RE.match(name) or name in sy["countryValueNames"]:
                raise SystemExit(f"{ctx}: bad or repeated country value name '{name}'")
            m = RANGE_RE.match(v)
            if not m:
                raise SystemExit(f"{ctx}: country_value expects 'country_value name = min..max'")
            lo, hi = num(m.group(1), ctx), num(m.group(2), ctx)
            if lo > hi:
                raise SystemExit(f"{ctx}: min above max")
            sy["countryValueNames"].append(name)
            sy["countryLimits"] = sy.get("countryLimits", []) + [{"key": name, "min": lo, "max": hi}]
        elif len(words) == 2 and words[0] == "param":
            name = words[1]
            if not ID_RE.match(name) or any(p["key"] == name for p in sy["params"]):
                raise SystemExit(f"{ctx}: bad or repeated param name '{name}'")
            sy["params"].append({"key": name, "value": num(v, ctx)})
        elif k == "provinces":
            for pname in [x.strip() for x in v.split(",") if x.strip()]:
                idx = ref.resolve_province(pname, ctx)
                if idx in sy["provinces"]:
                    raise SystemExit(f"{ctx}: province '{pname}' listed twice")
                sy["provinces"].append(idx)
        else:
            raise SystemExit(f"{ctx}: unknown line '{k}'")

    if not sy["name"]:
        raise SystemExit(f"{ctx0}: missing 'name ='")
    roles_ok = set(declared_roles) | {"member", "leader"}
    effects = []
    for n, e in sy.pop("roleEffects"):
        if e["role"] not in roles_ok:
            raise SystemExit(f"{path.name}:{n}: effect for unknown role '{e['role']}'")
        if "scaleBy" in e and e["scaleBy"] not in sy["valueNames"]:
            raise SystemExit(f"{path.name}:{n}: scaled by unknown value '{e['scaleBy']}'")
        effects.append(e)
    sy["roleEffects"] = effects
    sy["roleNames"] = declared_roles
    sy["countryLimits"] = sy.get("countryLimits", [])
    clash = set(sy["valueNames"]) & set(sy["countryValueNames"])
    if clash:
        raise SystemExit(f"{ctx0}: '{sorted(clash)[0]}' is both a value and a country_value")
    return sy


# --- Formables --------------------------------------------------------------

def parse_formable(path: Path, fid: str, lines, ref, gov) -> dict:
    ctx0 = f"{path.name} formable {fid}"
    if not FORMABLE_RE.match(fid):
        raise SystemExit(f"{ctx0}: id must be 2-8 capitals/digits, like SPA")
    if fid in ref.tags:
        raise SystemExit(f"{ctx0}: '{fid}' is already a 1453 country tag; pick another id")
    f = {
        "id": fid, "name": None, "text": "", "color": None, "shield": fid,
        "eligible": [], "trigger": [], "government": None, "reforms": [],
        "effects": [], "missionTree": None, "ai": True, "unique": True,
    }
    section = None
    for n, line in lines:
        ctx = f"{path.name}:{n}"
        text = line.strip()
        indented = line.startswith((" ", "\t"))
        if text in ("trigger:", "effect:"):
            section = text[:-1]
            continue
        if indented and section:
            if "=" not in text:
                raise SystemExit(f"{ctx}: expected 'name = value'")
            k, v = [x.strip() for x in text.split("=", 1)]
            if section == "trigger":
                if k == "can_form":
                    raise SystemExit(f"{ctx}: can_form cannot be used inside a formable's own trigger")
                f["trigger"].append(eventgen.validate_condition(k, v, ref, ctx))
            else:
                if k == "form_nation":
                    raise SystemExit(f"{ctx}: form_nation cannot be a formable's effect")
                f["effects"].append(eventgen.validate_effect(k, v, ref, ctx))
            continue
        section = None
        if "=" not in text:
            raise SystemExit(f"{ctx}: expected 'name = value'")
        k, v = [x.strip() for x in text.split("=", 1)]
        if k == "name":
            f["name"] = v
        elif k == "text":
            f["text"] = v
        elif k == "color":
            parts = v.replace(",", " ").split()
            if len(parts) != 3 or not all(p.isdigit() and 0 <= int(p) <= 255 for p in parts):
                raise SystemExit(f"{ctx}: color expects three numbers 0-255")
            f["color"] = [int(p) for p in parts]
        elif k == "shield":
            if not FORMABLE_RE.match(v):
                raise SystemExit(f"{ctx}: shield key must be 2-8 capitals/digits")
            f["shield"] = v
        elif k == "eligible":
            f["eligible"] = tags_list(v, ref, ctx)
        elif k == "government":
            if v not in eventgen.VALID_GOVERNMENTS:
                raise SystemExit(f"{ctx}: unknown government '{v}'")
            f["government"] = v
        elif k == "reforms":
            f["reforms"] = [x.strip() for x in v.split(",") if x.strip()]
            f["_reforms_line"] = n
        elif k == "mission_tree":
            if not ID_RE.match(v):
                raise SystemExit(f"{ctx}: mission_tree must be lowercase snake_case")
            f["missionTree"] = v
        elif k in ("ai", "unique"):
            f[k] = eventgen.parse_bool(v, ctx)
        else:
            raise SystemExit(f"{ctx}: unknown line '{k}'")

    if not f["name"]:
        raise SystemExit(f"{ctx0}: missing 'name ='")
    if f["color"] is None:
        raise SystemExit(f"{ctx0}: missing 'color ='")
    if not f["trigger"]:
        raise SystemExit(f"{ctx0}: a formable needs at least one trigger condition")
    line = f.pop("_reforms_line", 0)
    if f["reforms"]:
        trees = [f["government"]] if f["government"] else sorted(gov["reforms"].keys())
        for r in f["reforms"]:
            if not any(r in {o["key"] for t in gov["reforms"].get(g, []) for o in t["options"]} for g in trees):
                where = f"the {f['government']} tree" if f["government"] else "any reform tree"
                raise SystemExit(f"{path.name}:{line}: reform '{r}' is not in {where}")
    return f


def main() -> None:
    ref = eventgen.ReferenceData()
    gov = json.loads((RES_DIR / "government1453.json").read_text(encoding="utf-8"))
    sc = json.loads((RES_DIR / "scenario1453.json").read_text(encoding="utf-8"))

    systems: list[dict] = []
    sys_files = sorted(SYSTEMS_DIR.glob("*.txt")) if SYSTEMS_DIR.exists() else []
    for p in sys_files:
        for key, lines in blocks(p, "system"):
            if any(s["key"] == key for s in systems):
                raise SystemExit(f"{p.name}: duplicate system '{key}'")
            systems.append(parse_system(p, key, lines, ref))

    # Conditions and effects in formables may name any system or formable.
    ref.ruling_systems = {
        s["key"]: {
            "roles": set(s["roleNames"]) | {"member", "leader"},
            "values": set(s["valueNames"]),
            "country_values": set(s["countryValueNames"]),
        }
        for s in systems
    }
    raw: list[tuple[Path, str, list]] = []
    form_files = sorted(FORMABLES_DIR.glob("*.txt")) if FORMABLES_DIR.exists() else []
    for p in form_files:
        for fid, lines in blocks(p, "formable"):
            if any(r[1] == fid for r in raw):
                raise SystemExit(f"{p.name}: duplicate formable '{fid}'")
            raw.append((p, fid, lines))
    ref.formables = {r[1] for r in raw}
    formables = [parse_formable(p, fid, lines, ref, gov) for p, fid, lines in raw]

    payload = {
        "provinceCount": len(sc["provinces"]),
        "systems": systems,
        "formables": formables,
    }
    OUT_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(
        f"Wrote {OUT_PATH.relative_to(ROOT)} ({len(systems)} ruling systems from {len(sys_files)} files, "
        f"{len(formables)} formables from {len(form_files)} files)"
    )


if __name__ == "__main__":
    main()
