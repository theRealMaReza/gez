# Gez roadmap

Agreed with the owner in session 2 (12 November 2026). Each phase builds on
the ones before it. Work top to bottom; inside a phase, follow the order
given. When a phase is finished, tick it here and update `docs/HANDOFF.md`.

Rules that apply to every phase: keep `GezCore` pure Swift and
deterministic (multiplayer depends on it), test every system, check visuals
via the `ci-snapshots` branch, and ask the owner multiple-choice questions
(recommended option first) when a design or history choice comes up.

## Build names

Decided by the owner on 13 November 2026 (session 6, on claude.ai).
- **Alpha** (the build after Phase 20.5, the balance and play-test pass): **"Kayser"**, after
  *Kayser-i Rûm* ("Caesar of Rome"), the title Mehmed II took in 1453.
- **Beta builds**: each iteration gets its own name; theme not chosen yet
  (ideas offered: years after 1453 such as Belgrade 1456, Granada 1492,
  Calicut 1498; market cities; rivers). Ask the owner when a beta comes.
- These are build names, not the store title. The game is still called Gez.

## Feature decisions (owner's picks)

| # | Feature | Decision |
|---|---|---|
| 1 | Interface art (fonts, parchment panels, icons) | **Last phase (Phase 20)**, EU-style gold frames, medallions, painted art (decided session 6) |
| 2 | Coats of arms | **Real 1453 arms/banners** from Wikimedia Commons (changed: generated ones were rejected) |
| 3 | 3D map (relief, tilting camera) | **After core gameplay** |
| 4 | Things on the map (cities, forts, ports, armies) | **2D icons first, 3D later** |
| 5 | Economy | **EU5-style goods and markets** |
| 6 | Trade | **Routes between markets** (Silk Road, spice routes, Hansa, Mediterranean) |
| 7 | Buildings | **Build time and cost** |
| 8 | Estates | **Tied to the pops** |
| 9 | Rulers | **Full CK-style characters** (courts, councils, relationships), **starting with the real people of 1453** |
| 10 | Government | **Laws + reforms** |
| 11 | Diplomacy | **Full** (alliances, marriages, guarantees, vassals, embargoes, opinions, coalitions) |
| 12 | War and peace | **EU-style casus belli, war score, peace treaties** |
| 13 | Armies | **Regiments by type and origin** (levies from pops, professionals, mercenaries, special units) |
| 14 | Logistics | **Supply limits, attrition, roads**; rivers and mountains slow movement |
| 15 | Battle look | **2D first, 3D later** |
| 16 | Battle controls | **Real-time with pause**, formations, touch and Pencil friendly |
| 17 | Sieges | **Map sieges plus playable assaults** in the battle view |
| 18 | Navies | **Fleets, sea zones, naval battles auto-resolved on the map**, blockades, transport |
| 19 | Religion | **Full system** (conversion, holy sites, heresies, Reformation, Safaviyya, Hussites) |
| 20 | Culture | **Assimilation and migration** |
| 21 | Plague and famine | **Spreading plague (trade routes, armies) and famine** |
| 22 | Rebellion | **Rebels from pops and estates** with real causes |
| 23 | Technology | **EU4-style tech levels** |
| 24 | Events | **Historical events with choices + country missions** |
| 25 | AI | **Setting in game setup: historical or free** |
| 26 | Saves | **Local saves only** (no iCloud) |
| 27 | Map size | **Split India first** (about 95 to about 250 provinces), then other thin areas if needed |
| 28 | Audio | **Sound effects and ambience only, no music or instruments** |
| 29 | Multiplayer | **Epic Online Services (EOS) with join codes** (changed session 6, replacing Game Center); own free server as backup. Host chooses per game what happens when someone fights a battle manually |
| 30 | Windows | **Yes, through Godot** (decided 14 Nov 2026): the screens move to Godot before Phase 9 (Phase 8.5); the Swift simulation stays |
| + | Help | **Tooltips only** (no guided tutorial) |
| + | Chronicle | **History book, graphs and timelapse near the end** |

## Plan for the remaining phases (owner, 16 Nov 2026)

Order: 14 events → 15 AI setting → 16 sound + tooltips → 17 3D →
18 chronicle → 20 art → **20.5 balance and play-test** (with the 1453
border fixes) → **alpha "Kayser"** → **20.7 Old World map** → **20.8
ruling systems and formables** → 21 mission trees and 19 multiplayer
(order of 20.7 and 20.8: owner, 22 Nov 2026).

| Phase | Who writes | Decisions |
|---|---|---|
| 14 Historical events | Gemini | Mission trees moved to 21 |
| 15 AI setting | Gemini | Historical AI uses a simple goal list per country until 21 |
| 16 Sound + tooltips | Gemini | Sounds from free CC0 libraries (Kenney, Sonniss GDC, freesound CC0); tooltip text now, styled cards in 20 |
| 17 3D ✅ | Claude | Built in Godot (not Metal); three parts: map, models, battles. Models from free CC0 kits (KayKit used; Quaternius and Kenney allowed) recoloured by region, plus simple models built in code; **no paid tools** |
| 18 Chronicle ✅ | Gemini | History is recorded from Phase 18 on (no early recording); timelapse covers games started after it |
| 20 Art | Claude (pipeline) | Frames, medallions, seals by our art script; building icons rendered from the 3D models; paintings (events, missions, portraits) made by the owner in the Gemini app from Claude's prompts. **No paid tools or per-image API costs** |
| 20.5 Balance and play-test | Claude | Long AI-only runs plus the owner's play-throughs; fix balance, speed and bugs before Kayser |
| 20.7 Old World map | Decide when it starts | After the alpha, before 21, so mission trees are written once for the final list of countries |
| 20.8 Ruling systems and formables | Decide when it starts | Before 21, so mission trees can lead into them (owner, 22 Nov 2026) |
| 21 Mission trees | Gemini | After the alpha, the Old World map, and ruling systems and formables |
| 19 Multiplayer | Claude | After the alpha; Epic Online Services (EOS) with join codes, as decided in session 6 |

