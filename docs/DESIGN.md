# Gez — Design Document

A real-time-with-pause grand strategy game for Mac and iPad, in the spirit of
Europa Universalis V, with Total War–style battles and sieges. Time runs on a
daily tick like EU4, never turn-based.

## Vision

- Grand strategy on a historical map, starting **30 May 1453**, the day after
  Mehmed II's conquest of Constantinople.
- EU5-like depth: pops, economy, estates, religion, government, diplomacy.
- When armies meet, the player can **fight the battle in real time in a 2D
  top-down view** or **auto-resolve**. Sieges work the same way.
- Runs smoothly on an M1 Mac (minimum spec) and an M5 iPad.

## Map scope

The Old World (Phase 20.7, owner, 22–23 Nov 2026): all of Afro-Eurasia,
25° W to 148° E and 35° S to 71.5° N, at 48 pixels per degree (8304 × 5112
pixels, about 2.3 km per pixel). Europe, North Africa, the Horn, the Middle
East, Central Asia and India are filled in; East and Southeast Asia, Siberia
and Africa south of the Equator start as placeholder wasteland and are filled
region by region (`docs/HANDOFF.md`, "Old World region pull requests").
Target: roughly 3,000 land provinces and 500 countries.
**Australia and New Guinea are unknown land** (owner, 23 Nov 2026): not
playable, drawn as blank parchment (terra incognita). In the data they are
wasteland in the province map and carry the value `0xFFFF`
(`ProvinceIDMap.unknownLand`) in the sea map; mapgen makes them from `?`
seeds instead of `!`.

Map data is built from public-domain geography (e.g. Natural Earth). No data
or art from Paradox or Creative Assembly games may be used.

## Map structure

Region (e.g. *Anatolia*) → State (e.g. *Karaman*) → Province (e.g. *Konya*).
Provinces are the unit of ownership, sieges and movement. Province shapes
grow from their towns and stop at 73 major rivers, 20 mountain ridges and a
few hand-drawn frontier lines, so borders follow real geography. The random
"wobble" that keeps borders from looking too smooth is tied to fixed
latitudes and longitudes, so growing the map or changing its detail keeps
existing borders where they are. Borders
that run along a river are marked (crossing them will be slower and favour
the defender). A state can be
split between several owners. The map data lives in `data/map/` and is
turned into game files by `tools/mapgen/mapgen.py`.

## Time

- Calendar: 365-day years, no leap years (as in Paradox games).
- Speeds: paused + 5 speeds (0.5, 1, 2.5, 6, 20 days per real second).
- Controls: Space = pause, 1–5 = set speed, +/- = faster/slower.
- Tick order (fixed, deterministic):
  1. advance date
  2. daily systems: movement, supply, sieges, battles, combat
  3. monthly systems (1st of month): economy, population, estates, diplomacy AI
  4. yearly systems (1 January): long-term changes

## Systems

### Economy & pops (Phase 2, owner's choices)
- **62 goods** (EU5-like): food, luxuries, materials, animals, manufactured.
  Data in `data/economy/` → `tools/economy/econgen.py` → `economy1453.json`.
- **42 markets** at the start (Venice, Bruges, Cairo, Calicut...). Every
  province joins the market cheapest to reach (distance × terrain, sea is
  cheaper). New markets can grow from big towns later.
- **Supply and demand prices**: each month a price moves 25% toward
  base × √(demand/supply), kept within 0.2×–5× base.
- **Producers**: each province has a staple food (grain/rice/millet, yield by
  terrain), one trade good, fish on coasts (peasants and slaves work these),
  and 1–3 workshops worked by burghers (recipes with inputs; the first input
  is essential, others only slow work).
- **Needs by class** (`needs.txt`): peasants need staples, salt, meat,
  clothing, tools, drink; burghers and nobles want much more (wine, spices,
  silk, horses, jewellery...). Muslims don't buy wine/beer but buy coffee.
  Pop **satisfaction** (0–1) is the value-weighted share of needs met.
- Until trade routes (Phase 3), surplus flows to neighbouring markets in a
  simple exchange step; off-map goods (Spice Islands, China, Sahara gold,
  Siberian furs) arrive as imports at gateway markets.
- **Taxes**: 2.5% of farm/mine value, 3% of workshop profit go to the owner.
- Start-of-game yields are calibrated so world supply ≈ 1.15 × demand; the
  market runs 12 months before the start so prices settle.
- **Buildings** (`data/economy/buildings.txt`, `Economy/Buildings.swift`,
  `Systems/BuildingSystem.swift`): 33 types in four categories
  (production, trade and towns, religion and learning, military), levels
  1–5. Cost = ducats (+50% per level) plus materials bought from the
  province's market (they raise demand there next month). Build time in
  months (+25% per level). The state pays upkeep per level per year: 2% of
  the level-1 cost for trade and religion buildings, 1% for military (the
  first fort level is free); production buildings are run by their owners.
  Slots: 4 + 2 × development (+2 on the coast, +2 in a market town); each
  level uses one.
  Requirements: coast, matching trade good (mines need metal/stone...).
- **You build, pops work**: workshop buildings give 2,500 burgher jobs per
  level; if a province has fewer burghers (×0.7) than jobs, all its
  workshops run short-handed. Starting workshops come from `crafts.txt`;
  other starting buildings (universities, arsenals, market halls, temples,
  ports, forts) from `buildings_1453.txt` and simple rules.
- Temples show as Church/Mosque/Synagogue/Temple, colleges as
  University/Madrasa, by local faith.
- **AI**: each month a twelfth of computer countries consider their 8 most
  productive provinces and build the best tax return per ducat if it pays
  back within ~15 years and leaves 6 months of income in reserve.
- **Taxes by class** (budget window sliders, 0–2× normal): land taxes on
  peasants (60% of farm/mine value base), nobles (30%) and clergy (10%),
  burghers on workshop profits. Normal rates give 2.5% of land value and 3%
  of workshop profit. Above normal: −12% satisfaction per +1 level for that
  class; below normal: up to +5%.
