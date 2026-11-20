# Gez: session log

Notes from past sessions, moved out of HANDOFF to keep it short.
Read only when a task touches the same area.

## Session 10: Phase 12 written by Claude (PR #26)
- The owner had Claude write this phase instead of reviewing Gemini.
  One commit per part (A plague, B famine and earthquakes, C unrest and
  rebels, D screens and docs).
- **Own dice**: plague, famine, earthquakes and rebels use
  `world.calamity.rngState` (a `GameRandom` split off the game's stream on
  the first monthly tick, saved). Use `world.beginCalamityRandom(random)` /
  `endCalamityRandom(rng)` for any new calamity; never draw from the main
  `random` there, or every existing system's luck shifts.
- **Tuning**: `tools/calamity/plague_prototype.py` is a Python copy of the
  spread rules (keep constants in step with `PlagueModel`). The test
  `testTwoYearsOfCalamitiesStaySane` and the ten-year run (every year)
  print a `CALAMITY ...` line into the CI log (`CalamityReport.line`):
  read it after any rule change (deaths, unrest, how many factions and
  risings).
- **Famine is relative**: each market remembers its usual staple supply
  (`calamity.stapleNorm`); Hormuz, Aksum, Aden, Mogadishu and Tunis always
  run 20–35% short of staples in the economy model and would otherwise
  starve forever.
- **Rebel armies** are ordinary `isRebel` armies owned by the country;
  `world.unrest.isFactionArmy(index)` tells them from vassal revolts
  (`ArmySystem.resolveRebelClash` skips them; `RebelSystem.fight` handles
  them). They stand still for now (no marching on the capital).
- **Found on the way**: `ReligionPanel.gd` called a `_focus_map_on_point`
  that does not exist in `Main.gd` (clicking a province name in the
  Religion window did nothing); fixed to `_focus_and_select_province`.
- `testPopulationGrowsOverAYear` now allows 2% loss in the first year
  (people also die of plague and hunger).
- **Ten-year run (seed 1453, first version)**: the world falls from 202 M
  to 195 M people; disease kills about 4.5 M and famine 2.7 M in ten
  years, earthquakes 46 k; only 2 rebel risings worldwide (1 won, 1
  crushed), 1 faction bought off. Judged too deadly and rebels too rare,
  so the first tune (owner: "do what you think is right") cut camp fever
  (siege 6→4%, camp 4→2% a month, lethality 15→12%), smallpox
  (lethality 12→8%, outbreaks 0.03→0.02%) and famine deaths (0.3→0.2% a
  month), and made Peasant Rebels (threshold 12→10, rate 0.15→0.20),
  Separatists (16→14, 0.15→0.20) and Zealots (30→26) rise sooner. Read
  the yearly `CALAMITY` lines of the next long run to see the effect.
- **Draft pull requests**: the REST API cannot mark a draft "ready" (that
  needs GraphQL, which is blocked here) and refuses to merge a draft. Open
  pull requests as normal ones from the start. If one is a draft, close it
  and open the same branch again as a normal pull request.
- Not done / ideas: rebels marching and besieging, plague arriving with
  fleets and refugees, hospitals or granaries as buildings, an event
  pop-up when a rising starts (Phase 14), AI changing tax for other
  classes.

## Session 7 review of PR #23 (navies)
- Fixed: `NavySystem.runDaily` took ~4.3 ms/day (half the tick); dock
  permissions are now built once a day (`NavySystem.dockFriends`, tested
  against the pairwise check). Admirals and army commanders are different
  people. Army path search skips strait checks when no hostile fleet is at
  sea. The Godot top bar scales down to fit the window. History question:
  Giacomo vs Alvise Loredan (HISTORY_NOTES).
- The 10-year debug run went 163 s → 433 s with the navy; check it again
  after the strait shortcut. The profile job now times the navy systems.

## Session 7 review of PR #22 (battle view)
- Fixed: platform-independent battle maths (`Core/DetMath.swift`; the
  `BATTLE_CHECKSUM` printed by `BattleEngineTests` must match in the Mac,
  Linux and Windows test logs), walls hold the garrison in, every same-day
  battle of the player's gets the choice, same-coloured armies drawn apart,
  battle pace (`BattleEngine.pace = 0.125`, time limits 10/15 min; an even
  ~9,000-man battle lasts ~3 min, `testBattleLastsMinutesNotSeconds`).
