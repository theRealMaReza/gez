#!/usr/bin/env python3
"""Build the faith and holy sites data file for the 1453 scenario (Phase 11).

Reads data/faith/holy_sites.txt and validates province names and religion keys
against Packages/GezCore/Sources/GezCore/Resources/scenario1453.json and the
GezCore Religion enum. Writes Resources/faith1453.json.

Run after mapgen.py:  python3 tools/faith/faithgen.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data/faith"
RES = ROOT / "Packages/GezCore/Sources/GezCore/Resources"

sys.path.insert(0, str(ROOT / "tools"))
from faiths import RELIGIONS  # noqa: E402


def rows(name):
    for line in (DATA / name).read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            yield [x.strip() for x in line.split("|")]


def main():
    scen = json.loads((RES / "scenario1453.json").read_text())
    prov_by_name = {p["name"]: i for i, p in enumerate(scen["provinces"])}

    holy_sites = []
    seen_names = set()
    for r in rows("holy_sites.txt"):
        if r[0] != "site" or len(r) < 4:
            sys.exit(f"holy_sites.txt: expected 'site | name | province | religions', got {r}")
        _, name, prov_name, rel_text = r[:4]
        if name in seen_names:
            sys.exit(f"holy_sites.txt: duplicate site '{name}'")
        seen_names.add(name)
        if prov_name not in prov_by_name:
            sys.exit(f"holy_sites.txt: unknown province '{prov_name}' for '{name}'")
        rels = [x.strip() for x in rel_text.split(",") if x.strip()]
        if not rels:
            sys.exit(f"holy_sites.txt: '{name}' has no religions")
        for rel in rels:
            if rel not in RELIGIONS:
                sys.exit(f"holy_sites.txt: unknown religion '{rel}' for '{name}'")
        holy_sites.append({
            "name": name,
            "province": prov_name,
            "religions": rels,
        })

    out = {"holySites": holy_sites}
    (RES / "faith1453.json").write_text(json.dumps(out, indent=2) + "\n")
    print(f"faithgen: {len(holy_sites)} holy sites written to faith1453.json")


if __name__ == "__main__":
    main()