Money: **no extra paid services** (owner, 16 Nov 2026); the owner already
pays for Claude and Gemini.

Platforms: **Mac and Windows only for now**; iPad not planned (needs
Apple's paid account).

## Build order

### Phase 0: Foundation ✅ (session 1)
Calendar and speeds, pure-Swift simulation, 1,189 provinces, borders along
rivers and mountains, 247 countries with tribes and subjects, cultures,
religions and pops with classes, Metal map with real terrain. See
`docs/HANDOFF.md`.

### Phase 1: Finish the map ✅ (session 3)
Everything later attaches to provinces and sea zones, so their shape must
be final first. Done: India split (1,373 provinces total), 79 sea zones
with straits and coasts, real coats of arms, town/capital/fort/port
icons (SwiftUI overlay for now; move to Metal or 3D models in Phase 17).
1. **Split India** into about 250 provinces (new towns in
   `data/map/provinces/08_india.txt`, states regrouped, pops re-split,
   population check). Then review Persia, Anatolia, the Maghreb and
   Central Asia for oversized provinces.
2. **Sea zones**: water split into named zones (Aegean, Adriatic, Black
   Sea, Bay of Bengal...), with adjacency to coastal provinces and ports.
   Needed by navies, trade and plague.
3. **Coats of arms**: real arms, banners and tamgas as used c.1453, from
   Wikimedia Commons (credited), shown in panels and the top bar. Rules and
   workflow in HANDOFF "Heraldry workflow". Done: 200 real, 9 invented (owner
   asked), 57 plain banners where nothing is known.
4. **2D map icons**: towns that grow with development, forts by level,
   ports, capitals; drawn by the Metal renderer.

### Phase 2: Economy ✅ (session 4)
Owner's choices: ~60 goods (EU5-like), supply-and-demand prices, "you build,
pops work", ducats + loans + debasement, ~40 markets that can grow,
needs by class, building slots limited by size and terrain.
Done: steps 1–3 (goods, markets, needs, prices, taxes, satisfaction; Goods
and Markets map modes; market panel) and step 4 buildings (owner: levels
1–5, months-to-years build time, ducats + goods, all four kinds).
and step 5 (owner: named banking houses, default with penalties, debasement
once and ongoing, tax sliders by class).
1. **Goods**: each province produces goods from its terrain and pops
   (grain, wine, wool, cloth, iron, salt, fish, timber, spices, silk,
   horses...). Data file of goods and where they come from.
2. **Markets**: market centres (Venice, Bruges, Constantinople, Cairo,
   Tabriz, Samarkand, Delhi, Calicut...), each with supply, demand and
   prices; provinces belong to a market.
3. **Pop needs and income**: pops buy goods; taxes come from pops by
   class; burghers drive trade.
4. **Buildings** with build time and cost (workshops, markets, temples,
   docks, roads, forts, barracks); each changes production or capacity.
5. **Budget screen**: income, expenses, loans.

### Phase 3: Trade routes ✅ (session 4)
Owner's choices: player-drawn routes (plus the historical 1453 routes),
merchants + tolls, capacity per route/link, embargoes and closed markets.
Merchants move goods between markets along land and sea routes (Silk Road,
spice route through the Red Sea and the Gulf, Hanseatic Baltic,
Mediterranean). Control of routes earns money. Needs sea zones (Phase 1).

### Phase 4: Characters and dynasties (CK-style) ✅ (session 4)
Owner's choices: real rulers, heirs, spouses and key figures; invented
sibling heirs (and rulers) where history records no one; CK-style traits
and skills; court, council and marriages (plots later). Done: all of steps
1–5. Owner then asked for whole real families ("fully like CK3") and real
landed great vassals: done (session 5), with tax shares, inheritance,
grant/revoke, tax refusal and murder plots. Vassal revolts with armies
wait for Phase 6.
1. **Real 1453 people** as starting data: rulers, heirs, spouses, key
   nobles and generals (Mehmed II, Hunyadi, Skanderbeg, Ladislaus,
   Frederick III, Charles VII, Zara Yaqob, Jahan Shah, Abu Sa'id,
   Bahlul Lodi, Rana Kumbha...). Record uncertain facts in
   `HISTORY_NOTES.md` and ask the owner.
2. **Characters**: traits, skills, age, health, death; dynasties and
   houses; marriages and children.
3. **Courts and councils**: chancellor, marshal, steward and so on, with
   effects.
4. **Relationships**: opinion, friends and rivals, plots (simple at first).
5. **Succession**: laws per government; regencies, pretenders, personal
   unions forming and breaking (the Ladislaus union should end at his
   death in 1457 unless the player changes history).

### Phase 5: Government, laws and estates ✅ (session 5)
Owner's choices: EU5-style law areas; core + regional estates; power,
loyalty and privileges; a reform tree per government type. Done: all
three steps plus stability. Cossacks left out (they appear after 1453).
1. **Laws** with trade-offs (tax, conscription, tolerance, succession).
2. **Government reforms** over time.
3. **Estates tied to pops**: nobles, clergy, burghers plus regional
   estates (Janissaries, Cossacks, Rajputs, Mamluks); power from pop size
   and wealth; loyalty and privileges.

### Phase 6: Armies and logistics ✅ (session 6)
Owner's choices: three regiment origins tied to pops and markets (levies from pops, standing professionals from national manpower + market goods, mercenaries for gold); 5 core unit types + 10 historical 1453 regional units; 39 historical standing armies on the map on 30 May 1453 led by real commanders; daily movement by distance/terrain/rivers/roads/unit speed, province supply & attrition, and open revolts by disloyal great vassals.
1. **Regiments by type and origin**: infantry, cavalry, archers,
   handgunners, artillery; levies raised from pops (reducing them),
   professionals, mercenaries; special units. ✅
2. **Army movement** along province neighbours; river crossings and
   mountains slow armies; roads speed them. ✅
3. **Supply and attrition**: supply limit from province population and
   farmland; disease and starvation. ✅
4. **Basic AI** for raising and moving armies. AI grows with every phase
   from here on. ✅

### Phase 7: Diplomacy, war and peace ✅
Owner's choices:
- **Diplomacy**: Full 1453 treaties (alliances, guarantees, non-aggression pacts, military access, truces), opinion & trust (-100 to +100), diplomatic relation slots (scaled by Diplomacy skill & Chancellery), Aggressive Expansion & coalitions (at 50+ AE with 4+ outraged countries), plus starting historical 1453 alliances and truces.
- **Casus belli & wars**: Full CBs (Province Claim, Reconquest, Holy War, Subjugation/Tribute, Throne Claim from royal marriage, Coalition punitive war, or No-CB with -2 stability & high AE), ticking war score up to ±25% for holding the war goal, ally/subject call-ins based on trust/opinion/debt/truces, plus active 30 May 1453 wars (e.g., final phase of the Hundred Years' War in Gascony, Thirteen Years' War / Prussian Confederation tension).
- **War score & peace treaties**: War score (-100% to +100% from battles up to ±40%, province/capital occupation, and ±25% ticking war goal) + multi-demand peace treaties up to 100% cost (cede provinces, return cores, ducat indemnity, war reparations of 10% income for 10 years, make vassal/tributary, annul treaties, or release nations), scaling truce length (5–15 years) and AE by peace cost.
- **Auto-resolved battles & occupation**: Multi-day alternating Fire (artillery, handgunners, archers) and Shock (infantry, cavalry, elephants) phases using real regiment stats, commander Martial rolls (`GameRandom`), terrain/river crossing penalties, cavalry flanking, morale & discipline; levy casualties permanently reduce home-province peasant/tribal pops; shattered retreat; short takeover for unfortified enemy provinces.
1. **Diplomacy**: alliances, royal marriages (linked to characters),
   guarantees, vassals and tributaries (already in data), embargoes,
   opinion and trust, coalitions against aggressive expanders. ✅
2. **Casus belli and war goals**: claims, holy wars, succession claims,
   rebellion support. ✅
3. **War score** from battles, sieges and occupation; **peace treaties**
   (provinces, money, subjects, release of nations). ✅
4. **Auto-resolved battles** on the map using the same unit stats the
   battle view will use. ✅

### Phase 8: Sieges and the first playable game ✅ (session 6; play-test with the owner next)
Owner's choices:
- **Sieges & forts**: Fort levels 1–5 project Zone of Control into adjacent friendly provinces (blocking hostile movement past the fort until besieged); 1,000 garrison per level and at least 1,000 besiegers required per level; monthly siege roll (-7 to +7+) modified by artillery/Bombards, commander Martial, naval blockade status, and wall breaches (supplies holding, food/water shortage, defender desertion, disease outbreak, wall breach, surrender); once breached, the besieger can order a high-casualty Storm Assault.
- **Local save, load & autosave**: Versioned deterministic snapshots of all mutable `World` state (including `GameRandom` seed state), stored locally in Application Support/Documents with manual named saves, quick-save, and a **single-file autosave** (overwriting/deleting the old autosave each time) with player-selectable frequency: **Monthly, Every 3 Months, Every 6 Months, Every Year, or Never**.
- **First playable milestone**: Full nation-picker & campaign loop (playable country selection on the map for any of the 266 countries + featured 1453 powers), tag-switching / New Game / Load Game menu, active alerts banner (at war, besieged provinces, disloyal estates/vassals, loans due, low stability, idle diplomats), and a 10-year headless balance test suite.
1. **Sieges on the map**: forts block movement and need sieges; time
   depends on fort level, artillery, supply and disease; starve or storm.
2. **Local save and load**, autosave.
3. **First playable milestone**: a complete game loop (economy, armies,
   war, peace, sieges) as any country. Play-test with the owner and fix
   balance before going on.

### Phase 8.5: Move the screens to Godot ✅ (session 7, PR #21)
Decided by the owner on 14 November 2026, before Phase 9, so the battle
view, 3D map and art pass are built once, in Godot. Godot 4.7 runs the
screens on Mac, Windows, Linux (and iPad later); the whole simulation
stays the existing Swift `GezCore`, loaded into Godot through SwiftGodot
(a GDExtension). The Apple app in `App/` keeps working until the Godot
version matches it; the owner decides when to retire it.
1. **Prepare GezCore.** ✅ Move player actions and queries out of
   `App/Shared/GameModel.swift` (Apple-only) into a pure-Swift
   `GameSession` in GezCore (start/load/save, speed and pause, recruit,
   build, declare war, offer peace, laws...), so both front-ends share
   them. Make resource loading work outside SwiftPM bundles (a settable
   data directory instead of only `Bundle.module`). Keep the macOS, Linux
   and Windows test jobs green.
2. **Proof of concept** in `godot/`: the 1453 world loaded through
   SwiftGodot, the political map (port `MapShaders.metal` to Godot's
   shading language, same textures and ID maps), pan and zoom, the top
   bar, pause and speeds. The owner checks look and speed on the Mac:
   go or no-go for the full port. ✅ Go (14 Nov 2026): the map looks
   right; it feels a bit sluggish, to tune later (step 3e).
3. **Port every screen**: province panel, map modes, army counters,
   budget, trade, court, government, armies, diplomacy, war and peace,
   sieges, game menu (new, load, save), nation picker, alerts. One pull
   request per part:
   a. Game menu (new, load, save), nation picker, province panel, map modes. ✅
   b. Armies: counters on the map, select, move, recruit, sieges. ✅
   c. Economy: budget, trade, buildings. ✅
   d. Court, government and laws (step 3d1); diplomacy, war and peace,
      alerts (step 3d2). ✅
   e. Speed: find and fix the sluggishness the owner noticed. ✅ Reuse the
      ideas in closed PR #15 (commit bd4221e on branch
      `gemini/phase8-balance-and-docs`): tick speed-ups and the fix that
      stops the 1453 wars from making peace on day 2.
   f. Map icons (towns, capitals, forts, ports) and coats of arms
      across the UI. ✅
