-- Offline test for DanTraits_Germaphobe.lua: grime from dirty clothes,
-- stress and low mood while filthy, relief when clean, the infection
-- hazard cut, and nothing without the trait.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
H.load("Germaphobe")
H.expectEvery("minute", "Germaphobe")

local near = H.near
local function part(name, dirty)
  return { _dirty = dirty, getType = function() return name end, hasDirtyClothing = function(self) return self._dirty end }
end
local parts = { part("Torso_Upper", true), part("Torso_Lower", true), part("Hand_L", false), part("Hand_R", false) }

-- 1. half the body under dirty clothes: grime 0.5, stress builds, mood held down, one notice
local p = H.player({ traits = { "germaphobe" }, parts = parts }); H.current = p
local d = DanTraits_Data(p)
near(DanTraits_GermGrime(p, d), 0.5, 1e-9, "grime from clothes")
H.mins(10)
near(p._st.stress, 10 * 0.0006 * 0.5, 1e-9, "stress builds")
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

-- 4. without the trait: nothing
local plain = H.player({ parts = { part("Torso_Upper", true) } }); H.current = plain
H.mins(10)
assert(plain._st.stress == 0 and plain._st.unhappy == 0, "no trait: no stress")
near(DanTraits_RunHooks("infectionHazard", 1, plain, parts[1]), 1, 1e-9, "no trait: hazard as is")

H.pass()
