# 02. Test harness consolidation

Phase 1, first. Sonnet. Touches every test file; the change is mechanical
and the acceptance is "the same assertions still pass".

## Problem (from the coverage audit)

- The `Events` stub, `near`, `mins`, `makePlayer`, the halo capture and the
  12-file loader list are copied into 24 to 28 of the 30 test files.
- Two incompatible `Events` stubs exist: most files append handlers; three
  (`test_phantom.lua:2`, `test_healthpanel.lua:6`, `test_distributions.lua:2`)
  overwrite, keeping only the last handler per event. `test_phantom` passes
  only because Hallucinations happens to register `OnTick` last.
- `run_tests.py` detects a pass by the substring "passed"; two files print
  non-standard lines.

## Change

1. Create `tests/harness.lua`, loaded with `dofile` and returning a table
   `H` (plain Lua 5.3; fengari runs it):
   - `H.events()` installs `Events` with `Add` appending to `handlers[name]`
     (a list) and `Remove`; `H.fire(name, ...)` calls every handler in order.
     Returns `handlers`. For tests that need "the one handler", `H.only(name)`
     asserts exactly one and returns it.
   - `H.stubs()` installs the common game stubs: `getText` identity,
     `HaloTextHelper` capturing into `H.halo`, `ZombRand`, `ZombRandFloat`,
     `getSpecificPlayer`, `getGameTime`, `getTimestampMs` with a settable
     `H.now`, `CharacterStat` enum table, `MoodleType`, `MF = nil`,
     minimal `ISEatFoodAction`, `ISTakePillAction`, `ISDrinkFluidAction`,
     `ArrayList`, `IsoFireManager`, `getWorld`, `getCell`, `instanceof`,
     `BodyPartType`, `Perks`, `FitnessExercises`, `SandboxVars = nil`,
     `require = function() end`. Collect these by reading the top of every
     existing test; keep the union, name for name.
   - `H.load(...)`: loads mod files by short name from
     `../DanTraits/42/media/lua/shared/` (or a path given with a slash), core
     first if not already loaded. Resolve paths from the harness file's own
     location so a test also runs from the repo root.
   - `H.player(opts)`: the shared `makePlayer`, a superset of the existing
     variants (stats table `_st` with get/set, mod data `_md`, `_asleep`,
     `_outside`, traits set, body damage with parts when `opts.parts`,
     `getPainEffect`, `getNutrition`, `getFitness`, inventory). Where two
     existing `makePlayer`s disagree on a field name, pick one and adapt the
     tests that used the other.
   - `H.near(a, b, eps, msg)`, `H.mins(n, fn)` (run a minute handler n
     times), `H.pass(name)` printing `"<name>: all checks passed"`.
2. Port every `test_*.lua` to the harness. Keep every assertion. Delete
   duplicated stub blocks. Where a test relied on the overwrite stub, use
   `H.only` or `H.fire`.
3. Fix the two non-standard pass lines (`test_phantom`, `test_distributions`)
   to `H.pass`, and tighten `run_tests.py` to require the exact
   `": all checks passed"` suffix.
4. Add a header comment to `test_phantom.lua` and `test_distributions.lua`.
5. Remove the tautologies the audit found: `test_asthma.lua:135`
   (`== nil or true`), `test_concussion.lua:157` (and/or precedence),
   `test_concussion.lua:78` (accepts either outcome), `test_woundcare.lua:142`.
   Make each assert one thing; if the behaviour is genuinely random, seed
   `ZombRand` through the harness so it is deterministic.

## Acceptance

- Suite green with the same number of test files.
- `grep -l "local function makePlayer" tests/*.lua` is empty;
  `grep -l "__index = function(_, name)" tests/*.lua` lists only `harness.lua`.
- `cd tests && npx -y -p fengari-node-cli fengari test_smoker.lua` and the
  same from the repo root both work.
