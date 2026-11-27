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
  `gh api repos/theRealMaReza/gez/pulls -f title=... -f head=... -f base=main -f body=...`.
- MultiMesh instances with models scaled by the shader need a big
  `custom_aabb`, or they are culled at the screen edges.
- Packed arrays (`PackedFloat32Array`...) are copied on write: appending
  to one kept inside a Dictionary changes a copy, and copying it out and
  back copies the whole array every time. Keep a plain Array of small
  packed arrays and join them once (`MapModels._commit`).

## Session 13: Phase 20, Interface and art (Claude)
- The owner wants to guide the interface: show a mock-up (PIL with the
  real art pieces and fonts) and ask one multiple-choice question per part
  before building it.
- Godot 4.7.2 runs in the workspace: download the Linux build from GitHub
  releases into /tmp and use `xvfb-run ... --rendering-driver opengl3` to
  render test scenes (theme gallery, portraits, the Main scene without the
  Swift extension). Much faster than waiting for CI screenshots.
- `StyleBoxTexture` has no scale: nine-slice art is drawn at 1x. Tiling
  (`AXIS_STRETCH_MODE_TILE*`) bleeds neighbouring pixels at tile seams, so
  windows stretch a large page instead; only the leather bars tile (their
  texture is seamless as a whole).
- Godot's default theme only applies where code has no overrides; most
  panels set colours through one `_make_label` helper per script, so a
  mechanical wrap (`GezStyle.ink(...)`, `GezStyle.fs(...)`) restyled them.
- A script error inside `capture_snapshots.gd` hung the CI job for hours
  (see session 12): the screenshot step now runs under `timeout` and the
  job has `timeout-minutes`.
- Art scripts share one random generator: adding a new piece before old
  ones changes every later picture. Make new pieces last (or reseed), and
  check `git status` shows only new files after a rebuild. `hash()` of a
  string differs per Python run; use `ord()` or fixed seeds.
- Long simulation tests take ~85 minutes; several CI runs at once queue
  for Mac runners. Stack dependent parts on one branch chain and run CI on
  the last one.

## Session 13 (also): repo move to theRealMaReza/gez (21–22 Nov 2026)
- Moving a repo: a bundle of every ref, split into parts under 400 MB to
  stage from the Mac, rebuilt and checked by sha256; `git clone --mirror`,
  turn `refs/remotes/origin/*` into `refs/heads/*`, push all. Work that is
  only in another Claude session can come across as a small bundle the
  owner downloads and attaches.