4. **Builds**: Godot exports for Mac, Windows and Linux on CI, each started
   once to prove it loads the world; ✅ screenshot job pushes Godot
   captures to `ci-snapshots` (`godot/`); downloads on the website and
   itch.io stay separate (later).
5. **Retire `App/`** once the Godot version is at parity (owner decides).

### Phase 9: Battle view (2D, real-time with pause) ✅ (session 7, PR #22)
Owner's choices:
- **Battlefield & deployment**: "Lead Battle in Person" vs "Auto-Resolve" modal when the player's army fights or storms a breached fort; 2D battlefield generates elevation contours, woods, hills, and river crossings from the province's real terrain and border data, with a pre-battle Deployment Phase in each side's deployment zone (skipped if ambushed during a river crossing).
- **Tactical controls & formations**: Real-time with pause & speed controls (0.5x/1x/2x), drag-box or tap selection, draw-path / drag-frontline orders (touch, Apple Pencil, mouse & keyboard), formations (Line, Column, Wedge, Square/Wagon-Laager, Skirmish), tactical stances (Hold, Advance, Charge, Volley/Hold Fire, Retreat), plus directional flanking/rear morale penalties, fatigue, and ammunition tracking.
- **Playable siege assaults & write-back**: Fort assaults render walls, towers, gates, and pre-existing artillery breaches from the map siege; attackers can bombard walls/gates with artillery, send infantry with scaling ladders or battering rams, or storm through breaches to capture the inner keep; exact regiment survivors, morale, breaches, and levy pop losses feed directly back into the campaign `World`.
Built in one Gemini pull request (#22, parts A–D), reviewed by Claude. Owner's choice in review: a battle led in person lasts about 2–4 minutes at 1x.
- [x] 1. "Fight or auto-resolve" choice when armies meet (and on Storm Assault of breached forts).
- [x] 2. Battlefield from the real location's terrain (elevation, forest,
   river); deployment phase (skipped when ambushed at river crossing).
