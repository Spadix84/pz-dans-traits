# 23. Report: the character went invisible (2026-09-29)

Not a plan: a record of an incident during the play test of the ten new
traits, sun block and moodles, so it can be recognised if it happens again.
Cause unknown. Nothing in the mod was found to be responsible, and nothing
was changed for it.

## What happened

- Build: commit eee0e46 (the new-traits fixes, sun block and moodles),
  deployed to `~/Zomboid/mods/DanTraits`, game started with `-debug`,
  Developer Tools telemetry running, Moodle Framework loaded.
- A fresh test character (no traits, a cleared area, no zombies in the cell)
  was given Heart Condition by console and put through a forced heart attack
  (`heart attack`): the shared pass-out (`DanTraits_PassOut`, deep) for about
  13 game minutes, health 100 to 85, endurance 0. While out, a test scratch
  was put on the left hand (`wound hand_l scratch`) to confirm a deep
  blackout ignores it. The character came round ("You come round, grey and
  weak") and was left sitting on the ground, as every pass-out leaves them
  (only a movement key ends `EventSitOnGround`).
- Clean-up commands were then sent: `trait remove heart`, the heart mod-data
  fields cleared, `stat ENDURANCE 1`, and one Lua line:
  `player:getBodyDamage():getBodyPart(BodyPartType.Hand_L):RestoreToFullHealth();
  player:getBodyDamage():RestoreToFullHealth()`, then `give DanTraits.Sunblock 1`.
- Some time after that (the user was moving the character; the exact moment
  is not known) the user reported the character model had gone invisible.
- Reloading the save did not bring it back. Quitting the game to desktop and
  relaunching did.

## What was read from the character

Before the relaunch, with the game briefly unpaused, one inspection line got
as far as `sitting=false out=false blocked=false ignoreMove=false` before it
died on `getAlpha()` called without the player-index argument it takes,
which halted the game on the debugger's Break On Error. So the pass-out had released the character
(no block, no ignore-movement, not sitting) and the mod's own hold was off.
The `isInvisible` value was not captured (cut off in the debugger's object
stack).

After the relaunch, on the same save: `isInvisible=false`, not sitting, not
blocked, no mod state left over, no Lua errors from the mod anywhere in
`console.txt` for the whole session.

## What the mod does that touches the model

- `DanTraits_Collapse`: the shove-fall (`setBumpType("stagger")`, BumpFall
  variables). Used by every pass-out since the concussion work and by the
  alcohol-withdrawal seizure; hundreds of uses in play without this.
- `DanTraits_PassOut`: `setBlockMovement`, `setIgnoreMovement`,
  `setAuthorizeMeleeAction`, `setAuthorizeShoveStomp`, `UIManager.FadeOut`
  and `FadeIn` (the screen, not the model), `reportEvent("EventSitOnGround")`.
- The Germaphobe test earlier the same evening (a different character) set
  blood on the body visual with `getHumanVisual():setBlood` and called
  `resetModelNextFrame()`; that character was not the one that went
  invisible, and the flag was not used on this one.
- Nothing in the mod calls `setInvisible`, changes alpha, or touches the
  model's textures.

## Hypotheses, most likely first

1. Debug mode's own invisibility. Debug builds have a per-player invisible
   toggle (used by the debug menu and a key binding) that survives a save
   reload because it is on the player object, and a fresh process starts
   with it off. That matches "reload did nothing, relaunch fixed it" exactly.
   The `isInvisible` read after the relaunch was false, as it would be.
2. `RestoreToFullHealth()` on the whole body while the character was in the
   post-blackout sit state. Unlikely (the method only writes body part
   fields), but it was the one unusual call made to that character.
3. A model reset missed after the sit-on-ground state ended while the fade
   was still finishing. Would not explain a save reload failing to fix it.

## If it happens again

- Do not reload yet. With the game unpaused, read
  `player:isInvisible()`, `player:isSitOnGround()`, `player:isBlockMovement()`,
  `player:isIgnoreMovement()` and `player:getBumpType()` through the console
  (all exist on `IsoPlayer` and take no argument; `getAlpha` needs a player index).
- If `isInvisible` is true, `lua player:setInvisible(false)` should bring the
  model back at once and confirms hypothesis 1.
- Note what the character was doing at the moment it vanished, and whether
  any debug window was open.
