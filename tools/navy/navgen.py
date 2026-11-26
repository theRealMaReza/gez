#!/usr/bin/env python3
"""
Generate Packages/GezCore/Sources/GezCore/Resources/navy1453.json from:
  - data/navy/ships.txt
  - data/navy/fleets_1453.txt
  - Packages/GezCore/Sources/GezCore/Resources/scenario1453.json
  - Packages/GezCore/Sources/GezCore/Resources/economy1453.json
  - Packages/GezCore/Sources/GezCore/Resources/government1453.json
  - Packages/GezCore/Sources/GezCore/Resources/characters1453.json
  - Packages/GezCore/Sources/GezCore/Resources/seas1453.idmap

Run from repo root:
    python3 tools/navy/navgen.py
"""

from __future__ import annotations
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "navy"
RES = ROOT / "Packages" / "GezCore" / "Sources" / "GezCore" / "Resources"
SCENARIO = RES / "scenario1453.json"
ECONOMY = RES / "economy1453.json"
GOVERNMENT = RES / "government1453.json"
CHARACTERS = RES / "characters1453.json"
SEAS_IDMAP = RES / "seas1453.idmap"
OUT = RES / "navy1453.json"

SHIP_CLASSES = {"transport", "galley", "heavy", "light"}
GOVERNMENTS = {
    "monarchy", "feudalMonarchy", "electiveMonarchy", "iqta", "sultanate",
    "imperial", "timuridPrincedom", "mamlukSultanate", "merchantRepublic",
    "signoria", "oligarchicRepublic", "freeCity", "peasantRepublic",
    "confederation", "papacy", "theocracy", "monasticOrder", "steppeHorde",
    "tribalFederation", "tribalKingdom", "iqtaEmirate",
}

INLAND_SEAS = {
    # Mediterranean
    "Alboran Sea", "Balearic Sea", "Gulf of Lion", "Ligurian Sea",
    "Sardinian Sea", "Tyrrhenian Sea", "Sicilian Channel", "Gulf of Gabes",
    "Northern Adriatic", "Southern Adriatic", "Ionian Sea", "Gulf of Sidra",
    "Libyan Sea", "Northern Aegean", "Southern Aegean", "Sea of Marmara",
    "Cilician Sea", "Levantine Sea", "Sea of Alexandria",
    # Black Sea
    "Western Black Sea", "Eastern Black Sea", "Sea of Azov",
    # Baltic Sea
    "Western Baltic", "Baltic Sea", "Gulf of Riga", "Gulf of Finland",
    "Bothnian Sea", "Bay of Bothnia",
    # Red Sea
    "Northern Red Sea", "Central Red Sea", "Southern Red Sea",
}