- [x] 3. Real-time control with pause and 0.5x/1x/2x speeds: select units, move, draw-path, drag-frontline, formations, charge,
   fire; morale, fatigue, ammunition, flanking, tactical AI; touch, Pencil, mouse and keyboard.
- [x] 4. **Playable siege assaults**: walls, towers, gate, keep, breaches, artillery bombardment, ladders, battering ram.
- [x] 5. Results feed back to the campaign map (survivors, morale, levy pops, commanders, war score, fort breaches/garrison/capture) with Battle Result summary panel.

### Phase 10: Navies ✅ (session 7, PR #23)
Owner's choices:
- **Ships, docks & 1453 fleets**: 4 core ship classes (Cogs for transport, Galleys for inland-sea oar combat in Med/Black Sea/Baltic/Red Sea, Carracks as heavy ocean warships, Light Ships/Caravels/Dhows for trade protection & scouting) + regional ships (Venetian Great Galleys, Ottoman galleys, Indian Ocean dhows and ghurabs via tech); built in coastal provinces with Docks using `timber`, `naval_supplies`, `cloth`, and `cannons`, drawing Sailors from coastal peasant/burgher pops, plus historical 30 May 1453 starting fleets.
- **Naval operations**: Multi-day auto-resolved naval battles (cannon fire & boarding phases, galley bonus in inland seas, admiral Martial rolls, ship capture chance), port blockades (removing the -2 coastal fort siege penalty, cutting sea trade capacity, and adding war score), strait blocking (hostile fleets block enemy armies from crossing a strait unless they control both shores), and amphibious army transport (1 Cog/transport per 1,000 troops, with amphibious landing penalties in combat).
- [x] 1. **Ships, docks, sailors & 1453 fleets** (`data/navy/`, `tools/navy/navgen.py`, `navy1453.json`): 4 core classes + 4 regional ships, Docks shipbuilding with market goods, coastal pop sailors, and 28 starting fleets (230 ships) on 30 May 1453.
- [x] 2. **Fleets on the map & naval AI** (`NavyMovement.swift`, `NavyAI.swift`): daily sea-zone/port movement with admirals, supply/attrition at sea, port repairs, hunting enemy fleets, coastal patrol and blockades.
- [x] 3. **Auto-resolved naval battles, blockades & straits** (`NavyBattleSystem.swift`): cannon & boarding phases, inland-sea galley bonus, ship captures, war score, coastal siege & market sea-trade blockade effects, strait blocking.
- [x] 4. **Naval transport & Godot fleet UI** (`NavyTransportSystem.swift`, `FleetPanel.gd`, `MapFleetsLayer.gd`, `Main.gd`, `WarsPanel.gd`): 1 Cog per 1,000 men embarkation, amphibious landing penalty (`-2`), AI overseas transport, fleet map counters, fleet/docks/war breakdown UI and snapshots.

