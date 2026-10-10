-- Offline test for DanTraits_Germaphobe.lua: grime from dirty or bloody clothes and a bloody weapon,
-- stress and low mood while filthy, relief when clean, the infection
-- hazard cut, and nothing without the trait.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Germaphobe")
H.expectEvery("minute", "Germaphobe")

local near = H.near
local function part(name, dirty, bloody)
  return { _dirty = dirty, _bloody = bloody == true, getType = function() return name end,
           hasDirtyClothing = function(self) return self._dirty end, hasBloodyClothing = function(self) return self._bloody end }
end
local parts = { part("Torso_Upper", true), part("Torso_Lower", true), part("Hand_L", false), part("Hand_R", false) }

-- 0. body grime is the worst four parts, not the average of all of them
near(DanTraits_GermWorstMean({ 0, 0.8, 0, 0.4, 0, 0, 1, 0, 0.2, 0, 0, 0 }), 0.6, 1e-9, "the four worst")
near(DanTraits_GermWorstMean({ 0.5 }), 0.125, 1e-9, "a short list: the missing parts are clean")

-- 1. half the body under dirty clothes: grime 0.75, stress builds, mood held down, one notice
local p = H.player({ traits = { "germaphobe" }, parts = parts }); H.current = p
local d = DanTraits_Data(p)
near(DanTraits_GermGrime(p, d), 0.75, 1e-9, "grime from clothes")
H.mins(10)
near(p._st.stress, 10 * 0.002 * 0.75, 1e-9, "stress builds")
assert(p._st.unhappy > 0, "mood held down")
local filthy = 0
for _, t in ipairs(H.halo) do if t == "UI_DanTraits_GermFilthy" then filthy = filthy + 1 end end
assert(filthy == 1, "one notice")

-- 2. changed into clean clothes: relief
p._st.stress, p._st.unhappy = 0.5, 30
parts[1]._dirty, parts[2]._dirty = false, false
H.minute()
near(p._st.stress, 0.4, 1e-9, "stress drops")
near(p._st.unhappy, 20, 1e-9, "and misery")
assert(H.halo[#H.halo] == "+UI_DanTraits_GermClean", "clean at last")

-- 3. the infection hazard: a fifth lower
near(DanTraits_RunHooks("infectionHazard", 1, p, parts[1]), 0.8, 1e-9, "hazard x0.8")

-- 3b. bloody clothes count like dirty ones; the blood on a held weapon counts too
local bl = { part("Torso_Upper", false, true), part("Torso_Lower", false), part("Hand_L", false), part("Hand_R", false) }
local b = H.player({ traits = { "germaphobe" }, parts = bl }); H.current = b
near(DanTraits_GermGrime(b, DanTraits_Data(b)), 0.375, 1e-9, "one part in four under a bloody shirt: 0.375")
bl[1]._bloody = false
b.getPrimaryHandItem = function() return { getBloodLevel = function() return 100 end } end
near(DanTraits_GermGrime(b, DanTraits_Data(b)), 0.5, 1e-9, "a dripping weapon: 0.5")
b.getPrimaryHandItem = function() return { getBloodLevel = function() return 40 end } end
near(DanTraits_GermGrime(b, DanTraits_Data(b)), 0.2, 1e-9, "a spattered one: 0.2")
b.getPrimaryHandItem = function() return { name = "clean bat" } end
near(DanTraits_GermGrime(b, DanTraits_Data(b)), 0, 1e-9, "an item with no blood level: nothing")
b.getSecondaryHandItem = function() return { getBloodLevel = function() return 60 end } end
near(DanTraits_GermGrime(b, DanTraits_Data(b)), 0.3, 1e-9, "the off hand counts too")

-- 4. without the trait: nothing
local plain = H.player({ parts = { part("Torso_Upper", true) } }); H.current = plain
H.mins(10)
assert(plain._st.stress == 0 and plain._st.unhappy == 0, "no trait: no stress")
near(DanTraits_RunHooks("infectionHazard", 1, plain, parts[1]), 1, 1e-9, "no trait: hazard as is")

H.pass()
