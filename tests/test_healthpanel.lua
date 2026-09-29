-- Offline test for DanTraits_HealthPanel.lua: the wrapped list drawing
-- rewords, drops and dedupes the installed doDrawItem's lines by First Aid
-- level, closes up the gaps, adds this mod's own lines (infection, dressing,
-- stitches, bone), and leaves the debug view alone.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local TEXT = { IGUI_health_Scratched = "Scratched", IGUI_health_Cut = "Cut", IGUI_health_DeepWound = "Deep Wound",
  IGUI_health_Bitten = "Bitten", IGUI_health_Fracture = "Fracture", IGUI_health_Infected = "Infected",
  IGUI_health_Severe = "Severe", IGUI_health_Moderate = "Moderate", IGUI_health_Stitched = "Stitched",
  IGUI_health_Good = "Good", IGUI_health_NeedTime = "Need time", IGUI_health_Splinted = "Splinted" }
function getText(k) return TEXT[k] or k end
UIFont = { Small = "small" }
function getTextManager() return { getFontHeight = function() return 10 end } end
ISHealthPanel = { cheat = false }

-- stands in for vanilla (or NestedHealthInfo): draws what it is told to, 10 px a line, +5 at the end
local toDraw = {}
ISHealthBodyPartListBox = {}
function ISHealthBodyPartListBox:doDrawItem(y, item)
  self:drawText("Left Forearm", 0, y); y = y + 10
  for _, s in ipairs(toDraw) do self:drawText(s, 15, y); y = y + 10 end
  return y + 5
end

H.load("client/DanTraits_HealthPanel.lua")
H.fire("OnGameStart")

local function makePart(o)
  o = o or {}
  local p = { _stitch = o.stitch or 0, _life = o.life or 0, _bandaged = o.bandaged or false, _fracture = o.fracture or 0 }
  function p:getType() return "ForeArm_L" end
  function p:getStitchTime() return self._stitch end
  function p:getBandageLife() return self._life end
  function p:bandaged() return self._bandaged end
  function p:getFractureTime() return self._fracture end
  return p
end