### Phase 11: Religion and culture in motion ✅ (session 9, PR #24)
Owner's choices:
- **Religion**: Pop-level missionary conversion over time (scaled by Clergy loyalty, temples, and Religious Tolerance laws; blocked by Dhimmi/Millet or Hussite Compacts privileges); Holy Sites (Rome, Constantinople, Jerusalem, Mecca, Medina, Najaf, Karbala, Varanasi, Bodh Gaya, Axum, etc.) granting prestige & clergy loyalty; dynamic historical movements (Hussite Utraquist/Taborite question in 1453 Bohemia, Sufi orders & Safaviyya Qizilbash rise in Ardabil/Persia, and the Protestant & Reformed Reformation from ~1517 with Centres of Reformation).
- **Culture**: Primary Culture plus Accepted Culture slots (scaled by government rank & laws; non-accepted cultures suffer tax, manpower, and satisfaction penalties); gradual pop assimilation when same-religion, well-satisfied, and adjacent to same-culture provinces; dynamic pop migration along neighbor provinces and trade routes driven by war devastation, religious persecution, famine, and plague.
- [x] 1. **Conversion, missionaries, unrest & holy sites** (`FaithSystem.swift`, `data/faith/holy_sites.txt`, `tools/faith/faithgen.py` -> `faith1453.json`): pop conversion driven by owner faith, Clergy loyalty, temples, and Faith law; blocked/slowed by Dhimmi privileges and Hussite Compacts; per-province `religiousUnrest`; 43 holy sites granting prestige, Clergy loyalty, and stability discount.
- [x] 2. **Historical movements** (`MovementSystem.swift`): Bohemia Hussite Utraquist/Taborite question (`BOH`), Sufi order growth & Ardabil Safaviyya -> Qizilbash -> Safavid rise, Protestant & Reformed Centres of Reformation (never before 1500, spreading across neighbors and trade routes).
- [x] 3. **Culture, assimilation & migration** (`CultureSystem.swift`): government-rank + law accepted-culture slots, tax/manpower/contentment penalties on unaccepted cultures (`MarketSystem` & `ArmySystem` wired), slow conditional assimilation, and devastation/persecution/famine-driven migration conserving total world population.
- [x] 4. **Godot screens & snapshots** (`ReligionPanel.gd`, `MapFaithLayer.gd`, `Main.gd`, `capture_snapshots.gd`): Religion & Culture window, Province People tab conversion/assimilation/unrest/missionary controls, Religion & Culture map mode overlays, and `godot_religion_window.png` / `godot_map_religion_1520.png` snapshots.

### Phase 12: Plague, famine and rebellion ✅ (session 10, PR #26, written by Claude)
Owner's choices:
- **Plague, famine & earthquakes**: Plagues (bubonic plague, typhus/camp fever, smallpox) ignite in crowded hubs or besieged camps and spread along active Trade Routes, Ports, and marching Armies, killing pops by class with local immunity recovery and Port Quarantine / Cordon responses; Famine triggers when staple food supply falls below pop need (from bad harvest rolls, war devastation, siege looting, or peasant levies kept raised during harvest); occasional Earthquakes strike historical fault zones (Anatolia, Aegean, Italy, Persia, Lisbon, Himalayas), damaging buildings and forts.
- **Rebellions**: Cause-driven rebel factions tied to real pops & estates (Peasant Rebels, Religious Zealots, Cultural Separatists, Noble/Estate Rebels, Dynasty Pretenders); at 100% progress they raise a real army on the map from those pops and enforce their political demands if victorious.
- [x] A. **Plague** (`Calamity/Calamity.swift`, `Systems/PlagueSystem.swift`): plague, camp fever and smallpox; outbreaks in crowded towns, ports, sieges and camps; spread by road, trade route, sea and marching armies; deaths by class; fading immunity; Port Quarantine and Cordon for player and AI.
- [x] B. **Famine and earthquakes** (`Systems/FamineSystem.swift`, `Systems/QuakeSystem.swift`, `data/calamity/fault_zones.txt` → `tools/calamity/calamitygen.py` → `calamity1453.json`): yearly harvest rolls, devastation, looting and levies at harvest, famine deaths; 27 fault zones and 4 known earthquakes damaging buildings and forts.
- [x] C. **Unrest and rebels** (`Unrest/Unrest.swift`, `Systems/UnrestSystem.swift`, `Systems/RebelSystem.swift`): unrest per province from real causes; Peasant Rebels, Religious Zealots, Cultural Separatists, Estate Rebels and Pretenders with progress, real armies from their pops, enforced demands, and concessions / troops / lower taxes for player and AI.
- [x] D. **Godot screens** (`RebelsPanel.gd`, `MapCalamityLayer.gd`, `GezGodotCalamityBridge.swift`): alerts, province panel section, Rebels window, Plague and Unrest map modes, `godot_rebels_window.png` and `godot_map_plague.png` snapshots.

