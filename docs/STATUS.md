# Gez: status (one page)

The short version of `docs/HANDOFF.md` and `docs/ROADMAP.md`, mirrored to
the claude.ai Project as `claude/STATUS.md`. Everything else lives in the
repo (`theRealMaReza/gez`): read only the parts a task needs.

Last updated: 22 November 2026 (session 13, Phase 20).

## Repo move (21–22 Nov 2026)
- Old account `yv28f5k922-dot` suspended (owner appealed). New repo
  **`theRealMaReza/gez`**: all 40 old branches pushed; Phases 16–17
  restored from the owner's bundle (original hashes); Phase 17 part 3 was
  old PR #35, merged here as PR #2. New PR numbers start again at #1.
- Loose ends: tell Gemini the new remote; public site
  `yv28f5k922-dot.github.io` is not moved (HANDOFF "Public site" still
  points there); owner decides whether to delete
  `~/Developer/Gez/.git/transfer` (≈1.9 GB) on the Mac; docs PR #3 (repo
  move notes) is still open.

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
- Phases 0–17 and **20** done (map, economy, trade, characters,
  government, armies, diplomacy and war, sieges, Godot screens, battle
  view, navies, religion and culture, plague/famine/rebels, technology,
  70 historical events, AI behaviour setting, sound + math tooltips, 3D
  map, towns, armies and battles).
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
- **Map and flavour research** (owner, 22 Nov 2026): PR #13 adds
  `docs/MAP_EXPANSION_RESEARCH.md` (1453 border fixes, Afro-Eurasia
  expansion, regional governance, formables) with Claude's review notes.

## Next
1. **Phase 18 Chronicle** (Gemini, in progress): its screens get the
   Phase 20 look automatically; buttons via `add_side_button("chronicle" /
   "ledger" / "timelapse", ...)`.
2. Owner, when convenient: the paintings; a look at the new interface on
   the Mac (`git pull`, `./godot/build_mac.sh`): frame rate on the M1 when
   zoomed out (painted chart) and when windows open.
3. Then: **20.5 balance and play-test** (Claude, after 18 and 20 are
   merged; includes the 1453 border fixes from
   `docs/MAP_EXPANSION_RESEARCH.md`), **alpha "Kayser"**, **20.7 Old
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
