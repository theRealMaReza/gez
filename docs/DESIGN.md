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

Europe, North Africa, the Horn of Africa, the Middle East, Central Asia up to
the modern China border, and the Indian subcontinent. Target: roughly
1,500–2,500 land provinces plus sea zones.

Map data is built from public-domain geography (e.g. Natural Earth). No data
or art from Paradox or Creative Assembly games may be used.

## Map structure

Region (e.g. *Anatolia*) → State (e.g. *Karaman*) → Province (e.g. *Konya*).
Provinces are the unit of ownership, sieges and movement. Province shapes
grow from their towns and stop at 73 major rivers, 20 mountain ridges and a
few hand-drawn frontier lines, so borders follow real geography. Borders
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
- **Interface (skipped for now by the owner):** period fonts, parchment panels with frames, icons,
  coats of arms, curved country names.
- **Battles:** fight or auto-resolve. 2D sprites or 3D models (free CC0
  medieval models exist); to be decided with the owner.
- Art can come from code, free asset packs, an artist, or an AI image
  pipeline (Gemini via a GitHub secret); see `docs/HANDOFF.md`.

## Milestones

See `docs/ROADMAP.md` for the agreed feature decisions and build order.
