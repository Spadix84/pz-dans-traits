-- Offline test for DanTraits_Tinnitus.lua: shots build a noise load that
-- decays, a burst puts Hard of Hearing on (and Keen Hearing off) for a while,
-- more shooting adds time, the ears come back, melee and other people's
-- swings do nothing, and the ringing makes sleep lighter.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
CharacterTrait.HARD_OF_HEARING = "base:hardofhearing"
CharacterTrait.KEEN_HEARING = "base:keenhearing"
H.load("Tinnitus")
H.expectEvery("minute", "Tinnitus")
H.expectHooks("OnWeaponSwing")

local near = H.near
local swing = H.on("OnWeaponSwing")
local function gun(radius) return { isRanged = function() return true end, getSoundRadius = function() return radius end } end
local bat = { isRanged = function() return false end }

-- 1. shots add to the load by loudness; a bat adds nothing; the load halves in ten minutes
local p = H.player({ traits = { "tinnitus" }, vanilla = { "base:keenhearing" } }); H.current = p
local d = DanTraits_Data(p)
swing(p, gun(50)); swing(p, gun(50))
near(d.tnNoise, 2, 1e-9, "two pistol shots")
swing(p, bat); near(d.tnNoise, 2, 1e-9, "melee: nothing")
swing(H.player(), gun(50)); near(d.tnNoise, 2, 1e-9, "someone else's shot: nothing")
H.mins(10); near(d.tnNoise, 1, 1e-6, "halved in ten minutes")

-- 2. a burst: half deaf, Keen Hearing off, one notice
swing(p, gun(150)); swing(p, gun(150))   -- 3 each, capped
assert(p._traits["base:hardofhearing"] and not p._traits["base:keenhearing"], "Hard of Hearing on, Keen Hearing off")
assert(d.tnDeafMin >= 30, "at least half an hour")
local notices = #H.halo
assert(H.halo[notices] == "UI_DanTraits_TinnitusRinging", "ringing notice")
local before = d.tnDeafMin
swing(p, gun(150))
assert(d.tnDeafMin > before and #H.halo == notices, "more shooting adds time, no second notice")
near(DanTraits_RunHooks("sleepWake", 1, p, d), 1.5, 1e-9, "the ringing makes sleep lighter")

-- 3. the time runs out: hearing back as it was
H.mins(math.ceil(d.tnDeafMin) + 1)
assert(not p._traits["base:hardofhearing"] and p._traits["base:keenhearing"], "Hard of Hearing off, Keen Hearing back")
assert(H.halo[#H.halo] == "+UI_DanTraits_TinnitusFaded", "faded notice")
near(DanTraits_RunHooks("sleepWake", 1, p, d), 1, 1e-9, "sleep as before")

-- 4. without the trait gunfire does nothing
local plain = H.player(); H.current = plain
for _ = 1, 10 do swing(plain, gun(150)) end
assert(not plain._traits["base:hardofhearing"], "no trait: no deafness")

-- 5. the trait taken away while ringing: the ears come back at once
local q = H.player({ traits = { "tinnitus" } }); H.current = q
DanTraits_ExtraCommands.tinnitus(q, { "ring", "60" })
assert(q._traits["base:hardofhearing"], "ringing")
q._traits.tinnitus = nil
H.minute()
assert(not q._traits["base:hardofhearing"], "trait gone: hearing back")

H.pass()