# All straits from tools/mapgen/mapgen.py STRAITS, including narrow channels
# whose pixels touch on the raster map (e.g. Bosporus, Dardanelles, Messina).
STRAIT_NAMES = [
    ("Konstantiniyye", "Izmit"),
    ("Gallipoli", "Biga"),
    ("Gibraltar", "Ceuta"),
    ("Messina", "Reggio"),
    ("Copenhagen", "Lund"),
    ("Odense", "Copenhagen"),
    ("Odense", "Aarhus"),
    ("Kiel", "Odense"),
    ("Solkhat", "Matrega"),
    ("Kaffa", "Matrega"),
    ("Zeila", "Aden"),
    ("Hormuz", "Julfar"),
    ("Hormuz", "Minab"),
    ("Canterbury", "Calais"),
    ("Jaffna", "Madurai"),
    ("Djerba", "Gabes"),
    ("Negroponte", "Thebes"),
    ("Corfu", "Gjirokaster"),
    ("Chios", "Izmir"),
    ("Mytilene", "Balikesir"),
    ("Rhodes", "Milas"),
    ("Bahrain", "Qatif"),
    ("Mallorca", "Menorca"),
    ("Ibiza", "Mallorca"),
    ("Bastia", "Sassari"),
    ("Malta", "Agrigento"),
    ("Visby", "Kalmar"),
    ("Turku", "Stockholm"),
    ("Reval", "Turku"),
    ("Osel", "Pernau"),
    ("Isle of Man", "Lancaster"),
    ("Dublin", "Caernarfon"),
    ("Carrickfergus", "Ayr"),
    ("Orkney", "Wick"),
    ("Lewis", "Skye"),
    ("Skye", "Dingwall"),
    ("Islay", "Inveraray"),
    ("Leizhou", "Qiongzhou"),
    ("Jeju", "Naju"),
    ("Tsushima", "Busan"),
    ("Tsushima", "Hizen"),
    ("Nagato", "Buzen"),
    ("Bizen", "Sanuki"),
    ("Iyo", "Bungo"),
    ("Kii", "Tokushima"),
    ("Tsugaru", "Oshima"),
    ("Okinawa", "Amami"),
    ("Teshio", "Kuye South"),
    ("Nurgan", "Kuye North"),
    ("Malacca", "Siak"),
    ("Johor", "Indragiri"),
    ("Lampung", "Banten"),
    ("Bangka", "Palembang"),
    ("Blambangan", "Gelgel"),
    ("Gelgel", "Lombok"),
    ("Lombok", "Sumbawa"),
    ("Sumbawa", "Flores"),
    ("Flores", "Timor"),
    ("Sabah", "Jolo"),
    ("Jolo", "Cotabato"),
    ("Butuan", "Samar"),
    ("Samar", "Bicol"),
    ("Cebu", "Panay"),
    ("Cebu", "Samar"),
    ("Mindoro", "Tondo"),
    ("Mindoro", "Panay"),
    ("Palawan", "Sabah"),
    ("Palawan", "Mindoro"),
    ("Manado", "Ternate"),
    ("Ternate", "Tidore"),
    ("Tidore", "Seram"),
    ("Buru", "Seram"),
    ("Buton", "Buru"),
    ("Zanzibar", "Bagamoyo"),
    ("Zanzibar", "Pangani"),
    ("Lindi", "Comoros"),
    ("Comoros", "Mozambique"),
]


def rows(name: str):
    path = DATA / name
    for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        yield lineno, [p.strip() for p in line.split("|")]


def parse_goods(cell: str, known_goods: set[str], ctx: str) -> dict[str, float]:
    out: dict[str, float] = {}
    if not cell:
        return out
    for part in cell.split(","):
        part = part.strip()
        if not part:
            continue
        toks = part.split()
        if len(toks) != 2:
            raise SystemExit(f"{ctx}: expected '<good> <amount>', got '{part}'")
        good, amt_s = toks
        if good not in known_goods:
            raise SystemExit(f"{ctx}: unknown good '{good}'")
        amt = float(amt_s)
        if amt <= 0:
            raise SystemExit(f"{ctx}: non-positive good amount '{part}'")
        out[good] = amt
    return out


def parse_requires(
    cell: str,
    known_estates: set[str],
    known_cultures: set[str],
    known_regions: set[str],
    known_tags: set[str],
    ctx: str,
) -> list[dict]:
    rules: list[dict] = []
    if not cell:
        return rules
    for clause in cell.split(";"):
        clause = clause.strip()
        if not clause:
            continue
        if ":" not in clause:
            raise SystemExit(f"{ctx}: bad requires clause '{clause}'")
        kind, raw_vals = [x.strip() for x in clause.split(":", 1)]
        vals = [v.strip() for v in raw_vals.split(",") if v.strip()]
        if not vals:
            raise SystemExit(f"{ctx}: empty requires values in '{clause}'")
        if kind == "estate":
            for v in vals:
                if v not in known_estates:
                    raise SystemExit(f"{ctx}: unknown estate '{v}'")
        elif kind == "government":
            for v in vals:
                if v not in GOVERNMENTS:
                    raise SystemExit(f"{ctx}: unknown government '{v}'")
        elif kind == "culture":
            for v in vals:
                if v not in known_cultures:
                    raise SystemExit(f"{ctx}: unknown culture '{v}'")
        elif kind == "region":
            for v in vals:
                if v not in known_regions:
                    raise SystemExit(f"{ctx}: unknown region '{v}'")
        elif kind == "tags":
            for v in vals:
                if v not in known_tags:
                    raise SystemExit(f"{ctx}: unknown tag '{v}'")
        else:
            raise SystemExit(f"{ctx}: unknown requires kind '{kind}'")
        rules.append({"kind": kind, "values": vals})
    return rules


