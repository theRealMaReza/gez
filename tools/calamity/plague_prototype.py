#!/usr/bin/env python3
"""Balance prototype for the plague rules (a Python copy of the monthly
spread in Systems/PlagueSystem.swift; keep the constants in step).

It reads the generated scenario and prints, per decade, how many people
die of each disease and how many provinces were struck, so the numbers can
be tuned without waiting for a CI run.

    python3 tools/calamity/plague_prototype.py [years] [seed]
"""
import json, os, random, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RES = os.path.join(ROOT, 'Packages/GezCore/Sources/GezCore/Resources')

# name, months an outbreak lasts, share struck in a crowded naive city,
# share of the struck who die, immunity fading per month, monthly chance
# of a fresh outbreak in a crowded province
DISEASES = [
    ('plague',   9, 0.30, 0.35, 0.0030, 0.00040),
    ('typhus',   6, 0.20, 0.15, 0.0100, 0.0),
    ('smallpox', 7, 0.35, 0.12, 0.0015, 0.00030),
]
MIN_SUSCEPTIBLE = 0.45
# After an outbreak the province counts as this immune (survivors plus the
# people it never reached), fading from there.
IMMUNITY_AFTER = 0.75
NEIGHBOUR = 3.0     # chance per neighbour = min(cap, k * share struck this month)
NEIGHBOUR_CAP = float(os.environ.get('NC', 0.08))
MARKET = 4.0
MARKET_CAP = 0.20
SEA = 3.0
SEA_CAP = 0.12


def weights(n):
    import math
    w = [math.sin(math.pi * (t + 0.5) / n) ** 2 for t in range(n)]
    s = sum(w)
    return [x / s for x in w]


def main():
    years = int(sys.argv[1]) if len(sys.argv) > 1 else 50
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1453
    rnd = random.Random(seed)
    sc = json.load(open(os.path.join(RES, 'scenario1453.json')))
    eco = json.load(open(os.path.join(RES, 'economy1453.json')))
    provs = sc['provinces']
    P = len(provs)
    pop = [float(p['population']) for p in provs]
    dev = [p['development'] for p in provs]
    adj = [p['adjacent'] for p in provs]
    seas = [[] for _ in range(P)]
    for z, s in enumerate(sc['seaZones']):
        for p in s['coast']:
            seas[p].append(z)
    coast = [s['coast'] for s in sc['seaZones']]
    centres = [m['centre'] for m in eco['markets']]
    D = len(DISEASES)
    W = [weights(d[1]) for d in DISEASES]
    course = [[0] * D for _ in range(P)]      # months into the outbreak (0 = none)
    attack = [[0.0] * D for _ in range(P)]
    imm = [[0.0] * D for _ in range(P)]
    start = sum(pop)
    all_deaths = [0.0] * D
    for year in range(years):
        deaths = [0.0] * D
        struck = [set() for _ in range(D)]
        for month in range(12):
            seeds = []
            for p in range(P):
                for d, (name, length, base, leth, fade, origin) in enumerate(DISEASES):
                    if course[p][d] == 0:
                        crowded = dev[p] >= 7 or (seas[p] and dev[p] >= 5)
                        if origin > 0 and crowded and rnd.random() < origin * dev[p] / 7:
                            seeds.append((p, d))
                        continue
                    i = attack[p][d] * W[d][course[p][d] - 1]
                    struck[d].add(p)
                    for q in adj[p]:
                        if rnd.random() < min(NEIGHBOUR_CAP, NEIGHBOUR * i) * (0.5 + 0.07 * dev[q]):
                            seeds.append((q, d))
                    if p in centres and rnd.random() < min(MARKET_CAP, MARKET * i):
                        seeds.append((rnd.choice(centres), d))
                    if seas[p] and rnd.random() < min(SEA_CAP, SEA * i):
                        z = rnd.choice(seas[p])
                        seeds.append((rnd.choice(coast[z]), d))
                    dead = pop[p] * i * leth
                    pop[p] -= dead
                    deaths[d] += dead
                    all_deaths[d] += dead
                    course[p][d] += 1
                    if course[p][d] > length:
                        course[p][d] = 0
                        imm[p][d] = max(imm[p][d], IMMUNITY_AFTER)
            for p in range(P):
                for d in range(D):
                    imm[p][d] *= 1 - DISEASES[d][4]
            for p, d in seeds:
                sus = 1 - imm[p][d]
                if course[p][d] == 0 and sus > MIN_SUSCEPTIBLE:
                    crowd = 0.25 + 0.10 * dev[p]
                    attack[p][d] = min(0.6, DISEASES[d][2] * crowd * sus * (0.6 + 0.8 * rnd.random()))
                    course[p][d] = 1
            for p in range(P):
                pop[p] *= 1 + 0.004 / 12
        if year % 5 == 4 or year < 3:
            total = sum(pop)
            print(f"year {year + 1:3d}: pop {total / start:5.3f}  " + "  ".join(
                f"{DISEASES[d][0]} {deaths[d] / total * 100:5.2f}% in {len(struck[d]):4d} prov" for d in range(D)))

    print('average deaths a year: ' + '  '.join(f"{DISEASES[d][0]} {all_deaths[d] / start / years * 100:.3f}%" for d in range(D)))


if __name__ == '__main__':
    main()