### Phase 13: Technology ✅ (Phase 13 PR, written by Gemini)
Owner's choices: 3 EU4-style tech tracks (Administrative, Diplomatic, Military, levels 1–20 starting at levels 2–4 in 1453); monthly research from Ruler skills + Council seats + Learning + Paper/Books supply in the capital market + College/University buildings routed by Research Focus; EU4-style unlocks (unit & ship progression, Fort levels 2–5, Building levels 4–5, Trade Range/Efficiency, Administrative Efficiency, Tactics, Morale, Accepted Cultures & Diplomacy slots); −5% per level Neighbour Bonus; and 4 historical Institutions (Renaissance in Italy 1453, Printing Press at Mainz 1462, Global Trade 1550, Manufactories 1600) spreading along trade routes, neighbours, and literate burgher pops.
- [x] A. **Data, tracks & monthly research** (`data/technology/`, `tools/technology/techgen.py` → `technology1453.json`, `Technology/Technology.swift`, `Scenario/TechLoader.swift`, `Systems/TechSystem.swift`): 3 tracks × 20 levels, 1453 regional starting levels & country overrides, research focus, neighbour bonus, ahead-of-time penalty, AI focus, and optional `SaveSnapshot` state.
- [x] B. **Unlocks & AI gating** (`data/military/units.txt` via `milgen.py` → 26 units, `data/navy/ships.txt` via `navgen.py` → 16 ships, `BuildingSystem.swift`, `ArmySystem.swift`, `NavySystem.swift`, `MarketSystem.swift`, `PeaceTreaty.swift`, `Diplomacy.swift`, `CultureSystem.swift`, `GovernmentSystem.swift`): new recruitment/construction/fort/building/trade-range gating while keeping all 1453 starting armies, fleets, forts, and buildings intact.
- [x] C. **Historical institutions** (`Systems/InstitutionSystem.swift`): dedicated deterministic `GameRandom` stream (`world.tech.rngState`), historical & dynamic origins, neighbour/trade-route/burgher+books spread, embracing for ducats, and tech speed/cost modifiers.
- [x] D. **Godot screens & docs** (`godot/scripts/{TechnologyPanel,MapTechLayer}.gd`, `GezGodotTechBridge.swift`, `Main.gd`, `capture_snapshots.gd`): Technology window, Focus & Embrace controls, top-bar `Tech` button, Institutions (`K`) map mode, province People tab institution list, alerts, and `godot_technology_window.png` & `godot_map_institutions.png` snapshots.

### Phase 14: Historical events ✅ (historical events PR, written by Gemini; mission trees moved to Phase 21)
Owner's choices: Condition-triggered historical events with 2–4 choices (firing when historical conditions & date windows are met) plus interactive chronicle pop-ups for rebel risings, vassal murder plots, and ruler deaths. Mission trees were moved to a later phase, keeping event conditions and effects general and reusable.
- [x] A. **Event engine and data** (`data/events/*.txt` → `tools/events/eventgen.py` → `events1453.json`, `Events/Events.swift`, `Scenario/EventLoader.swift`, `Systems/EventSystem.swift`, `SaveGame.swift`, `GameSession.swift`): fixed reusable condition/effect vocabulary, monthly pre-filtered checks with `exact_date`/MTTH, dedicated saved RNG stream (`world.events.rngState`), optional `SaveSnapshot` state, AI weighted options, and `pauseOnEvents` setting.
- [x] B. **Historical & chronicle events** (`data/events/01..05_*.txt`, `CharacterSystem.swift`, `VassalSystem.swift`, `RebelSystem.swift`, `HISTORY_NOTES.md`): 66 real-date historical events with counterfactual fallbacks (Hundred Years' War, Belgrade 1456, Ladislaus 1457, Printing Press, Skanderbeg, Trebizond, Otranto, Fall of Granada, Columbus chain, Vasco da Gama, Safavids, Babur, Luther's Theses / Reformation, etc.) + 4 chronicle pop-up events.
- [x] C. **Godot screens, bridge & tests** (`godot/scripts/EventPopup.gd`, `Main.gd`, `GezGodotEventBridge.swift`, `capture_snapshots.gd`, `EventEngineTests.swift`, `HistoricalEventsTests.swift`, `GezGodotTests.swift`, `TenYearBalanceTests.swift`, `ProfileTests.swift`): modal event popup with effect tooltips & auto-pause toggle, alerts-area recent events strip, `godot_event_popup.png` snapshot, and full unit/determinism/save-load coverage.
- [ ] Mission trees: moved to **Phase 21** (owner, 16 Nov 2026: after 3D and the art pass); they reuse the Phase 14 condition/effect vocabulary.

### Phase 15: AI behaviour setting ✅ (Phase 15 PR, written by Gemini)
Owner's choices: Weighted AI goal & mission evaluation (never hard-scripted railroading): in **Historical AI** mode, AI countries prioritize their historical goals (a simple target list per country until the Phase 21 mission trees exist), traditional rivals/allies, and historically plausible event choices while still checking real army strength, treasury, and truces; in **Free AI** mode, AI countries evaluate all opportunities purely by strategic value, border weakness, trade wealth, and ruler personality traits.
- [x] **New-game setting & data pipeline** (`data/ai/goals_1453.txt` → `tools/ai/aigen.py` → `ai_goals1453.json`, `AI/AIGoals.swift`, `Scenario/AIGoalsLoader.swift`): "AI behaviour" option (`Historical` default vs `Free`), with 157 ordered goals across 28 key 1453 country tags (post-1453 Ottoman expansion, Hungary defending Belgrade in 1456 linked to `hist_belgrade_1456_hun`, European, Levantine, Balkan, and Russian powers).
- [x] **Historical & Free AI evaluation + save/load** (`Systems/AIGoalSystem.swift`, `DiplomacyAISystem.swift`, `BuildingSystem.swift`, `ArmySystem.swift`, `EventSystem.swift`, `SaveGame.swift`, `GameSession.swift`): goal completion, skipping impossible/expired/too-weak goals, fallback to Free AI when lists run out, Free situational/trait evaluation, and save/load compatibility (old saves default to Historical).
- [x] **Godot UI & tests** (`Main.gd`, `DiplomacyPanel.gd`, `GezGodotBridge.swift`, `AIGoalTests.swift`, `TenYearBalanceTests.swift`, `GezGodotTests.swift`): Nation Picker AI behaviour selector, Game Menu active AI indicator, Country View `AI Goal:` line, and unit/save-load/10-year headless tests for both settings.

