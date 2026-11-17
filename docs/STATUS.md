# Gez: status (one page)

The short version of `docs/HANDOFF.md` and `docs/ROADMAP.md`, mirrored to
the claude.ai Project as `claude/STATUS.md`. Everything else lives in the
repo (`yv28f5k922-dot/Gez`): read only the parts a task needs.

Last updated: 16 November 2026.

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
- Phases 0–14 done (map, economy, trade, characters, government, armies,
  diplomacy and war, sieges, Godot screens, battle view, navies, religion
  and culture, plague/famine/rebels, technology,
  historical events: 70, merged 16 Nov 2026, PR #30).
- Gemini writes most code on `gemini/*` branches; Claude reviews
  (routine: HANDOFF "Working with Gemini" and "How Claude reviews").

## Next
1. Owner play-test of Phase 14 on the Mac (`git pull`,
   `./godot/build_mac.sh`, start a game; Hungary gets Belgrade in July
   1456).
2. **Phase 15: AI setting** (historical or free; historical AI uses a
   simple goal list per country until the Phase 21 mission trees).
3. Then: 16 sound (free CC0) + tooltips, 17 3D (Claude;
   free CC0 models + models built in code), 18 chronicle, 20 art, 20.5
   balance and play-test (Claude), **alpha "Kayser"**, then 21 mission
   trees and 19 multiplayer (Epic Online Services, join codes). Who writes what: ROADMAP "Plan for the
   remaining phases". Art script: `tools/uiart/ui_art_concept.py`.

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
