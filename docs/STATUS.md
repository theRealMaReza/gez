# Gez: status (one page)

The short version of `docs/HANDOFF.md` and `docs/ROADMAP.md`, mirrored to
the claude.ai Project as `claude/STATUS.md`. Everything else lives in the
repo (`theRealMaReza/gez`): read only the parts a task needs.

Last updated: 22 November 2026 (Phase 18 merged, PR #18).

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
- **Paintings still to make** (owner, Gemini app): 97 prompts in
  `docs/ART_PROMPTS.md` (main menu, loading screen, 66 event pictures,
  29 portraits). Drop them in `godot/assets/paintings/{menu,events,portraits}/`
  or attach them in a chat; stand-ins show until then.
- Gemini writes most code on `gemini/*` branches; Claude reviews
  (routine: HANDOFF "Working with Gemini" and "How Claude reviews"). New
  screens: plain controls, `add_window`, `add_side_button` (HANDOFF "New
  screens and the Phase 20 look").
- **Map and flavour research** (owner, 22 Nov 2026): PR #13 (merged) adds
  `docs/MAP_EXPANSION_RESEARCH.md` (1453 border fixes, Afro-Eurasia
  expansion, regional governance, formables) with Claude's review notes.

## Next
1. Owner, when convenient: the paintings; a look at the new interface on
   the Mac (`git pull`, `./godot/build_mac.sh`): frame rate on the M1 when
   zoomed out (painted chart) and when windows open; try the Chronicle,
   Ledger and Timelapse medallions in the left column.
2. **20.5 balance and play-test** (Claude; Phases 18 and 20 are both
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
