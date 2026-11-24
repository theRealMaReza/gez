# Gez: status (one page)

The short version of `docs/HANDOFF.md` and `docs/ROADMAP.md`, mirrored to
the claude.ai Project as `claude/STATUS.md`. Everything else lives in the
repo (`theRealMaReza/gez`): read only the parts a task needs.

Last updated: 24 November 2026 (session 17: smooth borders #51, Hagia Sophia #54,
review of Gemini's #46–#48).

## Repo move (21–22 Nov 2026)
- Old account `yv28f5k922-dot` suspended (owner appealed). New repo
  **`theRealMaReza/gez`**: all 40 old branches pushed; Phases 16–17
  restored from the owner's bundle (original hashes); Phase 17 part 3 was
  old PR #35, merged here as PR #2. New PR numbers start again at #1.
- Loose ends: tell Gemini the new remote; public site
  `yv28f5k922-dot.github.io` is not moved (HANDOFF "Public site" still
  points there); owner decides whether to delete
  `~/Developer/Gez/.git/transfer` (≈1.9 GB) on the Mac. (Docs PR #3 was closed;
  its notes went into #13.)

## The owner
- Doesn't write code. Plain language, short replies (often on a phone).
- Design and history questions: multiple choice, 2–4 options,
  recommended first, one topic at a time. **Interface design: show
  mock-ups and ask** (owner, 22 Nov 2026).
- Game: EU5-style grand strategy from **30 May 1453**, daily tick with
  pause and 5 speeds, Total War–style battles (fight or auto-resolve),
  CK3-style real people of 1453. Mac and Windows (Godot); no iPad for now.
- No music ever. Local saves only. No extra paid services (art: free
  models, our code, and paintings the owner makes in the Gemini app). Never ask for API keys in chat.
- Alpha build name: **"Kayser"** (after Phase 20.5).

## Where things stand
- Phases 0–18 and **20** done (map, economy, trade, characters,
  government, armies, diplomacy and war, sieges, Godot screens, battle
  view, navies, religion and culture, plague/famine/rebels, technology,
  70 historical events, AI behaviour setting, sound + math tooltips, 3D
  map, towns, armies and battles).
- **Phase 20.5 part 1, 1453 border fixes** (#19, merged 22 Nov): free
  cities Metz, Besançon, Basel; Further Austria; St Gallen and Valais;
  Yemen split; five more Irish lordships; Malatesta, Pomerania,
  Schleswig, Rostov, Upper Oka, Ösel-Wiek, Alaiye; 21 new countries and
  5 new provinces (1,378). Doubts in `docs/HISTORY_NOTES.md`.
- **Phase 18 Chronicle and stats** (Gemini PRs #14–#17, rebased and fixed
  by Claude as PR #18, merged 22 Nov): Chronicle book by reign, Ledger and
  graphs, Map Timelapse; history stays compact in saves (tested at 400
  years, 200 events a year).
- **Phase 20 Interface and art** (Claude, session 13, PRs #4–#11 + part 9):
  one shared Theme (gold frames, leather, parchment, red banners, gold
  buttons, Cinzel / EB Garamond); top bar of medallions + numbers, screens
  in a medallion column on the left, glowing alert medallions; goods and
  building icons; manuscript-style portraits for everyone; shields by
  culture; compact tooltip cards; unrolling windows; curved country
  names; painted-chart look when zoomed out; forests; main menu and
  loading screen. Every look picked by the owner from mock-ups.
- **Phase 20.6 Polish** ✅ (no rule changes): part 2 Main.gd split (#26);
  part 3 map-mode dock (#32) and outliner (#33); part 1 (Claude, 23 Nov):
  map names measured instead of guessed (#35), engraved heart / broken
  heart / star glyphs instead of ♥ ✗ ★ (#36), province drawer bottom
  margin (#37), Court shows relatives once (owner's pick A, #40); part 4
  (Claude, 23 Nov): models with baked shading, dark plinths, towns capped
  by their province's size and shape, waving flags and sails (#38); battle
  view with a horizon and haze, thin ground outlines, small label plates,
  bigger soldiers that fill the rules' rectangle, musket and cannon smoke
  (#39). CI now always shoots a fixed battle (`godot_battle_showcase.png`,
  `godot_battle_closeup.png`).
- **Paintings still to make** (owner, Gemini app): 97 prompts in
  `docs/ART_PROMPTS.md` (main menu, loading screen, 66 event pictures,
  29 portraits). Drop them in `godot/assets/paintings/{menu,events,portraits}/`
  or attach them in a chat; stand-ins show until then.
- **Who does what (owner, 23 Nov 2026):** Gemini (Gemini 4 Neon, in
  Antigravity) writes most code and tests and merges its own PRs when CI
  is green. PRs labelled `needs-claude` wait for Claude: looks, region
  PRs, save format, shared engine, multiplayer sync, weakened tests (list
  in `GEMINI.md`). Claude does the 20.8 engine, borders and landmarks,
  all visual design (mock-ups the owner picks; Gemini builds them) and
  the screen check before "Kayser". Routine: HANDOFF "Who does what".
- **20.7 East Asia core** (Gemini, #44, merged 23 Nov): Ming with its
  princes and tusi, Joseon, the Ashikaga and 15 shugo, Ryukyu, the Ainu;
  229 provinces (1,607). Mongolia, Manchuria, Tibet and the Tarim are
  still wasteland.
- **20.7 rest of East Asia** (Gemini, #46 Tarim and Moghulistan, #47 Tibet
  and Bhutan, #48 Mongols, Oirats and Manchuria; 1,732 provinces). Merged
  from the owner's account without Claude's review although labelled
  `needs-claude`; Claude checked them afterwards (24 Nov): Kunga Lekpa's
  birth year (#50); highland lakes were pits on the 3D map (#52); main
  was red after #48 (shipbuilding test, #53). Several shields are
  20th-century flags (owner's picks).
- **20.7 smooth borders** (Claude, #51): borders and coasts from a baked
  distance field (`tools/terrain/edge_field.py` → `edges.png`, made by
  `bake_terrain.py`), smooth curves at every zoom; far fewer texture reads.
  A test fails if `edges.png` is stale. Timing tool for the M1:
  `godot/tools/profile_map.gd` (owner to run).
- **20.7 landmarks** (Claude): Hagia Sophia built in code, owner's pick B
  (Mehmed II's red-brick minaret), #54. Next: one landmark per region.
- **Phase 20.7 part 1, Old World map foundation** (Claude, PR #43, 23 Nov):
  map grown to Afro-Eurasia (25 W–148 E, 35 S–71.5 N) at **48 px/degree**
  (8304 × 5112, owner's pick after measuring: about +580 MB in the game);
  **Australia and New Guinea are unknown-land parchment** (owner's pick);
  new land is placeholder wasteland; 59 new sea zones; old borders kept;
  new faiths (Mahayana, Confucian, Daoist, Shinto; West African, Bantu,
  East African, Siberian, Austronesian, Highland). Guide for Gemini's
  region PRs: HANDOFF "Old World region pull requests".
- **Map and flavour research** (owner, 22 Nov 2026): PR #13 (merged) adds
  `docs/MAP_EXPANSION_RESEARCH.md` (1453 border fixes, Afro-Eurasia
  expansion, regional governance, formables) with Claude's review notes.

## Next
1. Owner, when convenient: on the M1, `./godot/build_mac.sh`, then
   `/Applications/Godot.app/Contents/MacOS/Godot --path godot --script
   res://tools/profile_map.gd` (border speed before/after); the paintings; a look at the new interface on
   the Mac (`git pull`, `./godot/build_mac.sh`): frame rate on the M1 when
   zoomed out (painted chart) and when windows open; try the Chronicle,
   Ledger and Timelapse medallions in the left column.
2. **20.7 region PRs** (Gemini writes, Claude reviews; guide in HANDOFF;
   East Asia is done): Southeast Asia, Siberia, Africa south of the Equator, and the
   still-empty Sahel and Guinea coast; then 20.8, then the rest of 20.5. Also on
   the Mac: frame rate of the new battle view (smoke, more haze) and of
   towns on first load.
3. **20.5 balance and play-test** (Gemini writes the fixes and builds
   "Kayser", Claude checks the screens; Phases 18 and 20 are both
   merged; part 1, the 1453 border fixes, is merged as #19; the first
   six AI-only games to 1550 are in `docs/BALANCE_REPORT.md`; next the
   fixes listed there, one PR per area), then **alpha "Kayser"**, **20.7 Old
   World map** (Afro-Eurasia), **20.8 ruling systems and formables**,
   then 21 mission trees and 19 multiplayer.
   Who writes what: ROADMAP "Plan for the remaining phases".

## Saving tokens (owner's choice, 16 Nov 2026)
- One task per session (a phase part, or one PR review); HANDOFF carries
  memory between sessions.
- Sonnet for routine work (PR checks and merges, red-CI fixes, data
  edits, doc mirroring); Opus for writing phases, design and hard bugs.
- CI: run `tools/ci/status.sh <branch> --wait` once instead of polling;
  it prints pass/fail per job and only the error lines of failures.
- PR reviews: `git diff --stat` first, then read only the files that matter.
- Past session lessons are in `docs/SESSION_LOG.md`; open only when
  relevant.
- Owner: run `/explain-usage` at the end of sessions to see what costs most.