### Phase 16: Sound effects and tooltips ✅ (Phase 16 PR, written by Gemini)
Owner's choices: Strictly zero music or musical instruments: procedural/recorded non-musical sound effects and environmental ambience only (UI parchment/wood clicks, coin clinks, marching boots, hoofbeats, hammer/construction, siege cannon thuds, sword/musket battle sounds, and camera-zoomed ocean/wind/city ambience) plus rich math-breakdown tooltips everywhere. (Per current Mac & Windows-only direction, tooltips use short-delay hover rather than iPad long-press.)
- [x] **Sound effects & ambience** (`tools/audio/make_sfx.py`, `godot/assets/audio/*.ogg` — 27 `.ogg` files, ~1.1 MB total from Kenney CC0 packs, OpenGameArt CC0, and filtered-noise procedural generation, `AudioManager.gd` autoload with `UI`, `Effects`, and `Ambience` buses, local settings in `user://audio_settings.cfg`, Game Menu sliders + Master Mute, voice limits/cooldowns, pause-gating, camera-zoom/terrain ambience mixing, and simulation + tactical battle sound cues; credited in `docs/CREDITS.md`).
- [x] **Math-breakdown tooltips everywhere** (`Packages/GezCore/Sources/GezCore/Core/Breakdowns.swift` sharing exact component helpers across `ArmySystem`, `NavySystem`, `SiegeSystem`, `GovernmentSystem`, `Diplomacy`, `Finance`, and `Breakdowns`; `GezGodotPhase16Bridge.swift`; shared parchment `TooltipManager.gd` autoload covering top bar, nation picker, province view, sea & market panels, budget, trade, court, government, diplomacy, wars, armies, fleets, religion/culture, rebels, technology, event popups, battle view, and map army counters; `BreakdownTests`, `SaveLoadTests` legacy check, and `GezGodotTests` verification).

