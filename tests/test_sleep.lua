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

H.pass()
