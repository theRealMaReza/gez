# Gez: status (one page)

The short version of `docs/HANDOFF.md` and `docs/ROADMAP.md`, mirrored to
the claude.ai Project as `claude/STATUS.md`. Everything else lives in the
repo (`yv28f5k922-dot/Gez`): read only the parts a task needs.

Last updated: 20 November 2026.

## The owner
- Doesn't write code. Plain language, short replies (often on a phone).
- Design and history questions: multiple choice, 2–4 options,
  recommended first, one topic at a time.
- Game: EU5-style grand strategy from **30 May 1453**, daily tick with
  pause and 5 speeds, Total War–style battles (fight or auto-resolve),
  CK3-style real people of 1453. Mac and Windows (Godot); no iPad for now.
- No music ever. Local saves only. No extra paid services (art: free
  models, our code, and paintings the owner makes in the Gemini app). Never ask for API keys in chat.
- Alpha build name: **"Kayser"** (after Phase 20.5).

## Where things stand
- Phases 0–17 done (map, economy, trade, characters, government, armies,
  diplomacy and war, sieges, Godot screens, battle view, navies, religion
  and culture, plague/famine/rebels, technology, historical events: 70,
  AI behaviour setting: Historical vs Free; 16 sound effects + math
  tooltips; **Phase 17 Going 3D**: 3D terrain map that tilts as you zoom,
  3D towns/forts/ports/armies/fleets in five regional styles, 3D battle
  view; PRs #33–#35 merged 20 Nov).
- Gemini writes most code on `gemini/*` branches; Claude reviews
  (routine: HANDOFF "Working with Gemini" and "How Claude reviews").

## Next
1. Owner play-test of Phases 15–17 on the Mac (`git pull`,
   `./godot/build_mac.sh`): AI behaviour selector + `AI Goal:` line;
   tooltips, sounds and volume sliders; zoom in to see the tilt, 3D
   towns, marching armies; lead a battle and a storm assault in 3D.
   Report the frame rate on the M1 if it feels slow. Small known nits:
   coin sound plays almost every month; sea-battle sound can stop once
   the recent-battles list is full.
2. **Phase 18: Chronicle** (Gemini).
3. Then: 20 art, 20.5 balance and play-test (Claude), **alpha "Kayser"**,
   then 21 mission trees and 19 multiplayer (Epic Online Services, join
   codes). Who writes what: ROADMAP "Plan for the remaining phases". Art
   script: `tools/uiart/ui_art_concept.py`; 3D models:
   `tools/models/build_models.py`.

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
