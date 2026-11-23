# Gez: handoff

Read this first, then `docs/ROADMAP.md` (the agreed plan), `docs/DESIGN.md`
(how every system works, with all numbers), `docs/HISTORY_NOTES.md` (history
judgment calls) and `CLAUDE.md` (rules). Lessons from past sessions and reviews are in
`docs/SESSION_LOG.md` (read only the part a task needs). This file says where the project
stands, how to work on it, and what to do next.

Last updated: Phase 18 (22 November 2026). Phases 0–18 and 20 are done; next is 20.5 (balance and play-test), then the alpha "Kayser"; mission trees remain in Phase 21. Phase 18 (Chronicle and stats) was built by Gemini in four PRs (#14–#17): `HistoryState.swift`, `HistorySystem.swift`, `ChronicleRenderer.swift`, `HistoryQueries.swift`, `data/chronicle/templates.txt` (`chronicle_templates.json` via `tools/chronicle/chroniclegen.py`), `GezGodotPhase18Bridge.swift`, and `godot/scripts/{ChroniclePanel,LedgerPanel,TimelapsePanel}.gd`; merged as #18 (squashed onto Phase 20, with review fixes). Next: Phase 20.5 (Claude).

How to test Phase 17 by hand on Mac:
1. `git pull`, `./godot/build_mac.sh`, Cmd+Q Godot, reopen the project.
2. Zoom in from the whole map: the map tilts smoothly and mountains stand up (Alps, Caucasus, Himalaya); labels, army counters and clicks still land on the right provinces.
3. Towns are 3D (bigger with development; mosques in the Islamic world, temples in India, pagodas in Tibet, yurts on the steppe), forts by level, ships at ports, flags on capitals; move an army and watch the soldiers march.
4. Lead a battle in person (and a storm assault): soldiers, walls, gate, keep, rams and ladders are 3D; all orders work as before.

## The owner

- Does **not** write code. Claude writes everything. Explain in plain
  language; keep replies short (they often read on a phone).
- Ask design and history questions as **multiple-choice questions** (2–4
  options, recommended first, marked "(Recommended)"), one topic at a time.
  The owner usually picks the recommended option but reads them all.
- Wants an **EU5-style grand strategy game** (pops, economy, estates,
  religion, government, diplomacy) with **Total War–style real-time battles
  and sieges**, on a **daily tick with pause and 5 speeds like EU4**, never
  turn-based. Before a battle: **fight it yourself or auto-resolve**.
- Characters should be **fully like CK3**: real people of 1453 with their
  real families; invent people **only** where history records no one.
- Platforms: **Mac and Windows only for now** (owner, 16 Nov 2026; iPad
  not planned). Originally Mac and iPad (owner has an M1 Mac and an M5 iPad).
  Swift / Xcode. **Windows might come later**, so keep `Packages/GezCore`
  pure Swift. **14 Nov: the owner decided to move the screens to Godot
  before Phase 9** (ROADMAP Phase 8.5); GezCore stays the simulation,
  loaded through SwiftGodot. CI tests GezCore on macOS, Linux and Windows.
- Start date: **30 May 1453**, the day after Mehmed II took Constantinople.
- Map: Europe, North Africa, Horn of Africa, Middle East, Central Asia to
  the modern China border, Indian subcontinent.
- **Graphics matter a lot.** A good-looking map now, built so it can become
  3D later (Phase 17). The EU-style interface and art pass is the **last
  phase (Phase 20)**; don't style panels before then unless asked.
- Wants historical uncertainties raised so they can decide; record them in
  `docs/HISTORY_NOTES.md`.
- No music or instruments ever (sound effects only, Phase 16). Saves are
  local only (no iCloud).
- **Build names**: the alpha (after Phase 20) is called **"Kayser"**; each
  beta gets its own name, theme still open. See ROADMAP "Build names".
- May use **Gemini** for art later. That needs a Gemini API key stored by
  the owner as a GitHub Actions secret (`GEMINI_API_KEY`). **Never ask for
  or paste the key in chat.** Not started.

## Where things stand

Everything below is built, tested on CI and visible in the app.

| Area | State |
|---|---|
| Simulation core | Pure-Swift package `Packages/GezCore`: 365-day calendar, EU4-style speeds, deterministic `GameRandom`, daily tick with monthly and yearly systems (order in `Simulation.swift`) |
| Map (Phase 1) | 1,373 provinces, 238 states, 36 regions, 266 countries (incl. tribes and subjects), 79 sea zones with straits; borders follow 72 rivers and 20 ridges; Metal renderer with real-elevation terrain, borders, water, icons for towns, capitals, forts and ports |
| People (pops) | 187 cultures, 25 religions with sects, Sufi orders, pops by class (nobles, clergy, burghers, peasants, slaves); 202 million people |
| Heraldry | Real 1453 arms and banners from Wikimedia Commons (200 real, 9 invented at the owner's request, 57 plain banners); see "Heraldry workflow" below |
| Economy (Phase 2) | 62 goods, 42 markets, supply-and-demand prices, class needs and contentment, 34 building types (levels 1–5, slots), taxes by class with sliders, 15 named banks, loans, debasement, inflation, bankruptcy |
| Trade (Phase 3) | Player-drawn and historical routes, merchants and tolls, route and link capacity, embargoes, closed markets, AI routes |
| Characters (Phase 4) | 2,244 people: 560 real living people of 1453 and 79 dead ancestors with their real families (parents, siblings, children, bastards); invented only where history is silent. CK-style traits and skills, councils, succession laws, births, deaths, marriages |
| Great vassals | Real lords hold 75 provinces (Hunyadi, Rožmberk, Olelko of Kiev, Ottoman march lords, Georgian princes...). They keep 40% of the tax, inherit by family law, can be granted or stripped of land, refuse taxes when unhappy and may plot to poison the ruler. Court chronicle logs it all |
| Government (Phase 5) | Stability −3…+3; 11 law areas with trade-offs (6 months to change); estates tied to pops (core four plus Janissaries, Mamluks, Rajputs, Tribes, Dhimmi) with power, loyalty and 23 privileges; a 4-tier reform tree per government type that can change the government |
| Armies & logistics (Phase 6) | 15 unit types (5 core + 10 regional 1453 units), 39 starting standing armies (235 regiments, 225,000 men), three origins (levies from pops, standing professionals from manpower + market goods, mercenaries for gold), daily province-to-province movement (distance, terrain, rivers, roads, unit speed, commander Martial), supply limit & monthly attrition/reinforcement, great vassal open revolts, military AI |
| Godot screens (Phase 8.5) | `godot/`: every Apple-app window, button, map mode, map icon and coat of arms (court, government, diplomacy, wars & peace, alerts, budget, trade, buildings, armies, game menu, nation picker); GezCore loaded through SwiftGodot (`godot/swift`, `GezGodotBridge`); exports for Mac, Windows and Linux on CI |
| Going 3D (Phase 17) | `godot/scripts/{MapProjector,Map3D,MapModels,ModelLibrary,BattleView3D}.gd`, `godot/shaders/{map3d,map_model}.gdshader`, `godot/assets/models/models.bin`: terrain mesh from the elevation with a camera that tilts as you zoom; 3D towns (grow with development), forts by level, ports with ships, capital flags, marching soldiers and riders, fleets, in five regional styles (KayKit CC0 kits recoloured + models built in code); 3D battlefield, soldier formations, walls and siege engines over the unchanged Phase 9 rules |
| Battle view (Phase 9) | `Packages/GezCore/Sources/GezCore/Battle/` + `godot/scripts/BattleView.gd`: choice modal (Lead Battle in Person / Auto-Resolve), reproducible terrain/hills/forest/river+ford battlefields, deployment + ambush skip, real-time 10 Hz fixed-step combat (Pause/0.5x/1x/2x), click/box/move/path/frontline/attack/retreat orders (touch/Pencil friendly), 6 formations, 5 stances, flanking/morale/routing/fatigue/ammo, tactical AI, playable fort siege assaults (walls/towers/gate/keep/breaches/ladders/ram), and deterministic write-back (survivors, levy pops, commanders, war score, fort capture) with result panel |
| Navies (Phase 10) | `Packages/GezCore/Sources/GezCore/Navy/`, `Systems/Navy*.swift`, `data/navy/` (`navy1453.json`), `godot/scripts/FleetPanel.gd` & `MapFleetsLayer.gd`: 4 core + 4 regional ship types, Docks shipbuilding with market goods, coastal pop sailors, 28 starting 1453 fleets (230 ships), daily sea movement/attrition/port repair, fleet AI, multi-day auto-resolved naval battles (cannon + boarding, inland galley bonus, capture, war score), blockades (siege & trade cuts), strait blocking, 1-Cog-per-1,000 amphibious transport (`-2` landing penalty) with AI usage, Godot counters/panels/alerts |
| Religion & culture (Phase 11) | `Packages/GezCore/Sources/GezCore/Faith/`, `Systems/{FaithSystem,MovementSystem,CultureSystem}.swift`, `data/faith/` (`faith1453.json`), `godot/scripts/{ReligionPanel,MapFaithLayer}.gd`: monthly conversion (Clergy loyalty, temples, Faith laws, Dhimmi/Compacts blocks), missionaries, `religiousUnrest`, 43 holy sites (prestige, Clergy loyalty, stab discount), Hussites (`BOH`), Safaviyya/Qizilbash, Protestant/Reformed Reformation (~1517+, trade-route Centres), accepted cultures (government rank + law slots, tax/manpower/mood multipliers), conditional assimilation, and pop-conserving migration across neighbors/trade routes; Godot Religion & Culture window + People tab + map overlays + 1520 snapshot |
| Plague, famine & rebels (Phase 12) | `Packages/GezCore/Sources/GezCore/{Calamity,Unrest}/`, `Systems/{PlagueSystem,FamineSystem,QuakeSystem,UnrestSystem,RebelSystem}.swift`, `data/calamity/fault_zones.txt` (`calamity1453.json`), `godot/scripts/{RebelsPanel,MapCalamityLayer}.gd`: plague, camp fever and smallpox (outbreaks in crowded towns, ports, sieges and camps; spread by road, trade route, sea and armies; deaths by class; fading immunity; Port Quarantine and Cordon), yearly harvests and famine, 27 fault zones + 4 known earthquakes, unrest 0–100 per province from eleven causes, five rebel factions per country that raise real armies from their pops and enforce demands, concessions / troops / lower taxes for player and AI; Godot Rebels window, Plague (P) and Unrest (L) map modes, province People tab section, alerts |
| Technology (Phase 13) | `Packages/GezCore/Sources/GezCore/Technology/`, `Systems/{TechSystem,InstitutionSystem}.swift`, `data/technology/` (`technology1453.json` via `techgen.py`), `godot/scripts/{TechnologyPanel,MapTechLayer}.gd`, `GezGodotTechBridge.swift`: 3 EU4-style tech tracks (Administrative, Diplomatic, Military, levels 1–20 starting 2–4 in 1453), monthly research from ruler + council + Learning + Colleges + Paper/Books routed by Research Focus, −5%/level Neighbour Bonus, ahead-of-time penalty, EU4-style unit/ship/fort/building/trade-range/admin-eff unlocks keeping 1453 starters intact, and 4 historical institutions (Renaissance 1453, Printing Press Mainz 1462, Global Trade 1550, Manufactories 1600) with dedicated RNG stream `world.tech.rngState`; Godot Technology window, Institutions (K) map mode, province panel institutions, alerts |
| Historical events (Phase 14) | `Packages/GezCore/Sources/GezCore/Events/`, `Systems/EventSystem.swift`, `Scenario/EventLoader.swift`, `data/events/*.txt` (`events1453.json` via `eventgen.py`), `godot/scripts/EventPopup.gd`, `GezGodotEventBridge.swift`: 66 condition-triggered historical events with 2–4 choices and counterfactual fallbacks + 4 interactive chronicle pop-up events (rebel risings, vassal murder plots, ruler deaths), fixed reusable condition/effect vocabulary for future missions, dedicated saved RNG stream `world.events.rngState`, AI weighted choices, `pauseOnEvents` setting, Godot modal event popup, and collapsible Recent Events list in the alerts area |
| AI behaviour setting (Phase 15) | `Packages/GezCore/Sources/GezCore/AI/AIGoals.swift`, `Scenario/AIGoalsLoader.swift`, `Systems/AIGoalSystem.swift`, `data/ai/goals_1453.txt` (`ai_goals1453.json` via `aigen.py`), `DiplomacyAISystem.swift`, `BuildingSystem.swift`, `ArmySystem.swift`, `EventSystem.swift`, `SaveGame.swift`, `GameSession.swift`, `godot/scripts/{Main,DiplomacyPanel}.gd`: New-game "AI behaviour" selector (`Historical` default vs `Free`); 157 historical goals across 28 key 1453 tags (incl. post-1453 Ottoman targets and Hungary defending Belgrade in 1456 linked to `hist_belgrade_1456_hun`), skipping impossible/expired/too-weak goals and falling back to Free AI when lists run out; Free AI driven by threats, weak neighbours, trade wealth, and ruler traits; full save/load with legacy save fallback to Historical; and Country View AI Goal line |
| Interface and art (Phase 20) | `godot/scripts/{GezTheme,GezStyle,Portrait,AlertsRow,Motion,MapChartLayer,TitleScreens}.gd`, `godot/assets/ui/` (made by `tools/uiart/`), `godot/assets/fonts/`: one shared Theme (gold frames, leather, parchment, banners, gold buttons, Cinzel / EB Garamond) set as the project default; top bar of medallions, screens in a medallion column on the left, glowing alert medallions; goods, building, trait, shield and portrait art; compact tooltip cards; unrolling windows; curved country names, painted-chart look zoomed out, forests; main menu and loading screen. The owner's paintings go in `godot/assets/paintings/` (`docs/ART_PROMPTS.md`) |
| App windows (old Apple app) | Top bar: treasury (Budget), Trade, Court, Stability (Government), Armies (manpower, field armies, commanders, levies, recruitment). Province panel tabs: Overview (holder, supply, levy, buildings), Economy, People. Market panel. Map modes Q–I; 2D army counters and marching arrows |
| Tests | GezCore simulation tests (incl. `StartingWarsTests`, `FingerprintTests`, `BattleEngineTests`, `FaithTests`, `CultureTests`, `PlagueTests`, `FamineTests`, `UnrestTests`, `TechnologyTests`, `AIGoalTests`, six long runs), GezGodot bridge tests (incl. Phase 9, Phase 11, Phase 12, Phase 13, Phase 14 & Phase 15 bridge tests), App snapshot tests; note `FingerprintTests` updates whenever economy/manpower/pop rules change |

Also built (Phases 7–8): diplomacy, war and peace, auto-resolved battles,
sieges, save/load and autosave, nation picker, alerts. Not started (later
phases): chronicle (Phase 18, Gemini, in progress), multiplayer (Phase 19), mission trees (Phase 21).

## What to do next

0. **Paintings**: the owner makes them in the Gemini app from
   `docs/ART_PROMPTS.md` and drops them in `godot/assets/paintings/`
   (or attaches them in a chat; Claude commits them). Nothing else to do.

1. **Owner play-test of Phases 15–17** on the Mac (steps above; Phase 15:
   Nation Picker `AI behaviour`, Diplomacy `AI Goal:` line; Phase 16:
   tooltips, sounds, Esc volume sliders). Check frame rate on the M1 when
   zoomed in over a busy area and in a big battle.
2. **Phase 20.5: Balance and play-test** (Claude): 1453 border fixes (#19), then long AI-only runs.
3. Follow-ups: the campaign still uses platform maths (`MarketModel.km`
   distances, `hypot` in the AI), which can differ between Mac, Windows and
   Linux; move it to `Core/DetMath.swift` before multiplayer (Phase 19),
   as the battle code already is. Touch/Pencil battle controls are untested
   (no iPad build of the Godot game yet). Army table slots are never reused; the Ottomans start over
   their relation-slot limit (6/5); two temporary branches
   (`claude/fingerprint-base`, `claude/fingerprint-speedonly`) can be
   deleted on GitHub (the workspace cannot delete branches); retire `App/`
   when the owner says so.

### New screens and the Phase 20 look (for Gemini and Claude)
- Build screens from **plain Godot controls**: `PanelContainer` is a
  window (frame, leather, parchment page), `theme_type_variation = "Card"`
  an inner section, `"Title"` a red banner label, `"Heading"` a red Cinzel
  heading, `"Tab"` a leather tab button. Don't override colours or
  styleboxes; text is ink by default.
- Add a window with `main.add_window(node)` (it then sits right of the
  side column) and its button with `main.add_side_button(key, title,
  summary, callable)`; keys with medallions ready: `chronicle`, `ledger`,
  `timelapse` (others in `MEDALLIONS`, `tools/uiart/ui_art_concept.py`).
- Helpers in `GezStyle.gd`: `medallion_button`, `close_button`, `title`,
  `good_icon`, `building_icon`, `trait_seal`, `painting`, `fs` (font size).
  Portraits: `Portrait.make(character_dict, size)`.
- Where things live since Phase 20.6 part 2 (Main.gd split, about 3,100
  lines now). Main.gd keeps the map, camera, input, selection, top bar,
  side column, game menu, nation picker and the window toggles. Split out:
  - `ProvinceDrawer.gd`: the province drawer (Overview, Economy, People
    tabs) and the sea-zone panel, bottom left.
  - `MarketPanel.gd`: the market window, bottom right.
  - `MapModeBar.gd`: the map-mode dock and the zoom buttons (bottom
    right). Since part 3 the dock is one medallion showing the current
    mode; clicking it opens a 4 x 3 grid of all 12 (`open_grid()`,
    `close_grid()`; owner's pick, 22 Nov 2026). The top right is free for
    the outliner. The map state (`current_map_mode`, `_select_map_mode`)
    stays in Main.
  - `Outliner.gd` (part 3b): the right-hand outliner, top right. Your
    armies, fleets, sieges (yours and enemy sieges of your forts) and
    building work (buildings and ships); a click selects the army or fleet
    (or the province) and centres the map there. Headings fold; the title
    medallion folds the whole list. Data: one bridge call,
    `getOutlinerData` (`GezGodotOutlinerBridge.swift`), polled twice a
    second and rebuilt only when it changes. The market stays its own
    window (owner, 22 Nov 2026).
  Each is a full-screen, click-through `Control` that Main adds and then
  calls `setup(main)`. The old names still work through Main, so other
  screens need no change: `_refresh_province_panel()`,
  `_refresh_sea_panel()`, `_open_market_panel(i)`,
  `_refresh_market_panel()`, `province_panel`, `sea_panel`,
  `market_panel`, `current_prov_tab`, `prov_show_build`,
  `map_mode_buttons`. New screens (the outliner, the dock) go in their own
  script the same way; in Main add only the few lines that create them.
- Small pictures inside a line of text (Phase 20.6): `GezStyle.glyph(key)`
  and `GezStyle.with_glyph(key, label)`; keys `heart`, `heart_broken`,
  `star`, and `battle_infantry` / `_cavalry` / `_ranged` / `_artillery`
  (made by `build_glyphs` in `tools/uiart/ui_art_concept.py`, last in
  `--kit` so older art never changes). Don't use text symbols (♥ ✗ ★).
- Map names are measured (`MapLabelsLayer._text_width`, cached); straight
  country names use Cinzel like the curved ones.
- Court (Phase 20.6, owner's pick A): relatives are the clickable names
  under the person, the heir is marked "· heir", "Back to <ruler>" returns.
  The old Ruling Family buttons are hidden (`_refresh_family_tree` unused).
- 3D models (Phase 20.6): `build_models.py` bakes ambient occlusion into
  vertex colours (`AO_MESHES`), puts town buildings and forts on a dark
  plinth (`with_plinth`), and stores a "may move" weight in colour alpha
  for flags and sails; `MapModels.material_for()` gives those a waving
  cloth material (`cloth_wave` in `map_model.gdshader`). Towns are capped
  by province area and by how far the province reaches on the id map
  (`town_radius_cap`, `_town_reach`).
- Battle view (Phase 20.6): figures `FIGURE_SIZE` / `MEN_PER_FIGURE` /
  `FIGURE_SPACING` in `BattleView3D.gd` (tune together so soldiers fill
  the rules' rectangle); horizon skirt + depth fog; smoke billboards
  (`battle_smoke.gdshader`, `makes_smoke()` from stance and ammo, gunpowder
  units in `GUN_KEYS`); in `BattleView.gd` the 3D overlay draws a thin
  ground outline and one label plate per regiment (`_draw_plates`, nudged
  so they never overlap). `BattleShowcase.gd` + `BattleView.show_state()`
  show a fixed battle without the bridge (CI shots and local checks).
- After changing `GezTheme.gd`, re-save the theme (HANDOFF pipeline table);
  `godot/tests/test_style_kit.gd` fails if it is stale.

### How Claude reviews Gemini's pull requests (owner's choice, 15 Nov 2026)
The owner found full reviews too slow (each CI round with the three game
builds takes ~40 min, the long simulations ~50 min). From Phase 11 on:
- **During review**, wait only for the fast jobs: Simulation tests (Linux,
  macOS, Windows) and Godot extension (macOS), ~10-15 min. Also do the
  checks that need no CI (headless Godot parse check, bridge-call names
  and argument counts, generators reproducible, code reading).
- **Merge** when those are green and the owner agrees.
- **After merging**, the push to `main` runs the Godot exports (which start
  the exported game), the screenshots and the long simulations. Check them
  then, and fix anything red directly on `main` or in a small follow-up PR.
- Still run the profile/fingerprint job by hand (~5 min) when a PR changes
  the daily or monthly tick, since speed regressions are easy to miss.

## Working with Gemini (from session 6)

The owner now has **Gemini write the code** and **Claude test and review
it**. Gemini's rules are in `GEMINI.md` (and the same text in `AGENTS.md`
for Jules): it works on `gemini/<topic>` branches and opens pull requests
into `main`; it never pushes to `main`.

When the owner asks Claude to test Gemini's work:
1. `gh pr list` and `gh pr view <n>` / `gh pr diff <n>`; check out the
   branch (`git fetch origin <branch> && git checkout <branch>`).
2. Wait for CI on the pull request (all jobs, including the three Godot
   exports, which take ~40 minutes) and read failing logs.
3. Check the rules: GezCore pure Swift, `GameRandom` only, struct-of-arrays,
   tests for every new system, regenerated data committed and
   reproducible (rerun the generator, expect no diff), resources listed
   in `Package.swift`, no `Gez.xcodeproj`, docs and HISTORY_NOTES updated.
4. Read the logic for bugs, and run quick balance checks in Python where
   numbers changed. Look at the `ci-snapshots` images for UI changes
   (Godot ones in its `godot/` folder). Snapshots come from `main` pushes;
   for a pull request, run `gh workflow run ci.yml --ref <branch>` (REST:
   `gh api -X POST repos/theRealMaReza/gez/actions/workflows/ci.yml/dispatches -f ref=<branch> -f 'inputs[only]=all'`):
   its Godot screenshots go to the `ci-snapshots-preview` branch, and it
   also runs the long simulations. `gh pr list/view/review` use GraphQL,
   which is blocked; use `gh api repos/.../pulls/<n>` (REST) instead.
   Also check that every `_call_bridge("name", [args])` in the GDScript
   matches an `@Callable` with the same number of arguments.
5. Report to the owner in plain language: works or not, what is wrong,
   and what to tell Gemini. Leave review comments on the pull request
   (`gh pr review <n> --comment -b "..."` or `--request-changes`).
6. Merge only when CI is green and the owner agrees
   (`gh pr merge <n> --squash`), then update `docs/STATUS.md` and mirror it to the
   Project if they changed.

### Old World region pull requests (for Gemini, Phase 20.7)

Part 1 (Claude, PR "Old World map foundation") grew the map to Afro-Eurasia
at 48 pixels per degree. The new land is placeholder wasteland; each region
pull request turns one block of it into real 1453 provinces and countries.
One region per pull request (for example "Japan", "Korea and Manchuria",
"Ming South China", "Mainland Southeast Asia", "Swahili coast and Zimbabwe"),
each green in CI on its own. History comes from
`docs/MAP_EXPANSION_RESEARCH.md` §3 (read its Review notes first).

**Files to fill (in this order)**
1. `data/map/countries.txt`: new tags (`TAG | Name | r g b | government |
   religion [| capital]`). Every country must own at least one province.
2. `data/map/provinces/1x_<region>.txt` (new file per region, numbered after
   `10_`): `# Region`, `@ State`, then `Province | lat lon | OWNER terrain
   development` (terrain letters f p h m w x d s). Wasteland seeds are
   `! Name | lat lon`; unknown land (blank parchment) is `? Name | lat lon`.
   Then **delete the placeholder seeds** in that area from
   `data/map/provinces/10_placeholder_old_world.txt` (keep any that should
   stay wasteland, e.g. the Gobi, Taklamakan, Kalahari, Siberian taiga).
   Province names must be unique across the whole map.
3. `data/map/population_1453.txt`: one line per new region (people).
4. `data/map/cultures.txt`: new cultures (`id | Name | family`); new families
   are fine (e.g. sinitic, japonic, koreanic, tai, austronesian, mande, yoruba).
5. `data/map/pops/1x_<region>.txt`: a mix for **every state**
   (`culture religion[.sect] share`), province overrides with `> Province`.
   Religions: `tools/faiths.py` (the new ones are mahayana, confucian,
   daoist, shinto, west_african, bantu, east_african, siberian,
   austronesian, highland). A new religion must be added to both
   `tools/faiths.py` and `Packages/GezCore/Sources/GezCore/Faith/Religion.swift`
   (append new cases at the end; also its colour, and the switches in
   `HistoryQueries.swift` and `GezGodotPhase17Bridge.swift`).
6. `data/map/subjects.txt` (vassals, tributaries: Ming's tributaries,
   Majapahit's vassals...), `data/map/barriers.txt` (rivers `~`, ridges `^`;
   the research lists the big ones), `data/map/lakes.txt` (Baikal,
   Victoria, Tanganyika, Malawi, Chad, Tonlé Sap are not drawn yet),
   `data/map/seas.txt` (the 59 Old World sea zones at the end are a rough
   first cut; move or split them, but **append** new ones at the end).
7. `data/economy/`: a market centre for the region in `markets.txt`;
   resources and starting buildings for big cities; and lower the
   matching off-map imports in `imports.txt` (Chinese silk, spices, gold)
   once those lands are on the map.
8. `data/characters/people_6_<region>.txt` (new file): rulers, heirs,
   spouses, children, great vassals (`holds:`) in the people format below.
   Real people of 1453 wherever history records them (Jingtai Emperor,
   King Danjong, Ashikaga Yoshimasa, Esen Taishi, Oba Ewuare...); invent
   only where no one is recorded, and list doubtful dates in
   `docs/HISTORY_NOTES.md`.
9. `data/government/laws_1453.txt`, `data/military/armies_1453.txt`,
   `data/navy/fleets_1453.txt`, `data/technology/starting_levels.txt`
   (a `region` line for each new region), `data/heraldry/choices.txt`
   (optional), `data/ai/goals_1453.txt` (optional).

**Generators, in order** (each stops with a clear message on a mistake;
commit everything they write):
`python3 tools/mapgen/mapgen.py --land /tmp/geo/land10m.geojson` (coastlines
once: `tools/mapgen/fetch_coastlines.sh /tmp/geo`; needs ~4 GB of memory,
70 s) → `econgen` → `chargen` → `govgen` → `milgen` → `navgen` → `dipgen`
→ `calamitygen` → `techgen` → `eventgen` → `aigen` → `faithgen` →
`chroniclegen` → `make_icon` → `python3 tools/terrain/bake_terrain.py`
(the terrain picture is coloured by each province's terrain type, so
rerun it for new provinces; 60 s, 1.4 GB) → `bake_heightmap.py` (only
changes when coast or lakes change). Elevation is already fetched for the
whole box.

**Check before opening the pull request**: `docs/map_preview.png` (new
provinces in place, no slivers), the mapgen notes ("very small
provinces", "provinces with no land neighbours", "seed moved ... onto
land"), and that rerunning every generator changes nothing.

**What CI checks**: the Swift tests read the generated files, so a region
PR is mostly checked by `OldWorldMapTests` (map box, unknown land, faiths),
`ProvinceIDMapTests` (every label point inside its province, sea map
matches), `GezCoreTests` (states, regions, sea zone links, majority
religions), `HeraldryTests` (tags in `choices.txt` exist), the event and AI
goal tests (names they use still exist), the Godot extension tests, the
three game exports and the map snapshots (look at `ci-snapshots`). The
province map can hold 8,190 provinces (the map colour texture is 8192
wide) and 65,533 in the file.

**Godot map code** (for anyone writing map layers): the camera's `zoom` is
screen pixels per map pixel, and the map is now 1.5 times finer than the
map the thresholds were tuned on. Compare thresholds with
`MapScale.look(map_zoom)` (in `godot/scripts/MapScale.gd`), and multiply
sizes given in map pixels by `MapScale.k`.

## Website (session 6)

Public site at https://yv28f5k922-dot.github.io (downloads live since
version 0.1, 14 Nov 2026; see "Releasing a download"), from the
separate public repo `yv28f5k922-dot/yv28f5k922-dot.github.io` (plain HTML,
no build; GitHub Pages deploys every push to `main`). Owner's choices:
free github.io address; Mac download free, iPad "later" (needs Apple's
$99/year account); no download until the first playable version (Phase 8);
the site never links to this repo, because the owner plans to make the game
repo **private near release** (watch CI minutes then: private repos get
about 2,000 free minutes a month and macOS counts 10x). Screenshots come
from `ci-snapshots`, with the yellow button placeholders painted over.
When a download exists: build an unsigned Mac app on CI, attach it to a
GitHub Release on the website repo, and add "how to open an app from an
unidentified developer" steps to the page.

### Releasing a download (from 14 Nov 2026)
The **website repo** has `.github/workflows/release.yml` ("Release", run
by hand with a version name; Claude can dispatch it). It takes the newest
CI run on this repo's `main` whose Mac, Windows and Linux Godot exports
all passed and publishes them as a Release of the website repo:
`Gez-Mac.zip`, `Gez-Windows.zip`, `Gez-Linux.tar.gz`. The site links to
`.../releases/latest/download/<file>`, so it never needs editing per
release. While this repo is public no secret is needed. **When it goes
private**, the owner adds a secret `GAME_TOKEN` to the website repo
(fine-grained, Actions: Read on this repo only; never in chat).
Builds are unsigned: Mac needs right-click > Open, Windows shows
SmartScreen (More info > Run anyway) until the Microsoft Store.

## How to work on it

### Limits of the cloud workspace
- **Cannot compile Swift** and has **no general internet**. It can reach
  PyPI, npm and GitHub (git, and the API through `gh` for this repository
  only; `gh api graphql` is blocked, use REST).
- **Verify everything through GitHub Actions** (`.github/workflows/ci.yml`),
  which runs on every push to `main`:
  - *Simulation tests (Linux)*: `swift:6.0` container. Fastest signal.
  - *Long simulation tests (Linux)*: the four decade-long simulations
    (`skipUnlessLongTests()`, env `GEZ_LONG_TESTS=1`); daily, on pushes to
    `main` and by hand, never on pull requests. Branch pushes no longer run
    CI by themselves (only pull requests and `main`).
  - *Simulation tests*: macOS arm64.
  - *Build Mac and iPad apps*: `macos-15-intel`.
  - *Render map snapshots*: macOS arm64 (needs Metal); force-pushes PNGs
    to the `ci-snapshots` branch.
  - arm64 Mac runners are sometimes unavailable for hours, and a newer push
    cancels older runs, so "cancelled" jobs are normal.
- Watching CI from the workspace: `tools/ci/status.sh <branch> --wait`
  (one call; prints pass/fail per job and only the error lines). By hand:
  ```sh
  gh api "repos/theRealMaReza/gez/actions/runs?head_sha=$(git rev-parse HEAD)" \
    --jq '.workflow_runs[] | "\(.id) \(.name) \(.status) \(.conclusion)"'
  gh api repos/theRealMaReza/gez/actions/runs/<run id>/jobs --jq '.jobs[] | "\(.id) \(.name) \(.conclusion)"'
  gh api repos/theRealMaReza/gez/actions/jobs/<job id>/logs | tail -100
  ```
- Push with `git -c push.negotiate=true push -q origin main` (plain push
  sometimes stalls). GitHub prints a "repository moved" note; harmless.
- **To see the app:** `git clone --depth 1 -b ci-snapshots
  https://github.com/theRealMaReza/gez /tmp/snap`, then open the PNGs
  (`screen_main.png`, `metal_*.png`, `budget.png`, `trade.png`,
  `court.png`, `government.png`, `market_venice.png`, `panel_*.png`...).
  Artifact downloads are blocked by the proxy; use the branch. Buttons and
  menus show as yellow placeholder boxes in snapshots (an `ImageRenderer`
  limit); they are fine in the real app.
- **Checking Godot scripts from the workspace:** GitHub release downloads
  work, so fetch `Godot_v4.7.2-stable_linux.x86_64.zip` from
  `github.com/godotengine/godot/releases`, then in `godot/` run
  `--headless --import` once and `--headless --check-only --script
  scripts/Main.gd`. "GDExtension not found" errors are expected (no Linux
  build of the Swift extension); any `SCRIPT ERROR: Parse Error` is real.
- **Godot script tests and local renders:** `godot --headless --path godot
  --script res://tests/run_tests.gd` (no Swift extension needed). 3D
  renders work here too: `LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0
  1440x900x24" godot --rendering-driver opengl3 --path godot --script
  <scene script>` and save `root.get_viewport().get_texture().get_image()`.
  **PR screenshots:** `gh workflow run ci.yml --ref <branch>` publishes
  them to the `ci-snapshots-preview` branch.
- **Anything needing internet** runs as a GitHub Actions job that commits
  its output (`terrain.yml` fetches elevation, `heraldry.yml` fetches arms).

### When the owner's Mac is linked
Install Xcode and Homebrew, then `brew install xcodegen`, `xcodegen
generate`, open `Gez.xcodeproj`. Schemes: `GezMac`, `GeziPad` (signing team is
set in `project.yml`), `GezMacTests`. Never commit `Gez.xcodeproj`.

### Data pipelines (hand-written text → generated JSON)
Edit the text files, run the generator, commit both. Every generator
validates its input and exits with a clear message on mistakes, and all
of them are reproducible (same input, byte-identical output).

| Data | Generator | Output (in `Packages/GezCore/Sources/GezCore/Resources/` unless noted) |
|---|---|---|
| `data/map/` | `python3 tools/mapgen/mapgen.py --land /tmp/geo/land10m.geojson` (coastlines once: `tools/mapgen/fetch_coastlines.sh /tmp/geo`; `pip install numpy scipy pillow --break-system-packages`) | `scenario1453.json`, `provinces1453.idmap`, `seas1453.idmap`, `docs/map_preview.png` |
| terrain | `python3 tools/terrain/bake_terrain.py` (after mapgen; elevation comes from the "Fetch elevation" CI job: after a change of map box or detail, `gh api -X POST repos/theRealMaReza/gez/actions/workflows/terrain.yml/dispatches -f ref=<branch>`, which fetches, bakes terrain and height map and commits them to that branch) | `App/Resources/Terrain/terrain.jpg` |
| height map (3D map) | `python3 tools/terrain/bake_heightmap.py` (after mapgen or new elevation) | `App/Resources/Terrain/height.png` |
| 3D models | `python3 tools/models/build_models.py` (KayKit originals in `tools/models/kaykit/`; new kit models must be credited in `docs/CREDITS.md`) | `godot/assets/models/models.bin` |
| `data/economy/` | `python3 tools/economy/econgen.py` (balance with `tools/economy/prototype.py`, a Python copy of the monthly market; keep constants in step) | `economy1453.json` |
| `data/characters/` | `python3 tools/characters/chargen.py` | `characters1453.json` |
| `data/government/` | `python3 tools/government/govgen.py` | `government1453.json` |
| `data/military/` | `python3 tools/military/milgen.py` | `military1453.json` |
| `data/diplomacy/` | `python3 tools/diplomacy/dipgen.py` | `diplomacy1453.json` |
| `data/calamity/fault_zones.txt` | `python3 tools/calamity/calamitygen.py` (fault zones store province indices: rerun after any map change) | `calamity1453.json` |
| `data/technology/` | `python3 tools/technology/techgen.py` (stores Mainz index and regions: rerun after any map change) | `technology1453.json` |
| `data/events/` | `python3 tools/events/eventgen.py` (validates tags, provinces, characters, conditions & effects) | `events1453.json` |
| `data/ai/goals_1453.txt` | `python3 tools/ai/aigen.py` (validates tags, provinces, goal types, dates & priorities) | `ai_goals1453.json` |
| `data/heraldry/choices.txt` | push it; the Heraldry workflow downloads and converts | `App/Resources/Heraldry/arms_<TAG>.png`, `data/heraldry/credits.json` |
| interface art (Phase 20: frames, medallions, seals, goods icons) | `python3 tools/uiart/ui_art_concept.py --kit godot/assets/ui`, then (after changing `godot/scripts/GezTheme.gd`) `godot --headless --path godot --import` and `godot --headless --path godot --script res://tools/build_theme.gd` | `godot/assets/ui/`, `godot/assets/ui/gez_theme.tres` |
| building icons (Phase 20) | `python3 tools/models/build_models.py --icons`; `GEZ_ICON_MODELS=$PWD/tools/models/icon_models.bin GEZ_ICON_OUT=/tmp/bicons xvfb-run godot --rendering-driver opengl3 --path godot --script res://tools/render_building_icons.gd`; `python3 tools/uiart/ui_art_concept.py --buildings /tmp/bicons godot/assets/ui` (after `--kit`: workshops carry their good's icon) | `godot/assets/ui/buildings/` |
| app icon (portolan chart, drawn from the province map) | `python3 tools/icon/make_icon.py` | `App/Resources/Assets.xcassets/AppIcon.appiconset/`, `docs/icon_preview.png` |

Run order after a map change: mapgen → bake_terrain → econgen → chargen →
govgen → calamitygen (later ones read `scenario1453.json`). A new JSON resource must also
be listed in `Packages/GezCore/Package.swift`.

People file format (`data/characters/people_*.txt`): `role | id | Name |
Dynasty | m/f | born | relations | traits | note [| culture religion]`.
Roles: ruler, heir, spouse, child, sibling, parent, kin, figure, vassal,
dead, link. Relations: `f:` `m:` `s:` ids, `d:YYYY[-MM-DD]` death,
`illegit`, `holds:Prov1,Prov2` (underscores for spaces). `link | id |
...` adds relations to someone defined elsewhere. Notes with "?" are
uncertain and get listed in HISTORY_NOTES.

### Rules (also in CLAUDE.md)
- `GezCore` stays pure Swift (Foundation is fine; no SwiftUI, Metal, UIKit,
  AppKit or Combine).
- All randomness through `GameRandom`, so a game replays the same way.
- Bulk data as struct-of-arrays (`ProvinceTable`, `CountryTable`,
  `CharacterTable`, `Government`...).
- Every new system gets unit tests in `Packages/GezCore/Tests`.
- Never use Paradox or Creative Assembly data or art.
- Credit outside data in `docs/CREDITS.md`.
- Keep `docs/DESIGN.md` current when design changes; tick phases in
  `docs/ROADMAP.md`; update this file and `docs/STATUS.md` at the end of a session; mirror
  STATUS to the claude.ai Project (`claude/STATUS.md`; only that one, to
  keep every chat's start small).
- Commit messages end with the attribution lines from the session's
  system reminder.

## Key files

```
Packages/GezCore/Sources/GezCore/
  Simulation.swift   tick order (monthly: trade paths, market, buildings,
                     finance, AI, population, characters, vassals, government)
  Calendar/          GameDate, GameClock (speeds)
  Core/              GameRandom, IDs, MapInfo, RGB, Terrain, GovernmentType
  World/             World, ProvinceTable, StateTable, CountryTable, ProvinceIDMap
  Faith/, Population/  religions, cultures, pops, class split
  Economy/           Goods, Markets, Buildings, Finance, Trade, queries
  Characters/        CharacterTable, traits, names, chronicle
  Government/        Modifier, Effects, laws, estates, privileges, reforms
  Military/          UnitType, Regiment, ArmyTable, Military, Battle
  Diplomacy/         Treaty, War, CasusBelli, WarDeclaration, PeaceTreaty, coalitions, war reparations, opinions, trust, relation slots
  Systems/           MarketSystem (+ EconomySystem/PopulationSystem),
                     BuildingSystem, CharacterSystem, VassalSystem,
                     GovernmentSystem, ArmySystem, BattleSystem, DiplomacySystem, DiplomacyAISystem
  Calamity/, Unrest/  plague, famine, earthquake and rebel state (Phase 12)
  Scenario/          Scenario1453 + Economy/Character/Government/Military/Diplomacy/Calamity loaders
  Resources/         generated JSON and ID maps
App/Shared/
  GameModel.swift    bridge between simulation and UI; game loop; player actions
  ContentView.swift  top bar, speeds, map-mode bar, province panel, overlays
  EconomyViews.swift, BudgetView.swift, TradeView.swift, CourtView.swift,
  GovernmentView.swift, ArmyView.swift, DiplomacyView.swift, CountryArmsView.swift
  Map/               MapCanvasView (camera, gestures, labels, icons, routes, armies),
                     Metal/ (MapShaders.metal, renderer), MapRenderer (CPU fallback)
App/Tests/SnapshotTests.swift   renders PNGs on CI
godot/scripts/     the Godot game: Main.gd (map, top bar, side column, windows),
                   one script per window, GezTheme/GezStyle (Phase 20 look),
                   Portrait, AlertsRow, Motion, TitleScreens, Map*Layer
godot/assets/ui/   Phase 20 art (made by tools/uiart/), gez_theme.tres
godot/assets/paintings/  the owner's paintings (menu, events, portraits)
data/              hand-written source data (see table above)
tools/             generators and helpers (see table above)
docs/              HANDOFF (this), ROADMAP, DESIGN, HISTORY_NOTES, CREDITS, previews
```

## Known issues and tech debt

- Map labels are drawn by SwiftUI over the Metal view and don't curve yet.
- Wasteland beyond the game area uses rough biomes; Tibet looks very snowy.
- `MapRenderer` (CPU) duplicates some palette and border logic with the
  shader; keep them in step or retire it once Metal is proven everywhere.
- Population figures are regional estimates spread by development.
- The AI does not change laws yet (it does take reforms, raise stability
  and grant privileges).
- GitHub warns that `actions/setup-python@v5` and `upload-artifact@v4` run
  on Node 20; bump to the next major versions when convenient (the
  workspace could not check which exist).
- 208 uncertain facts about people and the 1453 government choices are
  waiting for the owner in `docs/HISTORY_NOTES.md`.

## Heraldry workflow

The owner rejected generated arms. Rules from the owner:
- Real arms and flags as used in 1453, from Wikimedia Commons, credited.
- If none from 1453 is known, use one from a few decades earlier or later.
- Indian kingdoms: their 1800s princely-state flags where they exist.
- Sultanates: Catalan Atlas (1375) flags and modern online guesses are OK.
- Turkic tribes use tamgas. Other tribes: ask the owner one by one.
- Otherwise a plain banner in the map colour.

How to change one: edit `data/heraldry/choices.txt` (`TAG | File:Name.svg |
note`) and push; the "Heraldry" workflow downloads, converts to PNG and
commits. To look for candidates: put rows in `data/heraldry/check.txt`
(`TAG | Name | wiki articles | commons searches | File: titles`) and run the
workflow by hand with mode `check` (`gh api -X POST
repos/theRealMaReza/gez/actions/workflows/heraldry.yml/dispatches -f
ref=main -f 'inputs[mode]=check'`). Contact sheets go to the
`heraldry-candidates` branch. CC BY-SA credits must be shown in-game
(credits screen still to do).

Owner decisions on tribes: Shammar = Ha'il flag; Asir = Idrisid flag;
Cyrenaica = Senussi flag; Yam = the owner-supplied Yam banner; Ja'alin,
Baloch, Hazara, Beja, Hakkari, Khokhars, Dards, Khasi, Bhuyan = invented
simple banners (`data/heraldry/designed/*.svg`); Pashtun = 1839 banner;
Kabarda = Kabardian noble banner; Oirats = Dzungar banner; Jats =
Bharatpur; Sami = 1986 Sami flag; Alania/Vainakh = later-era flags; Kirat
= modern Kirat flag; Albania = Kastrioti arms; Komi, Mordvins, Berbers,
Guanches, Somali, Najd = plain banner.