- Pushing many branches at once queues a CI run for each; the new account
  ran only about 3 jobs at a time. Cancel runs for old branches at once,
  and avoid both a `workflow_dispatch` and a `pull_request` run for the
  same commit (the dispatch run's checks already show on the PR).
- From this session: repository settings writes (for example the default
  branch) are refused by the proxy; GraphQL is blocked (use REST).

## Session 14 (22 Nov 2026): Phase 18 review and merge
- Gemini's four stacked Phase 18 PRs were built on main from before
  Phase 20; Claude squashed them onto main as one PR (#18) and moved the
  buttons into the side column (`add_side_button` / `add_window`).
- Gemini's save-size test used 5 events a year; at a realistic 200 the
  save was 7.6 MB. Packing (varints, year-on-year changes, one-byte
  wording seed) fixed it. Check size tests against realistic rates.
- Two Claude chats worked on the same branch at once and pushed the same
  fix minutes apart. Before pushing, fetch the branch; if someone else
  pushed, keep theirs rather than force-pushing.
- The 1453 border fixes (#19): the generators run here end to end (coast
  data via `fetch_coastlines.sh`, elevation is in the repo); new countries
  need a ruler under `@ TAG`, `ruler | =id` for one man ruling two, and no
  `d:` date for people alive at the start. Check map colours against
  neighbours in `docs/map_preview.png`. Heraldry: put rows in `check.txt`,
  run the workflow in `check` mode on the branch, pick from the sheets.

## Session 15 (23 Nov 2026): Phase 20.6 parts 1 and 4 (Claude)
- Six PRs (#35–#40) at once; CI previews publish to one orphan branch
  (`ci-snapshots-preview`), so a temporary branch merging all of them
  (`claude/20.6-preview`, not merged) gave every shot in one run.
- Straight country names were drawn in Godot's fallback Open Sans, not
  Cinzel: `ThemeDB.fallback_font` is the engine font even with a project
  theme. Measure with the font you draw with.
- Town size by area alone missed Konstantiniyye (big but thin and
  coastal); walking 12 rays on the id map catches the shape.
- The field-battle CI shots had silently stopped (no battle prompt in the
  snapshot run); a fixed `BattleShowcase` state keeps the battle view in
  the shots whatever the campaign does.
- Rendering locally works for 3D (`xvfb-run` + `--rendering-driver
  opengl3`): a throwaway SceneTree script that builds the node, feeds it
  data and saves the viewport. Depth fog shows in the Compatibility
  renderer on Godot 4.7.2.
- A "Godot extension (macOS)" failure cloning SwiftGodotBinary was a
  passing glitch; rerun failed jobs once the run ends.
- The old Metal app's "Render map snapshots" (arm64 runner) can wait in
  the queue for an hour; GDScript-only PRs were merged with it pending.


## Session 16 (23 Nov 2026): Phase 20.7 part 1, Old World map foundation (Claude)
- mapgen's border "wobble" was drawn for the whole picture, so growing the
  box reshuffled every border (1,070 of 1,378 provinces moved >15%). It now
  rebuilds today's random knots exactly (spline with mirror boundary) and
  adds new knots outside; check by regenerating at the old box and PPD 32.
- Measuring memory: `/proc/self/status` reads empty through Godot's
  FileAccess; run Godot from Python and read `RUSAGE_CHILDREN` maxrss.
  llvmpipe keeps textures in process memory, a fair stand-in for the M1's
  unified memory.
- This workspace has ~7 GB: bake_terrain on the big map was killed until
  it painted in strips with a 4-sigma margin; mapgen dropped whole-map
  distance transforms for seed snapping.
- A dispatched workflow uses the branch's copy of the workflow file, so the
  elevation job could be taught to push back to the branch it ran on. Its
  commit (by GITHUB_TOKEN) does not start CI; push something after it.
- In a shallow clone, `git fetch origin <branch>` doesn't make
  `origin/<branch>`; fetch with an explicit `branch:refs/remotes/origin/branch`.
- The map colour texture was 2048 wide (2,046 provinces at most); now 8192.
- Finer pixels change what the camera zoom means (screen px per map px):
  every "show names/towns/armies above zoom X", model size and relief
  height was in old map units. `MapScale.k` (pixels per degree / 32) and
  `MapScale.look(zoom)` keep them geographic. A test clicking 41.0 N
  29.0 E for Constantinople hit the Bosporus at 48 px/degree.
- The simulation had one pixel-based rule: sea travel (`baseSeaPixelsPerDay`
  over zone-centre distances). `seaDistance` now counts 32-px/degree
  pixels, so fleets keep their speed; NavyTests caught it.


## Session 17 (24 Nov 2026): 20.7 smooth borders, Hagia Sophia, review of #46–#48 (Claude)
- `needs-claude` PRs were merged from the owner's account; main went red
  after #48 and nobody noticed. After a Gemini merge, check main's CI.
- A year of full simulation inside a unit test makes it depend on wars:
  the shipbuilding test broke because Venice was (most likely) occupied,
  which cancels builds. Test one system by calling its step directly.
- Smooth borders: an unsigned distance can't be blended across an id
  edge (it is 0.5 on both sides). Rebuild a signed one from the 4 nearest
  pixels (+ own id, − others); a signed blur with a floor of 0.3 rounds
  the steps without losing 1-pixel straits.
- The map shader can be rendered here without the Swift extension: a
  PlaneMesh with the shader and PNGs of the id, sea and style textures
  (made in Python from the idmaps and scenario JSON). Same for model
  mock-ups (load models.bin in GDScript). Good for before/after pictures.
- A dispatched run and a PR run of the same branch both queue for the Mac
  runners; cancel one. Only dispatched runs publish preview shots, and
  they overwrite each other on `ci-snapshots-preview`.
- Lakes: `bake_heightmap.py` put them at sea level (pits on plateaus);
  in the shader they still fall into the parchment branch (HANDOFF).

## Session 18 (26 Nov 2026): Phase 20.8 part 1, ruling-systems engine (Claude)
- Owner's order: HRE, then Shogunate. Screens picked from mock-ups: HRE
  "Imperial Diet" window, formables "Crowns to claim" list (DESIGN).
- Engine merged as #70, green on the first CI run although nothing could
  be compiled here: keep new Swift close to patterns already in the code
  (events' own dice stream, `EventEvalContext`, Swift Testing with
  `Scenario1453.makeWorld()`), and keep `&inout` arguments out of
  `#expect`/`#require` (assign first).
- Generic saved state (roles, values, per-country values, flags, stage per
  system, matched by key) means Gemini's systems never touch the save
  format; a global `RulingSystems.register` is safe in parallel tests
  because hooks run only for systems present in that world's data.
- The CI wait script can outlive a foreground call (10 min cap) and a
  background one can be killed with the environment: if so, read the
  jobs once with `gh api .../actions/runs/<id>/jobs`.

