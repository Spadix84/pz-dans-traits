-- Offline test for DanTraits_Sleep.lua: light sets how deep the sleep is
-- (rest rate, the night's score) and whether it wakes you; exhaustion, drink
-- and sleeping pills sleep through it; Deep Sleeper cuts the wakes, halves
-- the bright penalty, boosts the dark bonus and grants Wakeful once;
-- Restless Sleeper, Night Owl, Cat's Eyes, caffeine and the sleepWake hook
-- raise the wake chance; Desensitized has nightmares; Restless Sleeper's two
-- halves are one night.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local woken = {}
function getSleepingEvent() return { wakeUp = function(_, p) woken[#woken + 1] = p; p._asleep = false end } end

-- a stand-in for Age's wake scaling (the 50s: x1.3 on the wakes over the morning one), registered
-- before Sleep loads as the game loads them, so by load order it would run before the free wake
H.load("DanTraits")
DanTraits_AddHook("nightWakes", function(wakes, player) if not (player and player._fifties) then return nil end; return 1 + (wakes - 1) * 1.3 end)
H.load("Caffeine", "Sleep")
H.expectHooks("OnCreatePlayer", "OnGameStart")
H.expectEvery("minute", "Sleep")

-- a sleeper by default, half tired, in a room with this much light and this many sleeping-pill hours
local newPlayer = H.factory({ fatigue = 0.5, asleep = true }, function(p, o)
  p._light, p._tablets = o.light or 0, o.tablets or 0
end)
local halo, near = H.halo, H.near
local minute = H.minute

-- 1. darkness: +1 at or below 0.25, -1 at or above 0.6, 0 at the reading line
near(DanTraits_SleepDarkness(0.0), 1, 1e-9, "pitch dark")
near(DanTraits_SleepDarkness(0.25), 1, 1e-9, "dark line")
near(DanTraits_SleepDarkness(0.425), 0, 1e-9, "midpoint")
near(DanTraits_SleepDarkness(0.9), -1, 1e-9, "lit room")

-- 2. rest: the game's drop in tiredness is scaled, +15% dark, -15% lit; a rise is left alone
H.roll = 9999
local dark = newPlayer({ light = 0.1 }); H.current = dark
minute(); dark._st.fatigue = 0.4; minute()
near(dark._st.fatigue, 0.5 - 0.1 * 1.15, 1e-9, "dark: rest faster")
local lit = newPlayer({ light = 0.9 }); H.current = lit
minute(); lit._st.fatigue = 0.4; minute()
near(lit._st.fatigue, 0.5 - 0.1 * 0.85, 1e-9, "lit: rest slower")
lit._st.fatigue = 0.6; minute(); near(lit._st.fatigue, 0.6, 1e-9, "a rise is left alone")
local awake = newPlayer({ light = 0.9, asleep = false }); H.current = awake
minute(); awake._st.fatigue = 0.4; minute(); near(awake._st.fatigue, 0.4, 1e-9, "awake: untouched")

-- 3. wake chance, percent per minute: 0 when dark or dim; 50%/hour fully lit, rested and sober
near(DanTraits_SleepWakeChance(lit, 1, 0, 0), 0, 1e-9, "dark: never")
near(DanTraits_SleepWakeChance(lit, 0.2, 0, 0), 0, 1e-9, "dim: never")
near(DanTraits_SleepWakeChance(lit, -1, 0, 0), 50 / 60, 1e-9, "fully lit")
near(DanTraits_SleepWakeChance(lit, -0.5, 0, 0), 25 / 60, 1e-9, "half lit")
near(DanTraits_SleepWakeChance(lit, -1, 1, 0), 50 / 60 * 0.3, 1e-9, "exhausted sleeps through most of it")
near(DanTraits_SleepWakeChance(lit, -1, 0, 1), 50 / 60 * 0.1, 1e-9, "drunk sleeps through most of it")
local deep = newPlayer({ traits = { "deepsleeper" }, light = 0.9 })
near(DanTraits_SleepWakeChance(deep, -1, 0, 0), 50 / 60 * 0.25, 1e-9, "deep sleeper: a quarter")

-- 4. waking: never in the first half hour; after that a winning roll wakes you, once, with a notice
H.roll = 0
local bright = newPlayer({ light = 0.9, fatigue = 0 }); H.current = bright
for _ = 1, 29 do minute() end
assert(#woken == 0 and bright._asleep, "settling in: no wake")
minute()
assert(#woken == 1 and woken[1] == bright and not bright._asleep, "woke on minute 30")
assert(halo[#halo] == "UI_DanTraits_SleepLightWoke", "notice")
near(bright._md.DanTraits.slLightWakes, 1, 0, "counted")
minute(); assert(#woken == 1, "awake: no second wake")
local pills = newPlayer({ light = 0.9, fatigue = 0, tablets = 500 }); H.current = pills
for _ = 1, 60 do minute() end
assert(#woken == 1, "sleeping pills: slept through")
local black = newPlayer({ light = 0.05, fatigue = 0 }); H.current = black
for _ = 1, 60 do minute() end
assert(#woken == 1, "dark: slept through")

-- 5. the night's score: average darkness while asleep, +0.1 dark, -0.15 lit, consumed once
near(DanTraits_RunHooks("nightQuality", 0.5, black, black._md.DanTraits), 0.6, 1e-9, "dark night +0.1")
near(DanTraits_RunHooks("nightQuality", 0.5, black, black._md.DanTraits), 0.5, 1e-9, "consumed")
H.roll = 9999
local litNight = newPlayer({ light = 0.9 }); H.current = litNight
for _ = 1, 60 do minute() end
near(DanTraits_RunHooks("nightQuality", 0.5, litNight, litNight._md.DanTraits), 0.35, 1e-9, "lit night -0.15")
near(DanTraits_RunHooks("nightQuality", 0.5, litNight, {}), 0.5, 1e-9, "no sleep recorded: untouched")

-- 6. Deep Sleeper: bright penalties halved, dark bonuses x1.5
H.current = deep
minute(); deep._st.fatigue = 0.4; minute()
near(deep._st.fatigue, 0.5 - 0.1 * (1 - 0.15 * 0.5), 1e-9, "deep: bright rest penalty halved")
near(DanTraits_RunHooks("nightQuality", 0.5, deep, deep._md.DanTraits), 0.5 - 0.15 * 0.5, 1e-9, "deep: bright score penalty halved")
deep._light = 0.1; deep._st.fatigue = 0.5; minute(); deep._st.fatigue = 0.4; minute()
near(deep._st.fatigue, 0.5 - 0.1 * (1 + 0.15 * 1.5), 1e-9, "deep: dark rest bonus x1.5")
near(DanTraits_RunHooks("nightQuality", 0.5, deep, deep._md.DanTraits), 0.65, 1e-9, "deep: dark score bonus x1.5")

-- 7. Deep Sleeper grants Wakeful, once; others are left alone
H.current = deep
H.fire("OnCreatePlayer", 0, deep)
assert(deep._traits["base:needslesssleep"], "Wakeful granted")
H.fire("OnGameStart")
assert(deep._adds == 1, "granted once")
local plain = newPlayer(); H.current = plain
H.fire("OnCreatePlayer", 0, plain); H.fire("OnGameStart")
assert(not plain._traits["base:needslesssleep"], "no trait: no Wakeful")

-- 8. who you are: x1.5 each for Restless Sleeper, Night Owl, Cat's Eyes; the hook; Deep Sleeper last
local base = 50 / 60
near(DanTraits_SleepWakeChance(newPlayer({ vanilla = { "base:insomniac" } }), -1, 0, 0, {}), base * 1.5, 1e-9, "restless sleeper")
near(DanTraits_SleepWakeChance(newPlayer({ vanilla = { "base:nightowl" } }), -1, 0, 0, {}), base * 1.5, 1e-9, "night owl")
near(DanTraits_SleepWakeChance(newPlayer({ vanilla = { "base:nightvision" } }), -1, 0, 0, {}), base * 1.5, 1e-9, "cat's eyes")
near(DanTraits_SleepWakeChance(newPlayer({ vanilla = { "base:nightowl", "base:nightvision" } }), -1, 0, 0, {}), base * 2.25, 1e-9, "they stack")
DanTraits_AddHook("sleepWake", function(m, player, d) if d and d.testEpisode then return m * 3 end end)
near(DanTraits_SleepWakeChance(newPlayer(), -1, 0, 0, { testEpisode = true }), base * 3, 1e-9, "hook")
near(DanTraits_SleepWakeChance(newPlayer({ traits = { "deepsleeper" } }), -1, 0, 0, { testEpisode = true }), base * 3 * 0.25, 1e-9, "deep sleeper applies last")

-- 9. caffeine, anyone: a mug of coffee (100) is six hours on edge, a cup of tea (37) pro rata; x2 while it lasts; it runs out
local cup = newPlayer({ asleep = false }); H.current = cup
DanTraits_CaffeineDose(cup, 37, "tea")
near(cup._md.DanTraits.slCaffeineHours, 6 * 37 / 80, 1e-9, "tea: pro rata")
DanTraits_CaffeineDose(cup, 100, "coffee")
near(cup._md.DanTraits.slCaffeineHours, 6, 1e-9, "coffee: six hours")
assert(cup._md.DanTraits.cafLevel == nil, "no trait: no habit tracked")
DanTraits_CaffeineDose(cup, 20, "chocolate")
near(cup._md.DanTraits.slCaffeineHours, 6, 1e-9, "a small dose never shortens it")
near(DanTraits_SleepWakeChance(cup, -1, 0, 0, cup._md.DanTraits), base * 2, 1e-9, "on edge: x2")
for _ = 1, 360 do minute() end
near(cup._md.DanTraits.slCaffeineHours, 0, 1e-9, "worn off after six hours")
near(DanTraits_SleepWakeChance(cup, -1, 0, 0, cup._md.DanTraits), base, 1e-9, "back to normal")

-- 10. Desensitized: nightmares after the first half hour, even in the dark and on pills; stress and mood hit
H.roll = 0
local vet = newPlayer({ vanilla = { "base:desensitized" }, light = 0.05, tablets = 500 }); H.current = vet
local before = #woken
for _ = 1, 29 do minute() end
assert(#woken == before, "settling in: no nightmare")
minute()
assert(#woken == before + 1 and halo[#halo] == "UI_DanTraits_SleepNightmare", "nightmare wakes you")
near(vet._st.stress, 0.15, 1e-9, "stress"); near(vet._st.unhappy, 10, 1e-9, "mood")
H.roll = 9999
local calm = newPlayer({ light = 0.05 }); H.current = calm; before = #woken
for _ = 1, 120 do minute() end
assert(#woken == before, "no trait: no nightmares")

-- 11. Restless Sleeper: sleeps up to three hours apart are one night, and the wake between them is free
local rs = newPlayer({ vanilla = { "base:insomniac" } })
near(DanTraits_RunHooks("nightGap", 60, rs), 180, 0, "three-hour gap")
near(DanTraits_RunHooks("nightGap", 60, plain), 60, 0, "others: an hour")
near(DanTraits_RunHooks("nightWakes", 2, rs), 1, 0, "the planned wake is free")
near(DanTraits_RunHooks("nightWakes", 3, rs), 2, 0, "later ones still count")
near(DanTraits_RunHooks("nightWakes", 1, rs), 1, 0, "never below one")
near(DanTraits_RunHooks("nightWakes", 2, plain), 2, 0, "others: every wake counts")
-- the free wake comes off before the age scaling registered above (Sleep's hook at order 10): a
-- Restless Sleeper in their 50s with the planned wake pays nothing, with one more pays 1.3 of it
rs._fifties = true
near(DanTraits_RunHooks("nightWakes", 2, rs), 1, 1e-9, "50s Restless Sleeper, the planned wake: free, not 0.6 of a wake")
near(DanTraits_RunHooks("nightWakes", 3, rs), 1 + 1.3, 1e-9, "...and one more: that one scaled")

-- a fever is a bad night: the score x (1 - 0.3 fever), light wakes you x (1 + 0.5 fever)
local feverish = newPlayer({ light = 0.9 }); H.current = feverish
near(DanTraits_RunHooks("nightQuality", 0.5, feverish, {}), 0.5, 1e-9, "no fever: score untouched")
near(DanTraits_SleepWakeMultiplier(feverish, {}), 1, 1e-9, "no fever: wake multiplier 1")
DanTraits_InfectionFever = function() return 1 end
near(DanTraits_RunHooks("nightQuality", 0.5, feverish, {}), 0.35, 1e-9, "full fever: score x0.7")
near(DanTraits_SleepWakeMultiplier(feverish, {}), 1.5, 1e-9, "full fever: wakes x1.5")
DanTraits_InfectionFever = function() return 0.5 end
near(DanTraits_SleepWakeMultiplier(feverish, {}), 1.25, 1e-9, "half fever: wakes x1.25")
DanTraits_InfectionFever = nil

-- sandbox: SleepLightEnabled = false reads light as neutral: no faster or slower rest, no light wake
SandboxVars = { DanTraits = { SleepLightEnabled = false } }
H.roll = 0
local off = newPlayer({ light = 0.9, fatigue = 0.5 }); H.current = off
local wokenBefore = #woken
minute(); off._st.fatigue = 0.4; minute()
near(off._st.fatigue, 0.4, 1e-9, "off: rest is the game's")
for _ = 1, 60 do minute() end
assert(#woken == wokenBefore and off._asleep, "off: bright light does not wake")
SandboxVars = nil

-- 10. with Vitality off nothing scores the night: the light tally is dropped on waking, not kept for ever
-- (review 2026-10-16 A1.12); with Vitality on it waits for the scorer
H.roll = 9999
local unscored = newPlayer({ light = 0.1 }); H.current = unscored
for _ = 1, 5 do minute() end
assert(unscored._md.DanTraits.slNightMin == 5, "five minutes tallied")
unscored._asleep = false
SandboxVars = { DanTraits = { VitalityEnabled = false } }
minute()
assert(unscored._md.DanTraits.slNightMin == 0 and unscored._md.DanTraits.slNightDark == 0, "awake with Vitality off: dropped")
SandboxVars = nil
local scored = newPlayer({ light = 0.1 }); H.current = scored
for _ = 1, 5 do minute() end
scored._asleep = false; minute()
assert(scored._md.DanTraits.slNightMin == 5, "awake with Vitality on: kept for the night's score")

-- 12. clothes in bed: sleepwear is free; other slots add up to 1; warm clothes fade from 20C to 10C
-- and are free while cold; gear always counts; slower rest, a worse score, Deep Sleeper half, a notice
H.roll = 9999
local function dress(p, ...)
  p._worn = {}
  for _, loc in ipairs({ ... }) do p._worn[#p._worn + 1] = { type = "Base.X", name = loc, loc = "base:" .. loc } end
end
local cost = DanTraits_SleepClothesCost
local bed = newPlayer({ light = 0.425, moodles = {} }); H.current = bed
MoodleType = { HYPOTHERMIA = "HYPOTHERMIA" }
dress(bed, "tshirt", "underwear_bottom", "socks", "shorts_short", "necklace", "eyes")
near(cost(bed), 0, 1e-9, "sleepwear and jewellery: free")
dress(bed, "pants", "shirt", "shoes")
near(cost(bed), 0.65, 1e-9, "jeans, shirt, shoes at 20C")
H.climate.temp = 15
near(cost(bed), 0.25 + (0.25 + 0.15) / 2, 1e-9, "15C: warm clothes at half, shoes in full")
H.climate.temp = 5; near(cost(bed), 0.25, 1e-9, "5C: only the shoes")
H.climate.temp = 20; bed._moodles.HYPOTHERMIA = 1
near(cost(bed), 0.25, 1e-9, "feeling cold: warm clothes free")
bed._moodles.HYPOTHERMIA = 0
dress(bed, "pants", "shirt", "sweater", "jacketbulky", "shoes", "back", "webbing")
near(cost(bed), 1, 1e-9, "fully kitted: capped at 1")
-- the game's own spellings (B42 scripts: base:sweaterhat, base:fullsuit, base:maskfull;
-- 2026-10-22: the table kept underscores and 34 of 72 slots never matched)
dress(bed, "sweaterhat", "fullsuit", "maskfull")
near(cost(bed), 0.25 + 0.4 + 0.2, 1e-9, "hoodie, hazmat suit, gas mask with B42 ids")
H.climate.temp = 5; near(cost(bed), 0.2, 1e-9, "5C: only the mask counts"); H.climate.temp = 20
dress(bed, "Sweater_Hat", "Full_Suit", "Mask_Full")
near(cost(bed), 0.25 + 0.4 + 0.2, 1e-9, "the B41 spellings land on the same slots")
SandboxVars = { DanTraits = { SleepClothesEnabled = false } }
near(cost(bed), 0, 1e-9, "off: free")
SandboxVars = nil

-- rest x (1 - 0.12 x cost), score -0.1 x cost
dress(bed, "pants", "shirt", "shoes")
bed._st.fatigue = 0.5; minute(); bed._st.fatigue = 0.4; minute()
near(bed._st.fatigue, 0.5 - 0.1 * (1 - 0.12 * 0.65), 1e-6, "dressed: rest slower")
near(DanTraits_RunHooks("nightQuality", 0.5, bed, bed._md.DanTraits), 0.5 - 0.1 * 0.65, 1e-6, "dressed: night scores worse")
local deepBed = newPlayer({ traits = { "deepsleeper" }, light = 0.425 }); H.current = deepBed
dress(deepBed, "pants", "shirt", "shoes")
deepBed._st.fatigue = 0.5; minute(); deepBed._st.fatigue = 0.4; minute()
near(deepBed._st.fatigue, 0.5 - 0.1 * (1 - 0.12 * 0.65 * 0.5), 1e-6, "deep sleeper: half the rest cost")
near(DanTraits_RunHooks("nightQuality", 0.5, deepBed, deepBed._md.DanTraits), 0.5 - 0.1 * 0.65 * 0.5, 1e-6, "deep sleeper: half the score cost")

-- the notice: on waking after an hour or more dressed at 0.25 or worse; not in sleepwear, not after a short nap
local function sleepFor(p, minutes)
  H.current = p; p._asleep = true
  for _ = 1, minutes do minute() end
  local n = #halo
  p._asleep = false; minute()
  return #halo > n and halo[#halo] == "UI_DanTraits_SleepClothed"
end
assert(sleepFor(bed, 60), "an hour dressed: told on waking")
assert(not sleepFor(bed, 30), "half an hour: no notice")
dress(bed, "tshirt", "underwear_bottom")
assert(not sleepFor(bed, 120), "sleepwear: no notice")
dress(bed, "belt", "shoes")
assert(sleepFor(bed, 60), "shoes on: told")
MoodleType = nil
H.pass()
