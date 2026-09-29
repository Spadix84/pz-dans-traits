# 22. Missing tests and tooling fixes

Phase 3. Sonnet. After plan 02 (harness). Can be split across two agents:
new tests, and tooling.

## Missing tests (from the coverage audit)

1. `tests/test_brittle.lua`: damage under 2 never fractures; a seeded roll
   under 20 fractures one of the six parts and sets fracture time 40..79; an
   already-fractured part is skipped; the notice fires.
2. `tests/test_jinxed.lua`: `OnFillContainer` with no player does nothing;
   with the trait and a seeded roll under 35 removes exactly one item; an
   empty container is safe.
3. `tests/test_badday.lua`: see plan 21; at minimum the create handler is
   idempotent.
4. `tests/test_actions.lua`: the three timed actions with a stub
   `ISBaseTimedAction`: `ISDiabetesAction` inject uses n doses and calls
   `DanTraits_DiaInject`; test uses a strip and renames the meter; pill
   calls `DanTraits_DiaOnPill`. `ISUseInhalerAction` calls
   `DanTraits_UseInhaler`. `ISVitalityPillAction` fires the `pill` hook with
   the item type. `isValid` false when the item is missing or empty.
5. End-to-end faint: `test_blood.lua` and `test_hemophobia.lua` stub
   `DanTraits_PassOut`. Add one case each that loads `DanTraits_Faint` for
   real: shock at tier 3 with a seeded roll calls PassOut, the tick holds
   movement, a new wound wakes; Fear of Blood after `ISStitch.complete`
   passes out and comes round after the real-time floor (`H.now` advanced).
6. Telemetry commands never run: `metformin`, `inhaler`, `fracture`, `drop`,
   `cough`, `gluten`, `antidep`, `attrib`, `echo`. One assertion each in
   `test_telemetry.lua` with the target global stubbed.
7. Client context menus (`DanTraits_Client.lua`): a stub `context` with
   `addOption`, `getOptionFromName`, `removeOptionByName`, `addSubMenu`,
   `getNew`; assert the inhaler option is greyed when empty, the inject
   submenu greys doses above what is left, Vegetarian greys Eat, and
   `isTraitEnabled` hides Wakeful. New `tests/test_client.lua`.

## Tooling

8. `run_tests.py`: spawn fengari once per run, not per file (a small Lua
   runner that `dofile`s each test in a fresh environment is simplest; or
   pass all files to one `fengari` invocation and print per-file results).
   Pin `fengari-node-cli` to a version in a `tests/package.json` and use
   `npx --no-install` when `node_modules` exists.
9. `run_tests.py`: the total `len(tests) + 4` is hardcoded; count the
   extra checks from a list.
10. `check_api.py`: the receiver-name patterns (`part`, `bd`, `player`,
    `stats`, `weapon`) miss `patient`, `self.character`, `p`, `character`,
    `head`, `zombie`. Extend the list and add a self-test that a known-bad
    method name in a fixture string is caught. Print SKIP when the jar is
    missing (also in plan 20; whichever runs first).
11. `lint_kahlua.py`: also flag `string.format` with `%s` on a non-string
    (Kahlua's format is partial; the telemetry avoids it by hand) and
    `table.unpack` / `unpack`. Add to the self-test.

## Acceptance

- Suite green; every mod file has at least one test file naming it.
- `python tests/run_tests.py` wall time roughly halves (one fengari start).
