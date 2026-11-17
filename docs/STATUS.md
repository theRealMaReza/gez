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
- No music ever. Local saves only. Never ask for API keys in chat.
- Alpha build name: **"Kayser"** (after Phase 20).

## Where things stand
- Phases 0–13 done (map, economy, trade, characters, government, armies,
  diplomacy and war, sieges, Godot screens, battle view, navies, religion
  and culture, plague/famine/rebels, technology).
- Gemini writes most code on `gemini/*` branches; Claude reviews
  (routine: HANDOFF "Working with Gemini" and "How Claude reviews").

## Next
1. Owner play-test of Phase 13 on the Mac (`Tech` button, `K` map mode).
2. **Phase 14: historical events** with choices (Granada, Columbus,
   Vasco da Gama, Babur, Reformation, Safavids...) and pop-ups for
   risings, plots and deaths. Mission trees moved to Phase 21.
3. Then: 15 AI setting, 16 sound (free CC0) + tooltips, 17 3D (Claude;
   AI-made models, tool decided then), 18 chronicle, 20 art, 20.5
   balance and play-test (Claude), **alpha "Kayser"**, then 21 mission
   trees and 19 multiplayer. Who writes what: ROADMAP "Plan for the
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
