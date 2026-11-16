#!/usr/bin/env python3
"""Build the earthquake data file for the 1453 scenario (Phase 12).

Reads data/calamity/fault_zones.txt, finds the provinces inside each fault
zone from Packages/GezCore/Sources/GezCore/Resources/scenario1453.json and
writes Resources/calamity1453.json. Provinces are stored as their index in
the scenario, so run this again whenever the map changes.

Run after mapgen.py:  python3 tools/calamity/calamitygen.py
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data/calamity"
RES = ROOT / "Packages/GezCore/Sources/GezCore/Resources"
SOURCE = "fault_zones.txt"


def rows(name):
    for number, line in enumerate((DATA / name).read_text().splitlines(), 1):
        line = line.strip()
        if line and not line.startswith("#"):
            yield number, [x.strip() for x in line.split("|")]


def km(lat1, lon1, lat2, lon2):
    """Great-circle distance in kilometres."""
    r = math.pi / 180
    a = (math.sin((lat2 - lat1) * r / 2) ** 2
         + math.cos(lat1 * r) * math.cos(lat2 * r) * math.sin((lon2 - lon1) * r / 2) ** 2)
    return 12742 * math.asin(min(1, math.sqrt(a)))


def number(text, what, line, low, high):
    try:
        value = float(text)
    except ValueError:
        sys.exit(f"{SOURCE}:{line}: {what} '{text}' is not a number")
    if not low <= value <= high:
        sys.exit(f"{SOURCE}:{line}: {what} {value} must be between {low} and {high}")
    return value


def main():
    scen = json.loads((RES / "scenario1453.json").read_text())
    provinces = scen["provinces"]
    by_name = {}
    for i, p in enumerate(provinces):
        by_name.setdefault(p["name"], []).append(i)

    zones, quakes = [], []
    seen = set()
    for line, r in rows(SOURCE):
        if r[0] == "zone":
            if len(r) != 7:
                sys.exit(f"{SOURCE}:{line}: expected 'zone | name | latitude | longitude | radius km | "
                         f"chance per year | strength', got {len(r)} fields")
            name = r[1]
            if not name or name in seen:
                sys.exit(f"{SOURCE}:{line}: missing or duplicate zone name '{name}'")
            seen.add(name)
            lat = number(r[2], "latitude", line, -90, 90)
            lon = number(r[3], "longitude", line, -180, 180)
            radius = number(r[4], "radius", line, 20, 1500)
            chance = number(r[5], "chance per year", line, 0.0001, 0.5)
            strength = number(r[6], "strength", line, 0.1, 1)
            inside = [i for i, p in enumerate(provinces)
                      if km(lat, lon, p["latitude"], p["longitude"]) <= radius]
            if not inside:
                sys.exit(f"{SOURCE}:{line}: zone '{name}' contains no province (is it on the map?)")
            zones.append({"name": name, "yearlyChance": chance, "strength": strength, "provinces": inside})
        elif r[0] == "quake":
            if len(r) != 5:
                sys.exit(f"{SOURCE}:{line}: expected 'quake | year-month-day | province | strength | name', "
                         f"got {len(r)} fields")
            parts = r[1].split("-")
            if len(parts) != 3 or not all(x.isdigit() for x in parts):
                sys.exit(f"{SOURCE}:{line}: date '{r[1]}' must look like 1456-12-05")
            year, month, day = (int(x) for x in parts)
            if not (1453 <= year <= 1900 and 1 <= month <= 12 and 1 <= day <= 31):
                sys.exit(f"{SOURCE}:{line}: date '{r[1]}' is out of range")
            if (year, month, day) <= (1453, 5, 30):
                sys.exit(f"{SOURCE}:{line}: '{r[4]}' is before the game starts")
            found = by_name.get(r[2], [])
            if len(found) != 1:
                sys.exit(f"{SOURCE}:{line}: province '{r[2]}' " + ("is unknown" if not found else "is not unique"))
            strength = number(r[3], "strength", line, 0.1, 1)
            if not r[4]:
                sys.exit(f"{SOURCE}:{line}: the earthquake needs a name")
            quakes.append({"name": r[4], "year": year, "month": month, "day": day,
                           "province": found[0], "strength": strength})
        else:
            sys.exit(f"{SOURCE}:{line}: unknown row type '{r[0]}' (use zone or quake)")

    if not zones:
        sys.exit(f"{SOURCE}: no fault zones")
    quakes.sort(key=lambda q: (q["year"], q["month"], q["day"], q["name"]))
    out = {"provinceCount": len(provinces), "faultZones": zones, "historicalQuakes": quakes}
    (RES / "calamity1453.json").write_text(json.dumps(out, indent=1) + "\n")
    covered = len({p for z in zones for p in z["provinces"]})
    print(f"calamitygen: {len(zones)} fault zones covering {covered} provinces, "
          f"{len(quakes)} known earthquakes written to calamity1453.json")
    for z in zones:
        names = [provinces[i]["name"] for i in z["provinces"]]
        print(f"  {z['name']:34s} {len(names):3d}  {', '.join(names[:6])}{'...' if len(names) > 6 else ''}")


if __name__ == "__main__":
    main()