def sea_zone_centers(scen: dict) -> list[tuple[float, float]]:
    data = SEAS_IDMAP.read_bytes()
    magic, width, height, run_count = struct.unpack_from("<4sIII", data, 0)
    assert magic == b"GZID", f"Bad sea idmap magic {magic!r}"
    n_seas = len(scen["seaZones"])
    sum_x = [0.0] * n_seas
    sum_y = [0.0] * n_seas
    counts = [0] * n_seas

    pos = 0
    offset = 16
    for _ in range(run_count):
        val, length = struct.unpack_from("<HH", data, offset)
        offset += 4
        if val > 0 and val <= n_seas and length > 0:
            z = val - 1
            # Sum exact (x, y) over [pos, pos + length) across row breaks cleanly
            rem = length
            cur = pos
            while rem > 0:
                y = cur // width
                x0 = cur % width
                take = min(rem, width - x0)
                # sum of x0 .. x0+take-1
                sum_x[z] += take * (2 * x0 + take - 1) * 0.5
                sum_y[z] += take * y
                counts[z] += take
                cur += take
                rem -= take
        pos += length

    provinces = scen["provinces"]
    centers: list[tuple[float, float]] = []
    for z, sz in enumerate(scen["seaZones"]):
        if counts[z] > 0:
            centers.append((round(sum_x[z] / counts[z], 1), round(sum_y[z] / counts[z], 1)))
        elif sz["coast"]:
            cx = sum(provinces[p]["labelX"] for p in sz["coast"]) / len(sz["coast"])
            cy = sum(provinces[p]["labelY"] for p in sz["coast"]) / len(sz["coast"])
            centers.append((round(cx, 1), round(cy, 1)))
        else:
            centers.append((0.0, 0.0))
    return centers