- **Banks** (`data/economy/banks.txt`): 15 houses of 1453 (Medici, Casa di
  San Giorgio, Venetian banks, Hanseatic merchants, Galata, Karimi,
  Gujarati shroffs, Multani moneylenders...). Each has limited money and
  lends only in its regions (judged by the borrower's capital). Rate =
  base × (1 + debt / yearly income). Loans of 50–500 for 5 years; interest
  goes to the bank; due loans are repaid or rolled over.
- **Out of money**: the cheapest willing bank lends the shortfall; if none
  will, **bankruptcy**: debts cancelled (banks lose them), 5 years of no
  loans, income ×0.75, −15% satisfaction.
- **Debasement**: once (+3 months' income, +5% inflation) or ongoing
  (+20% income, +0.4% inflation a month). Inflation raises building costs
  (later army costs), angers burghers (−0.8 × inflation), nobles (−0.4×)
  and others (−0.2×); falls 0.15% a month when not debasing.
- AI repays loans when it has a reserve; never debases.

### Trade (Phase 3, owner's choices)
- **Routes are drawn by players** (trade window, or tap a good in a market's
  price list): a good, a source market, a destination market and an amount
  (10–100 units a year). The path through linked markets is found
  automatically (sea steps cheaper); it avoids markets closed to you.
- The 1453 world starts with ~50 historical routes owned by the countries
  that ran them (`data/economy/routes_1453.txt`): Venice's spices from
  Cairo and silk from Aleppo, the Karimi Red Sea trade, Hormuz, Calicut,
  Gujarati cloth, the Hansa's furs, wax, grain and salt, English and
  Castilian wool to Bruges...
- **Earning: merchants + tolls.** The route owner buys at the source price,
  pays transport (2% a sea step, 4% a land step) and tolls, and sells at
  the destination. Owners of market towns passed through collect tolls
  (normal 4%, high 10% of the goods' value).
- **Capacity**: each country has merchant capacity (40 + 30 per market town
  owned + market halls, ports, caravanserais, roads); a route uses
  units × base price × steps / 10. Each market link also carries a limited
  value a year (land 1,500, sea 3,000, raised by ports, roads, market halls
  and the new Caravanserai); overloaded links squeeze every route on them.
  War and pirates will cut links later.
- **Control**: embargo a country (its merchants can't trade in or pass
  your market towns) or close your markets to all foreigners.
- The old neighbour exchange stays as small-scale local trade.
- **AI**: a twelfth of computer countries each month open the most
  profitable route into their home market (≤ 5 markets long, ≤ 8 routes);
  routes losing money 6 months running are dropped.
- Markets map mode draws routes (gold = yours), widths by value.

### Diplomacy & war
- Opinions (-100 to +100), trust (0 to 100), relation slots (scaled by
  Diplomacy skill & Chancellery), Aggressive Expansion decay and punitive
  coalitions (forming at 50+ AE across 4+ outraged independent realms).
- Treaties: alliances, guarantees, non-aggression pacts, military access,
  truces (5–15 years scaled by peace cost), royal marriages and subjects.
- Casus belli (Reconquest, Claim, Holy War, Subjugation, Tribute, Coalition,
  Succession, No-CB), call-to-arms evaluations, war score (-100% to +100%
  from battles up to ±40%, province/capital occupation, ±25% ticking war
  goal), and multi-demand peace treaties (province cession, core return,
  war reparations, indemnities, vassalization, annul treaties, release
  nations).
- Multi-day alternating Fire & Shock battles with commander Martial rolls
  (`GameRandom`), terrain/river penalties, cavalry flanking, shattered
  retreat/stackwipe, unfortified province occupation, and wartime/diplomatic AI.

- **War AI** (`Systems/DiplomacyAISystem.swift`): idle wartime armies march
  to the nearest target by marching time (war goal first, then unoccupied
  enemy land, then their own occupied land), found in one path search;
  armies standing on enemy land they occupy, or on their own occupied land
  they are freeing, hold position. The stalemate white peace (48 months
  under 15% war score) counts months from 30 May 1453 at the earliest, so
  the wars already under way in 1453 do not end on the first monthly tick.
- **Army AI in peacetime** (`ArmySystem.runAI`): idle stacks standing in
  the same province merge, and new standing regiments join the army
  already in the capital instead of forming a new one.

### Sieges & forts (Phase 8)
- **Forts & Zone of Control** (`Systems/SiegeSystem.swift`): fort levels
  1–5 hold 1,000 garrison per level, recover garrison monthly when
  unbesieged, and project hostile Zone of Control into adjacent provinces
  so enemy armies cannot march past a fort without besieging it.
- **Sieges & storm assaults**: a siege needs at least 1,000 besiegers per
  fort level and advances in 30-day phases, rolling `GameRandom` modified
  by artillery, commander Martial, fort level, blockade and breaches
  (Supplies Holding, Food/Water Shortage, Defender Desertion, Disease
  Outbreak, Wall Breach, Surrender). Once breached, the besieger may order
  a costly **Storm Assault**; Phase 9 makes assaults playable.

### Save, load & first playable game (Phase 8)
- **Deterministic saves** (`Core/SaveGame.swift`): versioned JSON snapshots
  of the mutable `World`, date, tick count and exact `GameRandom` state.
- **Local storage & autosave**: named saves, Quick Save and one rotating
  autosave file, frequency monthly / 3 months / 6 months / yearly / never.
- **First playable UI**: nation picker over all 266 countries plus featured
  1453 powers, New Game / Load / Save / Switch Country menu, alerts row,
  10-year headless balance test.

### Speed (Phase 8.5 step 3e)
- Daily and monthly systems build per-country and per-province lookups
  once per call instead of scanning every province or army repeatedly.
  The `FingerprintTests` checksum (printed by the by-hand "profile" CI job)
  proved these give exactly the same world as before over two game years;
  the release tick went from about 5.7 to 3.9 ms per day on CI. The
  three AI changes above (one path search, merging, recruiting into the
  capital army) change the game and bring it to about 3.1 ms per day.

### Battles & tactical assaults (Phase 9)
- **Trigger & choice modal** (`Core/GameSession.swift`): when a human player's army meets a hostile army in the same province, or the player orders a **Storm Assault** on a breached fort, the campaign pauses and opens a choice modal (**Lead Battle in Person** or **Auto-Resolve** via `BattleSystem`). AI-vs-AI clashes remain auto-resolved.
- **Deterministic core** (`Packages/GezCore/Sources/GezCore/Battle/`): all battle and assault rules run in pure Swift using struct-of-arrays (`BattleUnitTable`) and `GameRandom` on a fixed **10 Hz** tick (`dt = 0.1 s`, speeds **Pause**, **0.5x**, **1x**, **2x**). Godot (`BattleView.gd`) only renders state and dispatches orders via `GezGodotBridge`. Angles and hill shapes use `Core/DetMath.swift` (atan2, sin, cos from +, −, ×, ÷ and √ only) instead of each platform's maths library, so the same orders give the same battle on Mac, Windows and Linux; `testBattleChecksumIsPrintedForCrossPlatformComparison` prints a `BATTLE_CHECKSUM` that must match in the three CI logs. When two of the player's battles start on the same day, both wait and are offered the choice in turn. **Pace** (owner, session 7): a battle led in person lasts about 2–4 minutes at 1x, so `BattleEngine.pace = 0.125` multiplies casualties per hit and melee fatigue, and ammunition is divided by it (archers and guns keep their share); wall damage is not scaled. `testBattleLastsMinutesNotSeconds` keeps a ~9,000-man battle between 1 and 7 minutes.
- **Battlefield generation** (`Battle/BattlefieldGenerator.swift`): deterministic `1200 × 800` arena generated from the province's real terrain, elevation contour hills, forest patches, and river border crossings (with fords), plus a pre-battle deployment zone per side (skipped when ambushed crossing a river).
- **Real-time orders, formations & stances** (`Battle/BattleCombat.swift`): click/tap or box selection, move, attack target, draw-path, drag-frontline, and retreat orders. Six formations scale movement and combat stats: **Line** (`1.0×`), **Column** (`1.35×` speed, `0.75×` attack, `0.78×` defence, `0.78×` march fatigue), **Wedge** (`1.14×` speed, `1.32×` attack, `0.90×` defence), **Square** (`0.36×` speed, `1.15×` defence, `0.45×` cavalry damage taken, `1.45×` artillery damage taken, `0.35×` flank morale penalty), **Wagon-Laager** (`0.18×` / `0.25×` speed, `1.45×` defence, `1.22×` ranged attack, `0.62×` ranged incoming, `0.40×` cavalry damage taken, `0.30×` flank morale penalty), and **Skirmish** (`1.20×` speed, `1.12×` ranged attack, `0.74×` ranged incoming, `0.70×` artillery damage taken). Five stances: **Hold**, **Advance**, **Charge** (`1.25×` engagement speed, `1.85×` march fatigue), **Volley / Hold Fire**, and **Retreat**.
- **Range, fatigue, flanking & morale**: base weapon ranges are **420** (artillery), **250** (longbowmen), **215** (archers), **190** (horse archers), **170** (handgunners), and **165** (war wagons), with limited ammunition. Marching accumulates fatigue (`0.018 * marchFatigueMultiplier * stanceMult * dt`) and melee adds `0.032 * dt`, reducing speed/combat effectiveness down to `0.60×–0.62×`. Flanking and rear hits amplify casualties and morale loss; units rout at morale `<= 0.15` and may rally above `0.38 × maxMorale`. Enemy AI (`BattleAI.swift`) deploys, holds favorable terrain early, flanks on wings, storms or defends forts, and retreats when heavily beaten.
- **Playable siege assaults** (`Battle/BattlefieldGenerator.swift`, `BattleCombat.swift`): fort layout scales with `fortLevel` (`1...6`) at curtain `x = 760` (`wallLeft = 740`, `wallRight = 784`): 4 towers (`340 + 170×lvl` HP), 2 walls (`260 + 140×lvl` HP, north wall `1.15×` at `lvl >= 4`), central gate (`180 + 110×lvl` HP), and inner keep (`x = 1050`, `520 + 200×lvl` HP, win capture zone `x = 965...1130`), with existing siege breaches opening the south wall and defenders on walls gaining `14 + 4×lvl` elevation bonus. Artillery bombards structures, infantry with **Ladders** scales walls at `0.40×` speed, infantry with a **Ram** breaches gates, and unequipped infantry funnels toward breaches to seize the keep.
- **Campaign write-back & result panel** (`Battle/BattleWriteBack.swift`): after victory or rout, exact surviving regiment headcounts and morale are written back in sorted `ArmyID` order (preserving reduced levy headcounts so disbanding returns only survivors to home province pops), war score uses the shared `BattleSystem.applyBattleWarScore` formula, stackwiped/beaten armies retreat or clean up, assault breaches and garrison strength persist, won assaults call `SiegeSystem.captureFort`, and commander fates roll via `GameRandom` (`45%`/`30%`/`25%` capture/kill/wound on stackwipe; `8%`/`8%`/`20%` on heavy defeat `lossRatio > 0.45`; `4%`/`12%` kill/wound on pyrrhic victory `lossRatio > 0.40`).

### People (pops)
- Every province's people are split into groups by **culture** (187, in
  families), **religion** (25, in six families), optional **sect** (Sunni
  schools of law, Hindu traditions) and **social class** (nobles, clergy,
  burghers, peasants, slaves).
- Provinces, states and countries show their mix as percentages.
- Sufi orders are present per province with a strength (the Safaviyya in
  Ardabil will matter politically).
- Population comes from 1453 estimates per region (202 million in total),
  spread over provinces by development and size.
- Pops feed the estates (Phase 5). Later: conversion, assimilation,
  migration, plague, unrest by unhappy groups.

### Characters (Phase 4, owner's choices)
- **Real people of 1453**: rulers, heirs, spouses, children and key figures
  (`data/characters/people_1453.txt` for rulers and courts: Mehmed II, Hunyadi,
  Skanderbeg, Vlad Dracula, Cosimo de' Medici, Zara Yaqob, Bahlul Lodi,
  Rana Kumbha...). Personal unions: one person can rule several countries
  (Ladislaus V: Hungary, Austria, Bohemia; Christian I: Denmark, Norway).
- **Gaps** (owner's rule): a country with no one recorded gets an invented
  ruler and an invented sibling heir; empty council seats get invented
  courtiers ("Isa of Silistra"). Invented people are flagged in the game.
  `tools/characters/chargen.py` builds `characters1453.json`.
- **CK-style traits and skills**: diplomacy, martial, stewardship,
  intrigue, learning (0–20); 28 traits (`traits.txt`) change skills and
  opinion (shared +10, opposite −15, family +20, faith −5/−20).
- **Life**: monthly deaths (adult risk roughly doubles every ten years;
  childhood is dangerous; sickly ×2), births to married women 16–42,
  children named from culture lists (often after a grandparent), inheriting
  a parent's trait half the time.
- **Succession laws** (`succession.txt`): primogeniture (sons, brothers,
  nephews, daughters, nearest of the dynasty), salic (France, Burgundy,
  Anjou, Lorraine: never women), seniority (steppe hordes, tribes),
  elective (republics, theocracies, Hungary, Bohemia, the Mamluks: ablest
  courtier). No heir at all: a relative is found or invented.
- **Council**: chancellor, marshal, steward, spymaster, court chaplain.
  Now: ruler stewardship ±1.5% tax per point from 5, steward ±1%
  (−15%…+25%); ruler learning/8 + chaplain learning/4 learning a year.
  Chancellor, marshal and spymaster matter from Phases 6–7.
- **Marriages**: you propose for unmarried members of your ruling family;
  refused for wrong age (<15 or >25 years apart), different faith family,
  or if a ruler/heir of a realm 2.5× bigger. Muslim men up to four wives.
  The wife joins her husband's court unless she rules. AI marries off its
  families each January (best realm first, else a local noble).
- **Whole real families** (owner: "fully like CK3"): parents (dead ones as
  ancestors), brothers, sisters, children and bastards are recorded where
  history knows them (`people_2_west.txt` … `people_5_south.txt`, ~560
  living real people and ~80 ancestors). Only gaps are invented.
- **Great vassals** (owner chose "real landed nobles"): real lords hold
  provinces for their liege (Hunyadi: Temesvár, Szörény, Szeben; Rožmberk:
  Budějovice; Olelko: Kiev; Ottoman march lords; Georgian princes...),
  about 75 provinces in all.
  - A vassal keeps 40% of his provinces' tax as private gold; the crown
    gets the rest (shown in the budget as "Kept by vassals").
  - Opinion of the liege: personal opinion of the ruler + 10, +15 same
    house, ± lasting favour (fades 1 a month), and −30 at the highest noble
    tax (+30 at none).
  - Below 0: discontent. Below −25: refuses all taxes. Below −50 with
    intrigue 8+: plots; 1% a month to strike. Success 30% ± 5% per point of
    intrigue over the spymaster's, +5% per 100 gold in bribes (5–60%); the
    ruler dies. If caught, the plotter loses all land.
  - Land passes to lawful sons (and their sons), then brothers and nephews,
    then daughters (not under Salic law), then bastard sons, else back to
    the crown. A vassal who becomes ruler merges his land into the crown.
  - The player grants crown provinces to courtiers (+40 favour) and can
    revoke them (−80 for the holder, −20 for every other vassal).
  - Vassal families marry local nobles each January so lines go on.
  - Open revolt with armies comes with Phase 6 (armies).
- **Chronicle**: inheritances, grants, refusals and plots are logged and
  shown in the Court window.

### Government, laws and estates (Phase 5, owner's choices)
Data in `data/government/` → `tools/government/govgen.py` →
`government1453.json`; code in `Government/Government.swift` and
`Systems/GovernmentSystem.swift`; Government window in the top bar.
- **Laws (EU5-style law areas)**: 11 areas: succession, crown authority,
  taxation, army, religious policy, trade, justice, peasants and land,
  towns, learning, coinage. Each has 2–4 options with trade-offs
  (`laws.txt`). Changing one costs a month's income and takes 6 months;
  only one change per area at a time. Changing succession costs 1
  stability. Some options need a government type (no primogeniture in a
  republic). Sound money forbids debasing.
- **Estates (core + regional)**: nobles, clergy, burghers and peasants
  everywhere; Janissaries (Ottomans), Mamluk emirs (Mamluks), Rajputs
  (Hindu nobles of Rajput cultures), Tribes (tribal cultures in tribal,
  steppe and listed Muslim realms) and Dhimmi (non-Muslims in Muslim
  realms, which they take from the other estates).
- **Power (from pops)**: raw power = thousands of people × weight (nobles
  30, clergy 25, Rajputs 30, burghers 5, tribes 3, dhimmi 0.6, peasants
  0.25) × (0.5 + contentment); Janissaries 12% and Mamluks 35% of the pop
  total; × (1 + power changes). The crown has its own share (monarchy 45%
  of the estates' total, theocracy 40, horde 35, republic 30, tribal 20,
  × crown-power changes). Shares add to 100%.
- **Loyalty** 0–100 heads 10% a month toward: 50 + laws and privileges +
  (contentment − 50%) × 40 + 3 per stability − 25 × power share − 20 per
  tax level above normal on their class − grudges. Loyal (60+) estates
  give bonuses, disloyal (<30) ones penalties scaled by their power.
  A disloyal (<20) estate with 35%+ power has a 5% monthly chance to
  seize its strongest missing privilege (−1 stability).
- **Privileges** (`privileges.txt`, 23): loyalty and power for the estate,
  plus effects; some pay or cost money once. Revoking: −1 stability and a
  grudge of 2× their loyalty, fading 3% a month.
- **Stability** −3…+3: each point ±3% tax, ±2 contentment, ±0.15 reform
  progress. Raising costs 2 months' income (min 25), +50% per point above
  0. Falls: ruler dies without an adult heir (−1), succession law change
  (−1), revoked privilege (−1), estate seizure (−1), bankruptcy (−2).
- **Reforms (a tree per government)**: 4 tiers costing 0/60/120/200
  progress; progress 0.4 a month + stability + laws. Some reforms change
  the government (tribal → kingdom/emirate, horde → settled khanate,
  theocracy → secular principality, republic → hereditary signore); the
  new type starts again at tier 1 and laws it does not allow fall back.
- **Effects reach**: tax (overall and per class), contentment by class and
  other faiths, merchant profit, vassal tax share and opinion, loan
  interest, building costs, learning, inflation. Manpower, levy size, army
  quality and fort defence are stored for Phase 6.
- **AI**: takes reforms (keeping its government unless tribal), raises
  stability below +1 when cheap, grants a privilege each January to a
  strong estate below 35 loyalty. AI does not change laws yet.
- Religions: see `Packages/GezCore/Sources/GezCore/Faith/Religion.swift`.

### Armies and logistics (Phase 6, owner's choices)
Data in `data/military/` → `tools/military/milgen.py` →
`military1453.json`; models in `Military/Military.swift`.
- **Three regiment origins**:
  - **Levies**: raised fast from a province's peasant, noble and tribal
    pops, shrinking the province's workforce while under arms and returning
    surviving soldiers to the pops when disbanded; casualties permanently
    reduce the pop.
  - **Standing professionals**: recruited from the national manpower pool
    (fed by population, barracks and government modifiers) for ducats plus
    market goods (`weapons`, `horses`, `gunpowder`, `cannons`, `camels`,
    `elephants`, `wood`) demanded from the recruiting province's market.
  - **Mercenaries**: hired for coin alone without using national manpower
    or local pops (higher recruitment cost and monthly upkeep).
- **15 unit types** (`data/military/units.txt`):
  - **5 core units** available everywhere: Footmen (`infantry`), Horsemen
    (`cavalry`), Archers (`archers`), Handgunners (`handgunners`) and
    Bombards (`artillery`, 500 men, slow pace 0.70, siege +2).
  - **10 historical 1453 regional units** unlocked by estate, government,
    culture, region or tag: `janissaries` (Janissaries estate),
    `mamluk_cavalry` (Mamluks estate), `rajput_cavalry` (Rajputs estate),
    `war_elephants` (Indian regions), `horse_archers` (steppe hordes and
    Tribes estate), `camel_riders` (Arab, Berber, Egyptian and Horn of
    Africa cultures), `gendarmes` (France, Burgundy, Provence, Lorraine,
    Brittany), `longbowmen` (England and Wales), `swiss_pikemen` (Swiss)
    and `war_wagons` (Hussite Bohemia and Jan Jiskra).
- **Starting armies on 30 May 1453** (`data/military/armies_1453.txt`):
  only historical standing forces and active campaign hosts start on the
  map (39 armies, 235 regiments, 225,000 troops — Mehmed II's victorious
  host at Constantinople with Janissaries and bombards, France's Compagnies
  d'Ordonnance under Dunois and Jean Bureau, Talbot in Gascony, Cairo's
  Royal Mamluks, Hunyadi's Banderium, Poděbrady's war wagons, Skanderbeg,
  Uzun Hasan, Jahan Shah, Bahlul Lodi, Kapilendra Deva, Rana Kumbha,
  Vijayanagara, Zara Yaqob...), while seasonal levies stay home at the
  plough until raised.
- **Commanders**: rulers, heirs, marshals, great vassals and courtiers can
  lead an army; their Martial skill speeds marches and strengthens combat.
- **Movement, supply & vassal revolts** (`Systems/ArmySystem.swift`):
  daily province-to-province marches scaled by real distance, terrain,
  river crossings (+35%), Paved Roads (−8% per level), commander Martial
  skill (+1.5% per point) and slowest unit speed; province supply limit
  from population, staple food output, terrain, ports and forts with
  monthly starvation/disease attrition (2–15%) and 10% monthly
  reinforcement in supplied friendly land; deeply disloyal (`opinion < −60`)
  or defiantly revoked great vassals raise their domain levies in open
  revolt.

### Navies and sea power

Pure-Swift naval simulation in `Packages/GezCore/Sources/GezCore/Navy/` and `Systems/Navy*.swift`, using struct-of-arrays (`FleetTable`, `ShipTable`) and deterministic `GameRandom`:

- **Ship classes (`data/navy/ships.txt`, `tools/navy/navgen.py` -> `navy1453.json`)**:
  - **4 core classes**: `cog` (transport, 1 regiment / 1,000 men, 90 hull, 2 cannons, 80 crew, 6 mo, 15d), `galley` (oared, +50% combat & +25% speed in inland seas: Mediterranean, Black Sea, Baltic, Red Sea; 80 hull, 4 cannons, 150 crew, 6 mo, 18d), `carrack` (heavy warship, 220 hull, 24 cannons, 250 crew, 12 mo, 50d), `light_ship` (`Caravel`, 100 hull, 8 cannons, 100 crew, 8 mo, 24d).
  - **4 regional ships**: `venetian_great_galley` (`VEN` / Venetian, 125 hull, 10 cannons), `ottoman_galley` (`TUR` / Turkish, 85 hull, 5 cannons, 5 mo), `dhow` (Indian Ocean / Arabian / Persian light ship), `ghurab` (Indian Ocean / Arabian heavy warship, 165 hull, 14 cannons).
- **Docks, shipbuilding & sailors (`Systems/NavySystem.swift`)**:
  - **Sailor pool**: `0.8%` of coastal peasant + burgher pops plus `250` per Shipyard / Docks level; refills from `0` to max over `60` months; monthly fleet upkeep scaled by `0.55`.
  - **Shipbuilding**: built only in un-occupied owned coastal provinces with Shipyard / Docks (1 concurrent ship per Docks level); draws ducats, national sailors (`maxCrew`), and market goods (`wood`, `naval_supplies`, `linen`/`wool_cloth`/`cotton_cloth`, `cannons`).
  - **Starting fleets on 30 May 1453** (`data/navy/fleets_1453.txt`): 28 historical squadrons (230 ships) across Ottomans (`hamza_bey`), Venice (`loredan_alvise`), Genoa, Aragon, Naples (`vilamari`), Portugal (`henry_nav`), Castile (`enriquez`), Hansa & Baltic, England, France (`bueil`), Rhodes, Mamluks, North Africa and the Indian Ocean.
- **Movement, supply & fleet AI (`Systems/NavyMovement.swift`, `Systems/NavyAI.swift`)**:
  - Daily sea-zone movement sped up by admiral Martial and inland galley speed (`1.25x`); open-sea attrition past naval supply range; friendly port repairs (`+15` hull / month) and crew reinforcement (`25%` maxCrew / month).
  - Wartime AI hunts weaker enemy fleets and blockades enemy ports; peacetime AI protects own coasts/trade and repairs in port.
- **Auto-resolved naval battles, blockades & straits (`Systems/NavyBattleSystem.swift`)**:
  - Multi-day auto-resolved engagements (Days 1–2 cannon phase, Day 3+ boarding phase) with `GameRandom` + admiral Martial dice rolls, `1.50x` inland galley effectiveness, `18%` capture chance when ships are disabled, retreated survivors heading to friendly port, and BattleSystem war score contribution.
  - **Blockades**: hostile fleets at sea remove the `-2` coastal-fort siege penalty, cut blockaded markets' sea-trade capacity by up to `75%`, and tick war score.
  - **Straits**: hostile fleets standing in a strait sea zone block enemy armies from crossing unless that army's side controls both shores.
- **Naval transport & amphibious landings (`Systems/NavyTransportSystem.swift`)**:
  - Armies embark onto friendly/allied Cogs in port (`1` transport ship per `1,000` men), sail aboard the fleet, disembark onto accessible or hostile coastal shores (`-2` amphibious combat penalty for recent landings), and are routed overseas by military AI when no same-landmass war target exists.

### Religion and culture (Phase 11, owner's choices)
Pure-Swift faith and culture systems in `Packages/GezCore/Sources/GezCore/Faith/` and `Systems/{FaithSystem,MovementSystem,CultureSystem}.swift`, using struct-of-arrays (`ProvinceTable` conversion/assimilation progress, `religiousUnrest`, `devastation`, `famine`, `lastNetMigration`; `CountryTable.prestige`, `primaryCulture`, `acceptedCultures`) and deterministic `GameRandom`:

- **Conversion & missionaries (`FaithSystem.swift`)**:
  - Monthly pop conversion fraction is `(passive + missionary) * clergyFactor * templeFactor * familyFactor`, capped at `0.25/month`, where `basePassiveConversionRate = 0.0005` (`0.05%/mo`) and `missionaryConversionBonus = 0.012` (`1.20%/mo`, costing `0.50` ducats/mo).
  - Multipliers: **Faith law** (`orthodoxy` passive `1.6x` / missionary `1.25x`; `tolerance` `0.6x` / `0.9x`; `open` `0.2x` / `0.5x`), **Clergy loyalty** `0.5 + loyalty/100` (`0.5x` to `1.5x`), **Temples** `+35%` per level (`templeConversionBonusPerLevel = 0.35`), and **same religion family** `1.25x` vs `0.85x` across families.
  - **Blocks & slowdowns**: Muslim owners with non-Muslim pops are completely blocked by the Dhimmi `millet` privilege and slowed (`0.5x`/`0.55x` passive, `0.7x`/`0.75x` missionary) by `own_courts` / `lower_jizya`; Catholic ↔ Hussite conversion is blocked while `hussiteCompactsActive` holds.
  - Missionary cap: `1` base slot, `+1` at `≥ 180` total development, `+1` under `orthodoxy` law.
- **Religious unrest (`FaithSystem.swift`)**: stored as `0...100` per province (`religiousUnrest`) for Phase 12 rebels, converging at `0.25/month` toward a target driven by non-state pop share, `orthodoxy`/`tolerance`/`open` law modifiers, Dhimmi privilege relief, and recent conquest/conversion.
- **Faiths (Phase 20.7, owner's choice: granular)**: besides the 1453 set,
  Mahayana Buddhist (Dharmic family), Confucian, Daoist and Shinto (a new
  East Asian family), and the old traditions split by region (Pagan family):
  West African, Bantu, East African (Waaqeffanna of the Oromo, Sidama, Kafa),
  Siberian shamanism, Austronesian and (mainland Southeast Asian) Highland
  traditions. Generic "folk" stays for Baltic, Uralic, Caucasian and Indian
  hill peoples. New cases are appended to `Religion` so older ones keep their
  place (history stores a religion's position). The Python generators share
  one list, `tools/faiths.py`.
- **Holy sites (`data/faith/holy_sites.txt` -> `tools/faith/faithgen.py` -> `faith1453.json`)**: 43 sacred sites (Rome, Konstantiniyye, Jerusalem, Mecca, Medina, Najaf/Kufa, Karbala/Hillah, Benares/Varanasi, Bodh Gaya, Aksum, etc.). Each unoccupied held site sacred to the state religion grants `+0.05/month` (`+0.6/yr`) prestige (decay `0.005/month`), `+3%` Clergy target loyalty (capped at `+12%`), and `-5%` stability-raising cost (capped at `-25%`).
- **Historical movements (`MovementSystem.swift`)**:
  - **Bohemia (1453+)**: Utraquist / Taborite question (`resolveHussiteQuestion`: uphold Basel Compacts, Taborite revival breaking the Compacts and adopting Hussite, or submit to Rome).
  - **Sufi orders & Safaviyya**: Sufi order influence grows across Muslim lands; Ardabil's Safaviyya advances through `growing -> militant (Qizilbash) -> triumphant (Safavid Twelver state)` from the late 15th/early 16th century via condition + date window + `GameRandom`.
  - **Reformation (`.protestant`, `.reformed`)**: Never triggers before `1500` (`minReformationYear = 1500`); Centres of Reformation appear probabilistically in the ~1517 window (and by ~1530 in Catholic realms with unsatisfied/low-Clergy-loyalty conditions) and spread to home provinces, adjacent neighbours, and trade-route partners.
- **Accepted cultures & assimilation (`CultureSystem.swift`)**:
  - Government rank (`Duchy` `<45` dev = `1` slot, `Kingdom` `45...124` dev = `2` slots, `Empire` `≥125` dev = `3` slots; subjects capped at `Duchy`) plus `accepted_cultures` modifiers from `faith`/`crown` laws determine accepted-culture slots.
  - Non-accepted cultures incur tax (`0.90` same family / `0.80` foreign), manpower (`0.80` / `0.50`), and pop satisfaction (`-0.04` / `-0.09`) penalties; revoking acceptance inflicts `-0.08` satisfaction on that culture.
  - **Slow assimilation**: up to `0.0025/month` (capped `0.05`) when state and province religions match, pop satisfaction is `≥ 0.55`, and adjacent provinces or the province itself holds the target culture.
- **Devastation, famine & pop-conserving migration (`CultureSystem.swift`)**: War (`siegeDevastationGain = 0.08`, `battleDevastationGain = 0.05`, peacetime decay `0.025/mo`), heavy religious persecution, and staple-food shortfall push pops to relocate to neighbouring provinces and along active trade-route markets (`maxMonthlyMigrationRate = 0.12/mo`), conserving total world population bit-for-bit.

### Plague, famine and rebellion (Phase 12, owner's choices)
Written by Claude (session 10). State lives in `world.calamity`
(`Calamity/Calamity.swift`) and `world.unrest` (`Unrest/Unrest.swift`), both
saved; all three systems draw their dice from the calamities' own
`GameRandom` stream (split off the game's stream on the first month and
saved), so plague rolls do not reshuffle every other system's luck.

- **Diseases (`Systems/PlagueSystem.swift`, monthly)**: Plague, Camp fever
  (typhus) and Smallpox. An outbreak in a province runs a fixed course
  (9 / 6 / 7 months, slow start, peak in the middle) and strikes a share of
  the people: base 30% / 20% / 35% × crowding (0.35 at development 1 to
  1.25 at 10) × the share not immune × dice (0.6–1.4), at most 60%. Of the
  struck, 35% / 12% / 8% die, times class: nobles 0.5, clergy 0.85,
  burghers 0.9, peasants 1.0, slaves 1.25. Soldiers standing there die 1.5×
  as fast (never the last man), garrisons too.
  - **Where it starts**: plague 0.04% and smallpox 0.02% a month × dev/7 in
    crowded provinces (development 7+, or 5+ on the sea); camp fever 4% a
    month in a besieged province, 2% where 15,000+ soldiers camp, 0.4% in
    a famine above 40%.
  - **How it spreads** (each month, chance = min(cap, k × share struck)):
    to each neighbour (k 3, cap 12%, × 0.5–1.2 by the neighbour's
    development; camp fever half), along running trade routes from market
    town to market town (k 4, cap 20%), from port to port on the same sea
    (k 3, cap 12%, +25% per Port level), and with armies (an army that
    stood in a struck province carries it for 3 months: 50% a month to
    infect where it stands).
  - **Immunity**: after an outbreak the province counts as 75% immune; this
    fades 0.3% / 1% / 0.15% a month. A province can only be struck while at
    least 45% are not immune, so plague returns about every 9 years at the
    soonest and smallpox once a generation.
  - **Port Quarantine** (coastal provinces; 0.4 + 0.08 × development ducats
    a month): only 20% of sea-borne spread gets in or out; −15% tax there
    and the market's sea links carry half. **Cordon** (0.6 + 0.06 × dev a
    month): only 25% of land spread, nobody migrates in or out; −10% tax
    and marches through take 50% longer. The AI quarantines good ports
    (dev 6+) while plague is on their sea and cordons up to three struck
    provinces, when it has 40+ ducats and a monthly surplus.
  - Plague or smallpox in a capital can kill courtiers and rulers (chance
    0.12 × share struck a month, double from age 50).
  - People flee struck provinces (existing migration) unless cordoned.
  - Balance prototype: `tools/calamity/plague_prototype.py` (about 0.1% of
    the world dies of plague and smallpox in an average year, in local and
    regional waves; in the full game camp fever, armies and trade routes
    add to it. Read the `CALAMITY` line in the CI log after any change).
- **Harvests and famine (`Systems/FamineSystem.swift`, monthly)**: on
  1 August every region rolls its harvest (three dice: 1.0 on average,
  mostly ±0.10, limits 0.6–1.2) plus a small roll per state. A province's
  staple output is harvest × (1 − 8% for each harvest month, July to
  September, its levies stayed raised) × (1 − 50% × devastation) × 0.7 if
  besieged or occupied. Each market remembers the staple supply ÷ demand it
  is used to (a slow average, so desert markets that always import are not
  permanently starving); when supply falls below 90% of that, famine sets
  in (3 points per point of shortfall, worse where the local harvest
  failed, fading 15 points a month afterwards). Famine kills up to 0.2% of
  peasants a month (nobles 0.2×, clergy 0.4×, burghers 0.8×, slaves 1.3×),
  lowers contentment, raises unrest, breeds camp fever and feeds the
  existing migration.
- **Earthquakes (`Systems/QuakeSystem.swift`)**: 27 fault zones and 4 known
  earthquakes in `data/calamity/fault_zones.txt` →
  `tools/calamity/calamitygen.py` → `calamity1453.json` (provinces are
  stored by index: rerun after a map change). Each zone has a yearly chance
  (0.4%–4%; about one damaging quake somewhere every two years) and a
  strength. At the epicentre each building level falls with chance 45% ×
  strength, forts lose levels the same way (the last wall of a besieged
  fort stands), 3% × strength of the people die and devastation rises 25
  points × strength; neighbours feel half.
- **Unrest (`Systems/UnrestSystem.swift`)**: one number 0–100 per province
  that moves 30% of the way each month toward the sum of its causes:
  taxes (30 points per level above normal, weighted peasants 60% /
  burghers 20% / nobles 10% / clergy 10%; −12 per level below), religion
  (40% of Phase 11's religious unrest), foreign rule (14 for a foreign
  unaccepted culture, 6 for a kindred one, by share of people), disloyal
  estates (power × points below 30 loyalty × 1.2, at most 20), war damage
  (15 × devastation), famine (25 × famine), plague (up to 15), war
  weariness (0.25 per month at war, at most 12), stability and succession
  (4 per point below 0, −2 per point above; +5 child or no ruler, +2 no
  heir), unmet needs (30 per point of contentment below 60%); calmed by
  soldiers and forts (1.5 per 1,000 loyal soldiers + 1 per fort level, at
  most 12) and by recent settlements (fading 0.5 a month).
- **Rebel factions (`Systems/RebelSystem.swift`)**: one of each kind per
  country. Progress moves by (grievance − threshold) × rate a month (at
  most +2.5 / −3), slower when under 10% of the realm backs them, 0.3× in
  the quiet years after a rising, and less with soldiers among them.

  | Faction | Grievance | Threshold / rate | Who rises | Demand if they win |
  |---|---|---|---|---|
  | Peasant Rebels | taxes + famine + war damage + unmet needs + war weariness + plague | 10 / 0.20 | 3% of peasants | peasant tax capped at 50% for 5 years |
  | Religious Zealots | religious unrest of their faith's provinces | 26 / 0.08 | 4% of that faith | 40%+ of the realm: their faith becomes the state's; else no missionaries, less unrest, tolerant law |
  | Cultural Separatists | foreign rule + half the other grievances | 14 / 0.20 | 4% of that culture | their provinces go to a landless country with a core there, or of their culture, or a neighbour of their culture; else (or if over half the realm) their culture is accepted |
  | Estate Rebels | points below 30 loyalty × (0.5 + 2 × power) | 0 / 0.10 | 25% of nobles + 1.5% of peasants | the strongest privilege they lack (or 3 months' income) |
  | Pretender | −stability × 8, child ruler +10, no heir +4, his skill | 12 / 0.12 | 2% of peasants and nobles | the throne (a real adult man of the ruler's house; never invented) |

  At 100% they raise a real army (1,500–30,000 men, taken from those pops
  in their four angriest provinces like levies; survivors go home
  afterwards). Each month a crown army on their province fights them
  (same strength formula as vassal revolts). Unbeaten for 12 months, or 6
  after routing a royal army, they enforce their demand (−1 stability).
  One rising at a time per country; afterwards 5 quiet years.
  - **Answers**: *Concede* (a milder version: 75% tax cap for 3 years,
    toleration, acceptance, the privilege, or buying off the pretender for
    6 months' income; −3 prestige, 3 quiet years), *Send troops* (the
    strongest free army marches there) and *Lower taxes* (−25% on
    peasants).
  - **AI**: at 70% it sets a raised peasant tax back to normal; at 85% it
    sends troops if its army is twice what would rise, otherwise concedes;
    against a risen faction the army AI marches and raises levies, and it
    concedes after 3 months if it has under 60% of their numbers.
- **Screens (`godot/scripts/RebelsPanel.gd`, `MapCalamityLayer.gd`,
  `GezGodotCalamityBridge.swift`)**: Rebels button and window; Plague (P)
  and Unrest (L) map modes with markers; province People tab shows
  sickness, immunity, harvest, famine, Quarantine/Cordon buttons, unrest
  with every cause and rebel progress; alerts for plague, famine,
  earthquakes and rebels.

### Technology and institutions (Phase 13, owner's choices)
Three EU4-style technology tracks (**Administrative**, **Diplomatic**,
**Military**, levels **1–20**, starting in 1453 at levels **2–4**) plus four
historical institutions, all defined in plain-text tables in
`data/technology/` (`techgen.py` -> `technology1453.json`):
- **Starting levels in 1453**:
  - Wide spread **2–4** by region: Western/Italian/German/Anatolian-Balkan/Islamic
    core regions start at **3–4** (with specific 1453 leaders such as Venice,
    Florence, Genoa, Rome, Milan, Naples, Ottomans, Mamluks, Castile, Portugal,
    France, Burgundy, Austria, Timurids, Delhi, Gujarat, Bengal, etc. having
    country overrides up to 4 on their strengths); steppe nomads, Siberia, and
    remote tribal periphery start at **2**; government caps apply (`tribal` capped
    at level 2 except tribal hordes at level 3 MIL).
- **Monthly research & Focus**:
  - Per-track base **+0.50/mo**, matching ruler skill (**+0.25** per point:
    Stewardship/ADM, Diplomacy/DIP, Martial/MIL), matching council seat skill
    (**+0.20** per point: Steward/ADM, Chancellor/DIP, Marshal/MIL).
  - Shared learning pool: court Learning (`0.50 * CharacterSystem.learningPerYear`),
    unoccupied Colleges/Universities (`0.30 * level` sum), and capital market
    fulfillment of `paper` (`+0.60 * met`) and `books` (`+0.90 * met`), scaled
    by government education/learning laws and routed by **Focus**:
    - `balanced`: `1/3` to each track
    - `administrative` / `diplomatic` / `military`: `50%` to focus track,
      `25%` to each other track (AI chooses balanced or focuses behind/critical track,
      prioritising MIL during war).
  - Each embraced institution gives **+5% research speed** across all tracks.
- **Tech cost modifiers & advancement**:
  - Base cost per level: **600 points** (stepped per era).
  - **Neighbour bonus**: **−5%** cost per level a land/strait neighbour is ahead,
    capped at **−25%**.
  - **Ahead-of-time penalty**: **+10%** per year ahead of `target_year`, capped
    at **+200%**.
  - **Unembraced institution penalty**: **+1%** per year since each unembraced
    spawned institution appeared, capped at **+50%** per institution.
  - When `progress >= effectiveCost`, level advances automatically (excess carries over).
- **Track unlocks (1–20, EU4-style)**:
  - **Military**: progressive EU4 unit unlocks (26 unit types total across
    `data/military/units.txt`, keeping all 1453 starting regiments intact and
    gating only *new* recruitment), **Military Tactics** (`0.50` -> `2.20`),
    **Land Morale** bonuses (up to `+2.00`), and **Fort levels 2–5** (Lv 2 at
    MIL 4, Lv 3 at MIL 8, Lv 4 at MIL 12, Lv 5 at MIL 16; existing 1453 forts
    stay even if tech is lower).
  - **Diplomatic**: progressive EU4 ship unlocks (16 ship types total across
    `data/navy/ships.txt`, gating only *new* shipyard builds while keeping
    1453 ships), **Trade Range** expansion in market steps (`3` -> `50`),
    **Trade Efficiency** (up to `+38%`), and bonus **Diplomatic Relation** slots (up to `+2`).
  - **Administrative**: **Building Levels 4 and 5** unlocked at ADM 6 and ADM 12
    (never tearing down existing 1453 buildings), **Tax** and **Production Efficiency**
    (up to `+35%`), **Accepted Culture** slots (up to `+2`), **Reform Progress**
    (up to `+0.20`), and **Administrative Efficiency** from ADM 10+ (up to `+20%`,
    scaling peace-deal warscore cost downward).
- **Historical institutions (`data/technology/institutions.txt`)**:
  - **Renaissance** (1453): active across `Italy` at game start (Italian capitals start embraced).
  - **Printing Press** (1462): spawns on 1 Jan 1462 in `Mainz` (delayed from c. 1450 secrecy until the Sack of Mainz scattered printers).
  - **Global Trade** (1550): spawns dynamically in the highest-value coastal port market centre.
  - **Manufactories** (1600): spawns dynamically in the highest-industrialised workshop province.
  - Spread monthly via a dedicated `GameRandom` stream (`world.tech.rngState`): land/strait neighbours (halved across active war borders), active trade-route market centres, and literate `burghers`+`clergy` pop share × `books` supply × College/Bookmaker/Paper Mill buildings.
  - Countries with `>= 10%` of development reached (threshold `50%+` presence) can **Embrace** for **2 ducats per unreached dev** (min 20 ducats); AI embraces once >=35% of dev is reached and treasury covers 1.5x cost.
- **Screens (`godot/scripts/TechnologyPanel.gd`, `MapTechLayer.gd`, `GezGodotTechBridge.swift`)**:
  top-bar `Tech` button (`Tech X/Y/Z`) and Technology window (tracks, progress, gain sources, cost modifiers, next unlocks, Focus buttons, Institutions with Embrace controls), Institutions (`K`) map mode with origin markers, province People tab institution breakdown, tech & institution alerts, and headless snapshots after multi-year simulation (`godot_map_institutions.png`, `godot_technology_window.png`).

## Historical & Chronicle Events (Phase 14)

Condition-triggered narrative events with 2–4 player/AI choices (mission trees moved to a later phase, with conditions & effects kept reusable):

- **Data pipeline (`data/events/*.txt` → `tools/events/eventgen.py` → `events1453.json`)**:
  reproducible JSON generator validating every country tag, province name, character ID, trait key, estate, good/tech/institution key, condition, and effect (`Scenario1453.loadEvents()` indexes country-whitelisted vs global candidates on load).
- **Fixed reusable condition & effect vocabulary (`Packages/GezCore/Sources/GezCore/Events/Events.swift`, `EventSystem.swift`)**:
  - Conditions: `tag`, `not_tag`, `exists`, `not_exists`, `owns`, `not_owns`, `controls`, `province_owner`, `province_religion`, `at_war_with`, `at_war`, `religion`, `not_religion`, `religion_family`, `culture`, `culture_family`, `government`, `is_subject`, `is_vassal_of`, `adm_tech`, `dip_tech`, `mil_tech`, `institution_spawned`, `institution_embraced`, `institution_present`, `stability_min`/`max`, `treasury_min`/`max`, `is_coastal`, `has_flag`, `not_flag`, `global_flag`, `not_global_flag`, `ruler_alive`, `not_ruler_alive`, `character_alive`, `ruler_trait`, `ruler_skill_min`, `reformation_started`, `safaviyya_phase`, `year_min`/`max`.
  - Effects: `ducats`, `stability`, `prestige`, `estate_loyalty`, `unrest`, `pops_convert`, `add_claim`, `add_cb`, `spawn_units`, `set_flag`, `clear_flag`, `set_global_flag`, `clear_global_flag`, `add_modifier` (duration in months, applied in `GovernmentSystem`), `change_opinion`, `change_opinion_both`, `change_religion`, `accept_culture`, `manpower`, `sailors`, `tech_progress`, `kill_character`, `add_vassal_favour`, `province_dev`, `province_fort`, `institution_spread`, `spawn_reformation`, `advance_safaviyya`.
- **Monthly evaluation & own dice**:
  - Pre-filtered by country whitelist and `[date_from, date_to]` / `exact_date` with an `EventEvalContext` cache built once per month (`EventSystem.runMonthly`).
  - Uses dedicated saved RNG stream `world.events.rngState` (`world.beginEventRandom` / `endEventRandom`), never drawing from `Simulation.random`.
  - Exact-date events fire on the first monthly tick on or after `exact_date`; MTTH events use standard monthly probability $1 - 0.5^{1/(\text{mtth}\cdot\text{mult})}$ capped at `1.0`.
- **Player pop-up & AI choices**:
  - Player events enqueue in `world.events.pending` (`EventReport` alert pill `"Event: ..."`) and auto-pause `GameSession` unless `pauseOnEvents == false`.
  - AI picks weighted options asynchronously (`ai_weight` scaled by situation modifiers).
- **Historical & Chronicle events (70 total)**:
  - **66 historical events** across five handcrafted files (`01_iberia_west.txt`, `02_central_italy_nordic.txt`, `03_balkans_east_russia.txt`, `04_persia_india_africa.txt`): End of the Hundred Years' War, Peace of Lodi, Belgrade 1456 (+ Ottoman fallback), Ladislaus V 1457, Printing Press at Mainz, Skanderbeg, Trebizond 1461, Otranto 1480 (`Lecce`), Fall of Granada (war & conquered fallbacks), Columbus patron chain (`POR` → `CAS` → northern courts), Vasco da Gama at Calicut 1498, Safavid rise 1501 (`MovementSystem`), Babur at Kabul/Panipat, Luther's Ninety-Five Theses 1517 (`MovementSystem`), Diet of Worms, etc.
  - **4 chronicle event pop-ups** (`05_chronicle_events.txt`, triggered directly by systems): `chronicle_rebel_rising` (`RebelSystem`), `chronicle_vassal_plot_success` / `chronicle_vassal_plot_uncovered` (`VassalSystem`, suppressing duplicate death pop-up when poisoned), and `chronicle_ruler_death` (`CharacterSystem`).
- **Godot screens (`godot/scripts/EventPopup.gd`, `Main.gd`, `GezGodotEventBridge.swift`, `capture_snapshots.gd`)**:
  centered Event pop-up modal (category, date, title, wrapped narrative, optional `Locate` button, 2–4 option buttons with effect tooltips, `"Pause game on events"` toggle mirrored in Game Menu), collapsible `"Recent Events"` strip in the alerts area, and `godot_event_popup.png` snapshot.

## AI Behaviour Setting (Phase 15)

New-game setting (`AIBehaviourSetting`: `Historical` default vs `Free`), saved in `.gezsave` (`SaveSnapshot.ai`, defaulting old saves to `.historical`):

- **Data pipeline (`data/ai/goals_1453.txt` → `tools/ai/aigen.py` → `ai_goals1453.json`)**:
  157 ordered goals across 28 key 1453 country tags (`TUR`, `HUN`, `VEN`, `GEN`, `MLO`, `FLO`, `NAP`, `ARA`, `PAP`, `FRA`, `ENG`, `BUR`, `CAS`, `POR`, `HAB`, `AUS`, `POL`, `LIT`, `MOS`, `SER`, `BOS`, `WAL`, `MOL`, `ALB`, `MOE`, `TRE`, `MAM`, `KNI`). Each goal stores `id`, `type` (`conquer_province`, `defend_province`, `ally_with`, `vassalize`, `keep_peace_with`, `build_up`), `target`, `earliestDate`, `giveUpDate`, `priority`, and historical `note`.
- **Historical AI (`Systems/AIGoalSystem.swift`)**:
  - Follows the highest-priority feasible goal in `[earliestDate, giveUpDate]`.
  - Automatically completes achieved goals (e.g. `hun_belgrade_1456` upon `belgrade_1456_resolved` or passing `1457-06-01`, province conquests, alliances, vassalizations, build-up thresholds) and skips impossible goals (target gone, `date > giveUpDate`, bankrupt or potential strength `< 0.45x` target alliance, unreachable overseas).
  - Drives war declarations, peace priorities, alliance formation, non-aggression/restraint (`keep_peace_with`), defensive garrisoning/relief (`defend_province`), and army/economy build-up while still obeying strength, treasury, stability, and truce rules.
  - Falls back seamlessly to Free AI once a country's historical goal list runs out (or for countries without a list).
- **Free AI**:
  - Evaluates opportunities solely from live threats, weak neighbours, trade/development wealth, balance-of-power alliances, and ruler personality traits (`AIGoalSystem.traitProfile`, adjusting war willingness, strength thresholds, economy investment, diplomacy, and event choice weights) with no history script.
- **Godot UI (`Main.gd`, `DiplomacyPanel.gd`, `GezGodotBridge.swift`)**:
  Nation Picker `"AI behaviour"` selector (`Historical` / `Free`), active AI indicator in Game Menu, and `AI Goal:` line in the Country View (`DiplomacyPanel`).

## Architecture

| Layer | Tech | Notes |
|---|---|---|
| Simulation (`Packages/GezCore`) | Pure Swift | No Apple-only frameworks. Fully unit-tested. Portable. |
| Screens (`godot/`) | Godot 4.7 + SwiftGodot | Main front-end from Phase 8.5: map shader, panels, input on Mac, Windows and Linux. GezCore loads as a GDExtension (`godot/swift`, `GezGodotBridge`). |
| Old app shell (`App/`) | SwiftUI | Apple-only; kept until the owner retires it. |
| Old map renderer | Metal | Province-ID texture + baked terrain texture + one shader for all map modes (ported to Godot's shading language). |
| Battle view | Metal or SpriteKit | Instanced 2D sprites for thousands of soldiers. |

Principles:
- **Data-oriented**: provinces and countries are stored as struct-of-arrays.
- **Deterministic**: all randomness comes from a seeded `GameRandom`, so the
  same save + inputs always gives the same result.
- **Simulation is separate from rendering**: the renderer only reads state.

## Art direction

The owner found the first flat-colour look ugly, so looks are a priority.

- **Map (now):** Metal renderer over a baked terrain picture made from real
  elevation (hill shading, biomes, rock and snow, sea depth, rivers).
  Country colours are a tint over the terrain, with soft coloured bands at
  country borders, animated water and a light paper grain.
- **Map (later):** the same shading on a 3D terrain mesh with a camera
  that tilts as you zoom in, then 3D cities, forts and armies.
- **Interface (Phase 20):** see "Interface and art (Phase 20)" below.
- **Battles:** fight or auto-resolve. 2D sprites or 3D models (free CC0
  medieval models exist); to be decided with the owner.
- Art can come from code, free asset packs, an artist, or an AI image
  pipeline (Gemini via a GitHub secret); see `docs/HANDOFF.md`.

## Milestones

See `docs/ROADMAP.md` for the agreed feature decisions and build order.

## Sound effects and breakdown tooltips (Phase 16)

- **Shared simulation breakdowns (`Packages/GezCore/Sources/GezCore/Core/Breakdowns.swift`)**: every major tooltip breakdown (`monthlyIncome`, `manpower`, `sailors`, `armyMorale`, `siege`, `stability`, `unrest`, `researchSpeed`, `techCost`, `relations`, `relationSlots`, `aiGoal`, `provinceSupply`, `warScore`) calls the exact helper functions shared with simulation ticks so tooltip figures never diverge from monthly/daily math.
- **Shared parchment tooltip panel (`godot/scripts/TooltipManager.gd`)**: singleton autoload on top canvas layer (`0.30s` hover delay, automatic viewport clamping, no off-screen clipping) intercepting `tooltip_text` and resolving live `@Callable` breakdown callbacks and canvas unit/fort hover tips.
- **Non-musical audio (`godot/scripts/AudioManager.gd`)**: strictly zero music or tonal instruments; three AudioServer buses (`UI`, `Effects`, `Ambience`) with saved sliders + Master Mute (`user://audio_settings.cfg`), capped concurrent voice pools (`MAX_UI_PLAYERS = 3`, `MAX_EFFECT_PLAYERS = 5`), per-cue cooldowns, pause-gating (`Effects` suppressed and `Ambience` faded when paused; `UI` remains responsive), and camera zoom/terrain ambience weighting via `getAmbienceContext`.

## Going 3D (Phase 17)

- **Map camera.** The game keeps its 2D camera state (zoom, offset) and
  builds a perspective camera from it (`godot/scripts/MapProjector.gd`,
  30° field of view): straight down up to 1.6× the whole-map zoom (exactly
  the old 2D picture), easing to a 52° tilt at 70% of the maximum zoom.
  Every 2D layer and every click converts through this one camera.
- **Terrain.** Height map at half the map size, 8-bit, stored as
  sqrt(height / 6,000 m); 6,000 m is drawn 34 map pixels high (strong
  exaggeration so relief reads when tilted). The terrain mesh has a cell
  every 6 map pixels; the shader lifts it and lights slopes only when
  tilted (the baked terrain picture already has hill shading).
- **Regional styles** (bridge, `GezGodotPhase17Bridge.swift`): Tibetan and
  Theravada → East Asian; Hindu and Jain → Indian (East Asian east of
  93°E); Tengri → Steppe; folk religions → Steppe north of 40°N, else
  Islamic; Muslims → Indian in India (66–93°E, 5–31.5°N), Steppe on steppe
  terrain north of 38°N, else Islamic; Eastern Christians and
  Zoroastrians → Islamic look; other Christians and Jews → European.
  Towns use the province's majority religion; armies, fleets and battle
  sides use their country's capital.
- **Towns.** Houses 1 + 0.65 × development (max 7); temple from
  development 4 (or capitals), market from 6, great building from 8 (or
  capitals from 5). Forts: level 2 tower, 3 strong tower, 4+ castle.
  Ports get a pier and a ship on the nearest water. Towns appear from zoom
  0.6 (development 5+ and capitals), 1.1 (3+) and 1.6 (all).
- **Units on the map.** One soldier per ~8,000 men (1–4) plus a standard
  in the owner's colour; steppe armies ride. Moving armies stand part-way
  to their next stop (days walked / days needed) and bob as they march.
  Fleets: 1–3 ships (1 per 6 ships) with sails in the owner's colour.
  Model size on screen grows slowly with zoom (9.5 × zoom^−0.38 map
  pixels per model unit; soldiers ×1.5, ships ×1.25).
- **Battle view.** One soldier per 60 men (max 40 per regiment) filling the
  regiment's rectangle; cavalry ride, ranged units carry bows (handguns in
  Europe), artillery are guns with crews. Walls stand 34 field units
  tall; breached walls become rubble. Rules, timings and results are the
  Phase 9 ones; the 3D view only reads the battle state.

## Interface and art (Phase 20)

The owner picked each look from mock-ups (session 13).

- **One shared Theme** (`godot/scripts/GezTheme.gd`, saved as
  `godot/assets/ui/gez_theme.tres`, the project's default theme): every
  plain Godot control gets the look with no per-panel styling. Windows
  are a gold rope frame with corner rosettes around a tooled-leather band
  and a parchment page; inner sections are thin gold "Card"s; titles are
  red cloth banners ("Title" variation); buttons are bevelled gold, tabs
  dark leather ("Tab"). Cinzel for titles and the top bar, EB Garamond for
  text. Text on parchment is dark ink; `GezStyle.ink()` darkens colours
  that older code chose for dark panels (keeping their hue).
- **Layout:** top bar of medallion + number (names and breakdowns on
  hover); the screens are a column of medallions down the left edge
  (`Main.add_side_button`); windows open right of it (`Main.add_window`).
  Map modes and zoom are medallions; alerts are glowing medallions centred
  under the top bar (red danger, amber attention, blue sea, green good news).
- **Icons:** goods in colour on gold roundels; buildings rendered from our
  3D models on gold-edged plaques, workshops with their good as a badge;
  trait wax seals stamped with the trait's initial and coloured by kind.
- **Portraits:** generated in the style of an illuminated manuscript (ink
  lines on gold leaf, arched gold frame), parts picked by culture family,
  religion, age, sex and rank, the variant by the person's id. A painting
  named after the person's id replaces it (29 rulers and captains of 1453).
- **Shields** by the capital's culture: heater (Latin Europe, and Catholic
  realms in Greek lands), round (Islamic world), lobed (India), tall oval
  (steppe), kite (Orthodox east), leaf (Africa), rounded square (East Asia).
- **Tooltips:** compact parchment cards, red heading, gains green, costs
  red, double rule above the total.
- **Motion:** windows unroll from the top in 0.16 s; medallions swell on
  hover and press in. Nothing runs while nothing moves.
- **Map:** country names in letter-spaced capitals curve along the
  country's shape (within ±40° of level). Zoomed out (below zoom 0.78), the
  map turns into a painted chart: parchment washed with the map colours,
  ink mountains, coast ripple lines, blank parchment for land outside the
  map, sea creatures, ships and a compass rose. Zoomed in: 3D forests.
- **Paintings** (the owner's, from `docs/ART_PROMPTS.md`, made in the free
  Gemini app): main menu and loading screen (Constantinople, 1453), 66
  event pictures, 29 portraits; stand-ins until they arrive. Dropping a
  picture in `godot/assets/paintings/<menu|events|portraits>/` is all it takes.


## Chronicle, Ledger & Map Timelapse (Phase 18)
- **Recording (`HistoryState`, `HistorySystem`)**:
  - New games initialize at 1453-05-30; legacy saves initialize at their loaded date and record from then on (`SaveGame.swift`).
  - Uses a dedicated deterministic RNG stream (`world.history.rngState`) so main simulation RNG and `FingerprintTests` are unaffected.
  - **Chronicle events (`ChronicleEventTable`)**: struct-of-arrays storing 15 event kinds (`warDeclared`, `warEnded`, `majorBattle` >= 2,000 men or >= 500 casualties, `navalBattle` >= 8 ships or >= 2 lost, `siegeCaptured`, `peaceTreaty`, `lawChanged`, `reformAdopted`, `plagueOutbreak`, `famine`, `rebellion`, `rulerCrowned`, `rulerDied`, `marriage`, `heirBorn`) with compact integer IDs and a `templateSeed`. Saved as one varint blob (date as a step from the previous event, IDs stored plus one, one byte for the text variant). `siegeCaptured` is recorded only for forts of level 2+ or a capital, so the book is not flooded by small forts.
  - **Regnal chapters (`RegnalChapterTable`)**: tracks each ruler's reign start/end dates per country so Chronicle entries are grouped into chapters by ruler.
  - **Prose templates (`data/chronicle/templates.txt` -> `chronicle_templates.json` via `tools/chronicle/chroniclegen.py`)**: 60 period-prose variants (4 per kind), rendered deterministically on demand by `ChronicleTemplateSet`.
  - **Yearly stats (`CountryStatsHistory`)**: struct-of-arrays recording population, monthly income (cents), army size, navy size, and packed tech levels once a year on 1 January for every active country; saved as each country's change from its previous year, so 400 years of recorded history stays well under 5 MB (test: `fourHundredYearSaveSize`).
  - **Map Timelapse (`TimelapseHistory`)**: delta-encoded yearly province owner and religion snapshots (baseline frame + yearly changed pairs), replayed on the live 3D map via `GezGodotPhase18Bridge` and `TimelapsePanel.gd`.
- **Godot screens**: `ChroniclePanel.gd` (regnal chapters, country filter, event-kind filter), `LedgerPanel.gd` (time-series comparison for player + up to 7 countries, religion & culture pie charts, world ledger table), and `TimelapsePanel.gd` (play, pause, 1x/2x/5x/10x speed, Political/Religion toggle, year scrubber), using plain Godot controls for the shared Phase 20 Theme. They open from the side column (`add_side_button`) inside `windows_layer` (`add_window`); the curved country names hide while the Timelapse shows an old year.