- Look at the battle screenshots (`godot_battle_*.png`, `godot_assault.png`)
  for units in impossible places and for battles that end too fast.

## Session 7 review of PR #21 (lessons for the next reviews)
- Gemini's "green" builds were not proof: the Linux export could not load
  GezCore (Swift runtime not copied) and the Mac export failed. Each export
  job now starts the exported game headless and requires the line
  "Gez: 1453 world loaded".
- `godot --headless --path godot --quit` does not register the extension;
  use `--import` before exporting or rendering screenshots.
- Speed claims: compare with `FingerprintTests` (by-hand profile job:
  `gh workflow run ci.yml --ref <branch> -f only=profile`, then diff the
  `FINGERPRINT` lines of two branches). Pure speed-ups must match line for
  line. Measured: 5.7 → 3.9 ms per game day identical; 3.1 ms with the
  three AI behaviour changes from PR #15 (documented in DESIGN.md).
- Watch for precomputed lists that go stale inside a loop that changes
  them (alliances, soldier counts).
- Screenshots are taken at the game's default 1440×900; look for things
  pushed off-screen.

Phase 7 history additions by Claude's review: the Albanian–Ottoman war and
the Delhi–Jaunpur war were active on 30 May 1453 and are now in
`data/diplomacy/wars_1453.txt`. Still doubtful: Scotland as an active
co-belligerent in the Hundred Years' War in 1453, and the Ottoman–Genoese
truce (Galata surrendered on 1 June 1453, two days after the start).

## Session 9 review of PR #24 (religion and culture)

- Speed: `CultureStanding` (end of `CultureSystem.swift`) builds
  accepted / same family / foreign for every (country, culture) once; the
  monthly economy and max manpower read it instead of comparing culture
  family strings per pop. Profile went 11.7 → 5.6 ms/day (Phase 10: 4.2).
- Pop groups grew without limit (14k → 42k in a year) because conversion,
  assimilation and migration made a new group for any amount of people.
  `PopDust.minNewGroup = 25` (smaller amounts wait or join a matching
  group) and `PopTable.foldDust` (monthly, at the end of
  `CultureSystem.runMonthly`) folds groups under 1 person into the largest
  same-class group. 18k groups after a year. Watch this number (the
  profile prints `pop groups=`) whenever a system creates pop groups.
- `testPopulationGrowsOverAYear` / `testPopsGrowWithTime` assumed the world
  always grows in year one; one extra AI war broke that. Growth is now
  tested on its own; the full year must stay within 0.5%.
- Temporary branches the owner can delete: `claude/diag-a`,
  `claude/diag-b`, `claude/fingerprint-base`, `claude/fingerprint-speedonly`.

## Session 12: Phase 17, Going 3D (Claude)
- Godot's Compatibility renderer (CI screenshots, `--rendering-driver
  opengl3`) writes shader colours as sRGB, Forward+ (Mac, Windows) as
  linear: shaders that work in sRGB must end with
  `ALBEDO = OUTPUT_IS_SRGB ? c : srgb_to_linear(c)`, or one of the two
  looks too dark.
- A GDScript runtime error in a `--script` SceneTree script stops the
  script but not Godot: the process hangs until killed. Always run with
  `timeout`, and read the log file (not a `| grep | head` pipe, which
  hides the error until the process ends).
- Typed arrays (`Array[int]`) cannot be assigned a plain array from
  another script; use `.assign()`.
- KayKit's free kits are on GitHub (`KayKit-Game-Assets/...`) and can be
  cloned from the workspace; Kenney and Quaternius need a CI job.
- `gh pr create` is blocked (GraphQL); open PRs with
  `gh api repos/yv28f5k922-dot/Gez/pulls -f title=... -f head=... -f base=main -f body=...`.
- MultiMesh instances with models scaled by the shader need a big
  `custom_aabb`, or they are culled at the screen edges.
- Packed arrays (`PackedFloat32Array`...) are copied on write: appending
  to one kept inside a Dictionary changes a copy, and copying it out and
  back copies the whole array every time. Keep a plain Array of small
  packed arrays and join them once (`MapModels._commit`).