-- draw one part at a level; returns the lines drawn and the end y
local function draw(level, lines, part, md)
  toDraw = lines
  local drawn = {}
  local patient = { getModData = function() return { DanTraits = md or {} } end }
  local box = setmetatable({ parent = { doctorLevel = level, getPatient = function() return patient end },
    drawText = function(_, s, x, y) drawn[#drawn + 1] = { s = s, y = y } end }, { __index = ISHealthBodyPartListBox })
  local yEnd = box:doDrawItem(100, { item = { bodyPart = part or makePart() } })
  return drawn, yEnd
end
local function texts(drawn) local t = {} for _, d in ipairs(drawn) do t[#t + 1] = d.s end return table.concat(t, " | ") end

-- 1. a layperson: wound types in plain words, no severity, a break "might be", the game's infection dropped
local d, y = draw(0, { "- Scratched (Severe)", "- Cut", "- Deep Wound Severe", "- Fracture ", "- Infected", "- Bleeding" })
assert(texts(d) == "Left Forearm | - UI_DanTraits_health_Scratch | - UI_DanTraits_health_Cut | - UI_DanTraits_health_BadCut | - UI_DanTraits_health_MaybeBroken | - Bleeding", texts(d))
assert(d[6].y == 150 and y == 165, "closed up: one line dropped, " .. tostring(d[6].y) .. " / " .. tostring(y))

-- 2. two cuts read the same to a layperson: one line
d, y = draw(1, { "- Cut", "- Cut (Moderate)" })
assert(texts(d) == "Left Forearm | - UI_DanTraits_health_Cut" and y == 125, texts(d))

-- 3. level 3+: the game's own detail stands (bar its infection line, replaced by ours)
d = draw(4, { "- Scratched (Severe)", "- Fracture Severe", "- Infected" })
assert(texts(d) == "Left Forearm | - Scratched (Severe) | - Fracture Severe", texts(d))

-- 4. nested lines under a bandage ("     * ") are reworded too
d = draw(0, { "- Bandaged", "     * Deep Wound" })
assert(texts(d) == "Left Forearm | - Bandaged |      * UI_DanTraits_health_BadCut", texts(d))

-- 5. infection by level: hidden, red and swollen, infected, the stage; hidden until level 9 while it incubates
local md = { infParts = { ForeArm_L = { L = 2 } } }
assert(texts(draw(0, {}, nil, md)) == "Left Forearm", "L2, level 0: can't tell")
md.infParts.ForeArm_L.L = 3
d, y = draw(0, {}, nil, md)
assert(texts(d) == "Left Forearm | - UI_DanTraits_health_RedSwollen" and d[2].y == 110 and y == 125, "L3: red and swollen, where the game's end gap was")
assert(texts(draw(3, {}, nil, md)) == "Left Forearm | - UI_DanTraits_health_Infected", "level 3: infected")
assert(texts(draw(6, {}, nil, md)) == "Left Forearm | - UI_DanTraits_health_InfectionLocal", "level 6: local")
md.infParts.ForeArm_L.L = 6
assert(texts(draw(6, {}, nil, md)) == "Left Forearm | - UI_DanTraits_health_InfectionSpreading", "level 6: spreading")
md.infParts.ForeArm_L = { inc = 300, L = 0 }
assert(texts(draw(8, {}, nil, md)) == "Left Forearm", "incubating: hidden at 8")
assert(texts(draw(9, {}, nil, md)) == "Left Forearm | - UI_DanTraits_health_MightTurn", "incubating: a hint at 9")

-- 6. dressing thin (3+), stitches (6+), the bone (bad set 3+, healing 9+)
local part = makePart({ bandaged = true, life = 0.5, stitch = 20, fracture = 30 })
md = { wcParts = { ForeArm_L = { badSet = true } } }
assert(texts(draw(2, {}, part, md)) == "Left Forearm", "level 2: none of it")
assert(texts(draw(3, {}, part, md)) == "Left Forearm | - UI_DanTraits_health_DressingThin | - UI_DanTraits_health_SetBadly", texts(draw(3, {}, part, md)))
assert(texts(draw(9, {}, part, md)) == "Left Forearm | - UI_DanTraits_health_DressingThin | - UI_DanTraits_health_StitchesHolding | - UI_DanTraits_health_SetBadly | - UI_DanTraits_health_BoneKnitting", texts(draw(9, {}, part, md)))

-- 7. the debug view is untouched
ISHealthPanel.cheat = true
d = draw(0, { "- Deep Wound Severe", "- Infected" })
assert(texts(d) == "Left Forearm | - Deep Wound Severe | - Infected", "cheat: as drawn")
ISHealthPanel.cheat = false

-- 8. the examiner's level is read live and written back to the panel (it keeps the one it was made with)
Perks = { Doctor = "doctor" }
toDraw = { "- Deep Wound Severe" }
local panel = { doctorLevel = 0, getPatient = function() return { getModData = function() return {} end } end,
  getDoctor = function() return { getPerkLevel = function(_, perk) return perk == "doctor" and 7 or 0 end } end }
local seenText = {}
local box = setmetatable({ parent = panel, drawText = function(_, s) seenText[#seenText + 1] = s end }, { __index = ISHealthBodyPartListBox })
box:doDrawItem(0, { item = { bodyPart = makePart() } })
assert(panel.doctorLevel == 7 and seenText[2] == "- Deep Wound Severe", "live level 7: the game's detail")

-- 9. wrapping twice (OnGameStart again) doesn't stack
local before = ISHealthBodyPartListBox.doDrawItem
H.fire("OnGameStart"); assert(ISHealthBodyPartListBox.doDrawItem == before, "not wrapped twice")

H.pass()