def main() -> None:
    scen = json.loads(SCENARIO.read_text(encoding="utf-8"))
    econ = json.loads(ECONOMY.read_text(encoding="utf-8"))
    govt = json.loads(GOVERNMENT.read_text(encoding="utf-8"))
    chars = json.loads(CHARACTERS.read_text(encoding="utf-8"))

    known_goods = {g["key"] for g in econ["goods"]}
    known_estates = {e["key"] for e in govt["estates"]}
    known_cultures = {c["id"] for c in scen["cultures"]}
    known_regions = set(scen["regions"])
    known_tags = {c["tag"] for c in scen["countries"]}
    prov_by_name = {p["name"]: i for i, p in enumerate(scen["provinces"])}
    char_by_id = {c["id"]: c for c in chars["characters"]}

    ships: list[dict] = []
    ship_keys: set[str] = set()
    for lineno, parts in rows("ships.txt"):
        ctx = f"ships.txt:{lineno}"
        if len(parts) != 14:
            raise SystemExit(f"{ctx}: expected 14 columns, got {len(parts)}")
        key, name, sclass, speed_s, hull_s, cannons_s, crew_s, months_s, cost_s, upkeep_s, cap_s, goods_s, req_s, min_tech_s = parts
        if sclass not in SHIP_CLASSES:
            raise SystemExit(f"{ctx}: unknown class '{sclass}'")
        if key in ship_keys:
            raise SystemExit(f"{ctx}: duplicate ship key '{key}'")
        min_tech = int(min_tech_s)
        if not (1 <= min_tech <= 20):
            raise SystemExit(f"{ctx}: min_dip_tech {min_tech} must be 1..20")
        ship_keys.add(key)
        ships.append({
            "key": key,
            "name": name,
            "shipClass": sclass,
            "speed": float(speed_s),
            "hull": float(hull_s),
            "cannons": int(cannons_s),
            "crew": int(crew_s),
            "buildMonths": int(months_s),
            "cost": float(cost_s),
            "upkeep": float(upkeep_s),
            "capacity": int(cap_s),
            "goods": parse_goods(goods_s, known_goods, ctx),
            "requires": parse_requires(req_s, known_estates, known_cultures, known_regions, known_tags, ctx),
            "minDipTech": min_tech,
        })

    fleets: list[dict] = []
    for lineno, parts in rows("fleets_1453.txt"):
        ctx = f"fleets_1453.txt:{lineno}"
        if len(parts) != 5:
            raise SystemExit(f"{ctx}: expected 5 columns, got {len(parts)}")
        tag, fname, prov_name, adm_s, ships_s = parts
        if tag not in known_tags:
            raise SystemExit(f"{ctx}: unknown country tag '{tag}'")
        if prov_name not in prov_by_name:
            raise SystemExit(f"{ctx}: unknown port province '{prov_name}'")
        pid = prov_by_name[prov_name]
        if not scen["provinces"][pid]["coastal"]:
            raise SystemExit(f"{ctx}: port '{prov_name}' is not coastal")
        adm = None if adm_s in ("", "-") else adm_s
        if adm is not None and adm not in char_by_id:
            raise SystemExit(f"{ctx}: unknown admiral '{adm}'")
        ship_list = []
        for tok in ships_s.split(","):
            tok = tok.strip()
            if not tok:
                continue
            if ":" not in tok:
                raise SystemExit(f"{ctx}: expected '<ship_key>:<count>', got '{tok}'")
            sk, cnt_s = [x.strip() for x in tok.split(":", 1)]
            if sk not in ship_keys:
                raise SystemExit(f"{ctx}: unknown ship key '{sk}'")
            cnt = int(cnt_s)
            if cnt <= 0:
                raise SystemExit(f"{ctx}: non-positive count '{tok}'")
            ship_list.append({"type": sk, "count": cnt})
        fleets.append({
            "country": tag,
            "name": fname,
            "province": pid,
            "admiral": adm,
            "ships": ship_list,
        })

    centers = sea_zone_centers(scen)
    sea_zones_meta = [
        {
            "name": sz["name"],
            "inland": sz["name"] in INLAND_SEAS,
            "centerX": centers[z][0],
            "centerY": centers[z][1],
        }
        for z, sz in enumerate(scen["seaZones"])
    ]

    prov_seas = [set() for _ in scen["provinces"]]
    for z, sz in enumerate(scen["seaZones"]):
        for p in sz["coast"]:
            prov_seas[p].add(z)
    sea_adj = [set(sz["adjacent"]) for sz in scen["seaZones"]]

    # Build deduplicated strait -> guarding sea zones table
    strait_pairs: list[tuple[int, int]] = []
    seen_pairs: set[tuple[int, int]] = set()
    for a, b in STRAIT_NAMES:
        if a in prov_by_name and b in prov_by_name:
            u, v = prov_by_name[a], prov_by_name[b]
            key = (min(u, v), max(u, v))
            if key not in seen_pairs:
                seen_pairs.add(key)
                strait_pairs.append(key)
    for pair in scen.get("straits", []):
        u, v = pair[0], pair[1]
        key = (min(u, v), max(u, v))
        if key not in seen_pairs:
            seen_pairs.add(key)
            strait_pairs.append(key)

    straits_meta = []
    for u, v in strait_pairs:
        common = sorted(prov_seas[u] & prov_seas[v])
        if not common:
            # Find zones touching shore u that touch zones touching shore v
            near = set()
            for su in prov_seas[u]:
                for sv in prov_seas[v]:
                    if sv in sea_adj[su]:
                        near.add(su)
                        near.add(sv)
            common = sorted(near) if near else sorted(prov_seas[u] | prov_seas[v])
        straits_meta.append({"a": u, "b": v, "seas": common})

    payload = {
        "ships": ships,
        "fleets": fleets,
        "seaZones": sea_zones_meta,
        "straits": straits_meta,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    total_ships = sum(s["count"] for f in fleets for s in f["ships"])
    print(f"Wrote {OUT.relative_to(ROOT)}: {len(ships)} ship types, {len(fleets)} fleets ({total_ships} ships), {len(straits_meta)} straits")


if __name__ == "__main__":
    main()
