-- Offline test for DanTraits_Bathing.lua (Take A Bath And Shower compatibility):
-- the bath mod's OnBathingEnd event is picked up at game start, once; a bath
-- washes sun block off the local player and says so; nothing for a character
-- with none on, and another character's bath is not ours. (The harness
-- creates any event on demand, so the event is always "present" here; the
-- absent-mod path is the nil check in install, covered by inspection.)
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Sunburn", "Bathing")

H.fire("OnGameStart"); H.fire("OnGameStart")
local bathEnd = H.on("OnBathingEnd")

-- 1. a bath washes sun block off, with one notice (installed once), none on: nothing said
local p = H.player(); H.current = p
DanTraits_ApplySunblock(p, 480)
assert(DanTraits_SunblockLeft(p) == 480, "sun block on")
H.clearHalo()
bathEnd(p)
assert(DanTraits_SunblockLeft(p) == 0, "washed off")
local told = 0
for _, t in ipairs(H.halo) do if t == "UI_DanTraits_SunblockWashed" then told = told + 1 end end
assert(told == 1, "told once (one handler, however many game starts)")
H.clearHalo()
bathEnd(p)
assert(#H.halo == 0, "nothing on: nothing said")

-- 2. another character's bath is not ours
local other = H.player()
DanTraits_ApplySunblock(other, 480)
bathEnd(other)
assert(DanTraits_SunblockLeft(other) == 480, "not the local player: left alone")

-- 3. in the water: the mode while that mod's flag is up, wet until it calls you dry
local bathStart = H.on("OnBathingStart")
local md = p:getModData()
assert(DanTraits_BathingMode(p) == nil and not DanTraits_BathingWet(p), "dry and out")
md.tabas_IsBathing = true
bathStart(p, "SHOWER")
assert(DanTraits_BathingMode(p) == "SHOWER" and DanTraits_BathingWet(p), "in the shower")
bathStart(p, "BATH")
assert(DanTraits_BathingMode(p) == "BATH", "in the bath")
md.tabas_IsBathing = nil
md.tabas_HasBathingWet = true
bathEnd(p)
assert(DanTraits_BathingMode(p) == nil and DanTraits_BathingWet(p), "out, still wet from it")
md.tabas_HasBathingWet = nil
assert(not DanTraits_BathingWet(p), "dry again")
md.tabas_IsBathing = true
assert(DanTraits_BathingMode(p) == "BATH", "flag up with no start seen (a reload): a bath")
md.tabas_IsBathing = nil

H.pass()
