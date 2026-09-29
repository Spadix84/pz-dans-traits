# Master plan

Source: the full review of 2026-09-28 (Fable). Each numbered file in this
folder is one self-contained unit of work: goal, files, exact steps, tests,
acceptance. Execute one plan per agent, in its own worktree, one commit per
plan. The offline suite (`python tests/run_tests.py`) is the gate for every
plan; in-game checks are listed where the suite cannot see the change.

## Rules for every executor (read before touching Lua)

- The game's Lua is Kahlua: no `next`, `assert`, `xpcall`, `string.gmatch`,
  `string.rep`; at most 200 locals and 60 upvalues per function, the file's
  top level included. `tests/lint_kahlua.py` enforces this and runs first.
- Every Java call on a game object goes inside `pcall`. Calling a method the
  object lacks fails quietly in `pcall` but dumps a stack trace to the log
  every time, so `tests/check_api.py` checks method names against the jar.
- Shared helpers live in `DanTraits.lua` (core) or, after plan 03, in
  `DanTraits_Util.lua`. Core is near the local limit: add nothing there that
  could go in Util.
- Trait files `require "DanTraits"` and read helpers into locals at the top.
  Keep that shape.
- Mod data is one flat table per player, `player:getModData().DanTraits`.
  Renaming a key breaks saves; plans that rename say how to migrate.
- Notices go through `DanTraits_Notify` / `DanTraits_NotifyGood` so the story
  event fires. Never call `HaloTextHelper` directly from a trait file.
- Keep the file-header comment of every file you touch accurate. Headers are
  the design record; a wrong header is a bug.
- Tests: fengari (standard Lua) via `tests/run_tests.py`. Add or extend a test
  for every behaviour change. Tests use the loader list and stubs at the top
  of each `test_*.lua`; after plan 02 they use `tests/harness.lua`.
- Commit message: one line of what changed and why, then the attribution
  line the session gives you. No "Co-Authored" from other agents.
- Do not deploy. The user runs `python deploy.py` and restarts the game.

## Order and dependencies

Phase 0, ship today (tiny, standalone):
- 01 drink wrapper collision fix + wrap helper

Phase 1, foundations (each is a mechanical refactor; the unchanged test
suite is the safety net; do them in this order because later ones use
earlier ones):
- 02 test harness consolidation (so every later plan adds tests cheaply)
- 03 util file (clamp01, floorUp, roll, parts, moodle, asleep, sandbox)
- 04 minute and frame driver registry (explicit ordering, one preamble)
- 05 stat delta pipeline (endurance regen, catch-a-cold, food sickness)
- 06 vanilla trait lookup cache
- 07 one definition of drunk
- 08 pain floors that honour painkillers

Phase 2, synergy (small, independent, parallelisable; all depend on 03 and
04 only where noted):
- 09 infection hook subscribers
- 10 fever reaches other systems
- 11 passing out: hypoglycemia, asthma attack, alcoholic seizure
- 12 smoker and asthma, one cough
- 13 migraine triggers: caffeine withdrawal, fever
- 14 hallucinations read the mod's own signals
- 15 vitality's reach: infection, concussion, deep wounds, lungs
- 16 age hooks: red cells, concussion, hangover, type 2
- 17 MDD relief thresholds

Phase 3, larger or judgement-heavy:
- 18 food classifier
- 19 mod-data key hygiene (touches saves)
- 20 small cleanups and sandbox toggles
- 21 bad day balance pass (needs in-game play)
- 22 missing tests and tooling fixes

## Who does what

- Plan authoring and review: the top model (this session). Review means
  reading the diff against the plan, running the suite, and checking the
  header comments.
- Execution: Sonnet, one agent per plan, `isolation: "worktree"`, prompt =
  "Execute plans/NN-....md in this repo. Read plans/00-master.md first."
  Haiku is fine for 01 and 03; everything else has enough judgement in it
  to want Sonnet.
- Phase 2 plans can run as parallel agents; phases 0 and 1 are sequential
  because each rebases on the last.
- After each phase: the user deploys and plays a session; anything the suite
  cannot see (moodles, sounds, timing feel) is checked there.

## Acceptance for the whole programme

- `python tests/run_tests.py` green at every commit.
- No trait file registers `Events.EveryOneMinute` or `Events.OnPlayerUpdate`
  directly (plan 04).
- Exactly one place in the codebase scales endurance recovery (plan 05).
- No two files guard a wrapped game method with the same flag (plan 01).
- Every hook declared with `DanTraits_RunHooks` has at least one subscriber
  or a comment saying it is offered for other mods.