### Phase 17: Going 3D ✅ (session 12, PRs #33–#34 on the old repo and #2 on the new one, written by Claude)
Owner's choices: built in **Godot** (not Metal), only free tools and CC0
models (KayKit, plus models built in code), fast on Mac and Windows.
- [x] 1. **3D map** (#33): terrain mesh lifted by the elevation data
   (`tools/terrain/bake_heightmap.py` → `App/Resources/Terrain/height.png`),
   painted by `godot/shaders/map3d.gdshader` (port of the 2D map shader:
   map modes, borders, water, selection). The camera looks straight down
   for the whole map and tilts smoothly to 52° as you zoom in
   (`MapProjector.gd`); labels, counters, routes, overlays and clicks go
   through the same camera.
- [x] 2. **3D cities, forts, ports and army figures** (#34) replacing the
   2D icons: towns grow with development, forts by level, piers and ships
   on the coast, capital flags, marching soldiers and riders, fleets; five
   regional styles (European, Islamic, Indian, East Asian, Steppe) from the
   recoloured KayKit kits mixed with models built in code
   (`tools/models/build_models.py` → `godot/assets/models/models.bin`,
   `MapModels.gd`).
- [x] 3. **3D battle view** (#35): 3D ground, soldier formations in each
   side's style, walls, towers, gate, keep, breaches, rams, ladders, guns
   and a siege camp (`BattleView3D.gd`); the Phase 9 rules and controls
   are unchanged (the 2D overlay sits on the tilted field).

### Phase 18: Chronicle and stats ✅
Owner's choices: Full regnal Chronicle book recording wars, major battles, peace treaties, laws, plagues, and dynastic events in period prose; a Ledger & Graphs screen comparing nations over time (population, GDP/income, army & navy size, technology, religion/culture pie charts); and an interactive Map Timelapse player recording yearly province-owner & religion snapshots from 1453 onward.
History book of the game (wars, rulers, borders), graphs, and a
world-history timelapse.

### Phase 19: Multiplayer (on hold for now, per the owner)
Owner's choice (session 6): **Epic Online Services (EOS)**, not Game
Center. Game Center only works for App Store apps and needs Apple's
$99/year account; EOS is free, works with the free website download, and
covers Mac, iPad and a possible Windows version.
1. **EOS peer-to-peer**: players sign in anonymously per device (EOS
   Connect device ID, no Epic account); EOS does NAT punching and falls
   back to Epic's relays. Lockstep sync of player orders (the simulation
   is deterministic).
2. **Join codes** instead of friend lists: the host opens an EOS lobby,
   Gez shows a short code (like `KZ7-QM4`), friends type it to join.
3. Host picks per game what happens when a player fights a battle
   manually (pause with a time limit, auto-resolve only, or watch).
4. Owner's one-time setup: free Epic developer account, a "Gez" product,
   download the EOS SDK, store the product IDs as GitHub secrets (never in
   chat). The website needs a short privacy policy mentioning Epic.
5. **Backups**: if Epic's terms change, our own small relay on a free host
   (Cloudflare Durable Objects first; Oracle or Google Cloud free VMs);
   free local Wi-Fi play between nearby devices as a bonus.
Note: the iPad version still needs Apple's paid account to install at all.

### Phase 20: Interface and art (the EU look) ✅ (session 13, PRs #4–#11 and part 9, written by Claude)
Owner's choices (session 13, from mock-ups): leather-bordered windows with
a parchment page; top bar of medallion + number with the screens in a
column of medallions down the left edge; goods in colour on gold roundels;
manuscript-style generated portraits; all seven shield shapes; compact
tooltip cards; main menu on a parchment panel at the left.
- [x] 1. **Style kit** (#4): one shared Theme (`godot/scripts/GezTheme.gd`
   → `godot/assets/ui/gez_theme.tres`, the project's default theme) and
   helpers (`GezStyle.gd`); gold rope frames with rosettes, tooled leather
   bar and side column, parchment pages, red cloth banners, gold buttons,
   leather tabs, medallions with engraved icons, wax seals for traits;
   Cinzel and EB Garamond. All art by `tools/uiart/ui_art_concept.py --kit`.
- [x] 2. **Goods and building icons** (#5): 62 goods drawn by the art script;
   34 buildings rendered from our 3D models (`render_building_icons.gd`).
- [x] 3. **Portraits** (#6): layered manuscript-style generator
   (`Portrait.gd`, parts from `tools/uiart/portrait_art.py`); the owner's
   paintings in `godot/assets/paintings/portraits/<id>.png` replace them.
- [x] 4. **Shields by culture** (#7): heater, round, lobed, tall oval, kite,
   leaf, rounded square, each in a gold rim.
- [x] 5. **Alerts row** (#8): glowing medallions under the top bar.
- [x] 6. **Rich tooltips** (#9): compact parchment cards.
- [x] 7. **Motion** (#10): windows unroll, medallions swell and press in.
- [x] 8. **Map polish** (#11): curved country names, painted-chart look when
   zoomed out (parchment, ink mountains, coast ripples, terra incognita,
   sea creatures, compass rose), forests.
- [x] 9. **Main menu, loading screen, event paintings**: stand-ins until the
   owner's paintings arrive; prompts in `docs/ART_PROMPTS.md`, pictures go
   in `godot/assets/paintings/{menu,events,portraits}/`.

After Phase 20: the **alpha build "Kayser"** (see "Build names" above).

### Phase 20.5: Balance and play-test (Claude)
Added by the owner on 16 Nov 2026. Long AI-only runs (balance lines in
the CI logs), the owner's own play-throughs on the Mac, then fixes to
balance, speed and bugs. Then the alpha build "Kayser".

Also in 20.5 (owner, 22 Nov 2026): the **1453 border and vassal fixes on
the current map** from Part I of `docs/MAP_EXPANSION_RESEARCH.md` (Metz,
Besançon, Basel as imperial cities; Further Austria under Albert VI;
Swiss associates; Yemen split between Rasulids and Tahirids; Irish
lordships; Malatesta, Pomerania and others). Data edits only; read that
document's "Review notes" first.

### Phase 20.7: The Old World map (after Kayser, before 21)
Decided by the owner on 22 Nov 2026. Grow the map to all of Afro-Eurasia
(East Asia, Southeast Asia, Siberia, Africa south of the Sahara,
Madagascar) and add detail inside today's map, as planned in
`docs/MAP_EXPANSION_RESEARCH.md` (Parts II–IV and its review notes).
Open questions to settle at the start: map detail (48 or 40 pixels per
degree; measure memory on an 8 GB M1 and texture limits on Windows), and
what to do with Australia and New Guinea, which fall inside the map box.
Several pull requests per region, each green in CI on its own.

### Phase 20.8: Ruling systems and formables (after 20.7, before 21)
Decided by the owner on 22 Nov 2026, so mission trees can be built on
top of them. From Parts V–VIII of `docs/MAP_EXPANSION_RESEARCH.md`:
- **Own systems** where history had its own machinery: HRE (7 electors,
  Imperial Authority, Reichstag reforms, free imperial cities, religious
  leagues), Ashikaga Shogunate (shugo vassals, Ōnin War trigger), Ming
  Mandate of Heaven and the tributary order, Polish–Lithuanian Sejm and
  royal elections, steppe kurultai and Chinggisid legitimacy, Southeast
  Asian mandala tribute rings.
- **Data-driven flavour** (estates, privileges, reforms, events)
  everywhere else: Ottoman, Mamluk, Persianate, Indian, Italian, Russian,
  Iberian, Ethiopian, West African and others.
- **Formable nations:** historical, plausible alt-history and sandbox
  unions, done by transforming a country in place (name, colour, shield,
  reforms; the country list stays fixed so saves stay safe).
Decide at the start which systems come first and split into pull
requests.

### Phase 21: Mission trees
After the Old World map (20.7) and ruling systems and formables (20.8);
missions can lead into formables and the new systems. Moved here from Phase 14 by the owner (16 Nov 2026): after 3D (Phase 17)
and the art pass (Phase 20). Branching mission trees for major 1453 powers
(Ottomans, France, England, Castile, Portugal, Austria, Hungary, Venice,
Mamluks, Aq Qoyunlu/Persia, Timurids, Delhi, Vijayanagara) and regional
trees for all other nations, reusing the Phase 14 event conditions and
effects; the Phase 15 historical AI then follows them.

### Backlog (decide later)
- **Windows** version: decided, through Godot (Phase 8.5).
- Playable naval battles, iCloud saves, guided tutorial, music: not wanted
  for now.
