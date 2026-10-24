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

-- 10. another mod wraps after this one, then a second world re-wraps on OnGameStart: the inner
--     layer finds itself inside the outer's call and passes through, so the mod's lines show once
do
  local other = ISHealthBodyPartListBox.doDrawItem
  ISHealthBodyPartListBox.doDrawItem = function(self, ...) return other(self, ...) end
  H.fire("OnGameStart")
  assert(ISHealthBodyPartListBox.doDrawItem ~= other, "re-wrapped over the other mod's layer")
  local d = draw(10, {}, makePart({ fracture = 60 }))
  local bone = 0
  for _, l in ipairs(d) do if l.s:find("BoneEarly", 1, true) then bone = bone + 1 end end
  assert(bone == 1, "the bone line is drawn once, not per layer: " .. texts(d))
  assert(#d == 2, "the part's name and the one line: " .. texts(d))
end

-- 11. daily medication: a header and a line per scheduled drug at the top of the list's
--     place, the list moved down and the panel grown to fit; your own character only
do
  H.load("Meds")
  local plainText = getText
  getText = function(k, a) if a ~= nil then return k .. ":" .. a end return plainText(k) end
  local NAMES = { ["Base.PillsBeta"] = "Beta Blockers", ["DanTraits.Anticonvulsants"] = "Anticonvulsants" }
  function getItemNameFromFullType(ft) return NAMES[ft] end
  function getCore() return { getScreenHeight = function() return 1000 end } end
  UI_BORDER_SPACING = 5
  function getTextManager() return { getFontHeight = function() return 10 end, MeasureStringX = function(_, _, str) return #str * 5 end } end
  ISHealthPanel.render = function(self) self.listbox._y = 50; self.allTextHeight = 300 end
  H.fire("OnGameStart")
  assert(ISHealthPanel.render == ISHealthPanel.DanTraitsRender, "render wrapped")

  local me = H.player({ traits = { "heart", "epilepsy" } }); H.current = me
  me.isLocalPlayer = function() return true end
  local function panelFor(who)
    local drawn = {}
    local listbox = { _y = 0, _h = 0, textRight = 0 }
    function listbox:getX() return 200 end
    function listbox:getY() return self._y end
    function listbox:setY(v) self._y = v end
    function listbox:getHeight() return self._h end
    function listbox:setHeight(v) self._h = v end
    local panel = setmetatable({ listbox = listbox }, { __index = ISHealthPanel })
    function panel:getPatient() return who end
    function panel:getAbsoluteY() return 0 end
    function panel:drawText(str, x, y, r, g, b) drawn[#drawn + 1] = { s = str, x = x, y = y, r = r, g = g } end
    return panel, drawn
  end

  DanTraits_MedTake(me, "beta", 1)
  H.hours = H.hours + 5
  local panel, drawn = panelFor(me)
  panel:render()
  assert(texts(drawn) == "UI_DanTraits_health_MedHeader | Anticonvulsants: UI_DanTraits_health_MedNever | Beta Blockers: UI_DanTraits_health_MedHours:5, UI_DanTraits_health_MedNextIn:17", texts(drawn))
  assert(drawn[1].x == 200 and drawn[1].y == 50 and drawn[3].y == 70, "at the list's place, a line apart")
  assert(drawn[2].r == 0.7 and drawn[3].g == 0.89, "not taken grey, covered green")
  assert(panel.listbox._y == 84 and panel.allTextHeight == 334 and panel.listbox._h == 250, "list down 34, panel grown 34: " .. panel.listbox._y .. " " .. panel.allTextHeight .. " " .. panel.listbox._h)
  assert(panel.listbox.textRight > 0, "wide enough for the lines")

  -- due, then worn off
  H.hours = H.hours + 18
  panel, drawn = panelFor(me); panel:render()
  assert(drawn[3].s == "Beta Blockers: UI_DanTraits_health_MedHours:23, UI_DanTraits_health_MedDueNow" and drawn[3].r == 1, drawn[3].s)
  DanTraits_Data(me).meds.beta.lvl, DanTraits_Data(me).meds.beta.built = 0.2, 0.5   -- worn off with some effect left to lose
  panel, drawn = panelFor(me); panel:render()
  assert(drawn[3].s == "Beta Blockers: UI_DanTraits_health_MedHours:23, UI_DanTraits_health_MedWornOff" and drawn[3].r == 0.89, drawn[3].s)
  H.hours = H.hours + 48
  panel, drawn = panelFor(me); panel:render()
  assert(drawn[3].s == "Beta Blockers: UI_DanTraits_health_MedDays:2, UI_DanTraits_health_MedWornOff", drawn[3].s)

  -- someone else's panel, a character with no daily drugs, the debug view: nothing added
  local other = H.player({ traits = { "heart" } }); other.isLocalPlayer = function() return false end
  panel, drawn = panelFor(other); panel:render()
  assert(#drawn == 0 and panel.listbox._y == 50, "a patient: nothing")
  local well = H.player(); well.isLocalPlayer = function() return true end
  panel, drawn = panelFor(well); panel:render()
  assert(#drawn == 0 and panel.listbox._y == 50, "no daily drugs: nothing")
  ISHealthPanel.cheat = true
  panel, drawn = panelFor(me); panel:render()
  assert(#drawn == 0, "debug view: left alone")
  ISHealthPanel.cheat = false

  -- another mod's render wrapped over ours, then re-wrapped: the lines once
  local ours = ISHealthPanel.render
  ISHealthPanel.render = function(self) return ours(self) end
  H.fire("OnGameStart")
  panel, drawn = panelFor(me); panel:render()
  assert(#drawn == 3 and panel.listbox._y == 84, "drawn once through two layers: " .. texts(drawn))

  -- 12. blood: a section above the medication, told by the examiner's First Aid level
  getText = function(k, a, b)
    if b ~= nil then return k .. ":" .. a .. ":" .. b end
    if a ~= nil then return k .. ":" .. a end
    return plainText(k)
  end
  local state = nil
  function DanTraits_BloodState() return state end
  local function blood(level, s)
    state = { vol = 1, cells = 1, loss = 0, volGain = 0, cellGain = 0, tier = 0, weak = 0, shock = 0.40, death = 0.50 }
    for k, v in pairs(s or {}) do state[k] = v end
    local lines = DanTraits_HealthBloodLines(me, level)
    local out = {}
    for _, l in ipairs(lines) do out[#out + 1] = l[1] end
    return table.concat(out, " | "), lines
  end
  local P = "UI_DanTraits_health_"
  -- full and well
  assert(blood(0) == P .. "BloodFeelFine", blood(0))
  assert(blood(4) == P .. "BloodLossNone", blood(4))
  assert(blood(7) == P .. "BloodVolAbout:100", blood(7))
  assert(blood(10) == P .. "BloodVol:100", blood(10))
  -- a steady bleed into tier 1 (25% lost), drinking a little, short of red cells
  local bleed = { vol = 0.75, cells = 0.72, loss = 0.002, volGain = 0.0002, cellGain = 0.00003, tier = 1, weak = 0.4 }
  local s, lines = blood(1, bleed)
  assert(s == P .. "BloodFeel1 | " .. P .. "BloodStillBleeding", s)
  assert(lines[1][2][1] == 1 and lines[2][2][1] == 1, "pale: orange; a steady bleed: orange")
  s = blood(3, bleed)
  assert(s == P .. "BloodLoss1 | " .. P .. "BleedSteady | " .. P .. "BloodCellsLow", s)
  s = blood(6, bleed)
  assert(s == P .. "BloodVolAbout:75 | " .. P .. "BloodLosingAbout:11 | " .. P .. "BloodCellsAbout:70", s)
  -- 10.8% net an hour; shock at 60% volume, 15 points off: 83 minutes; cells not rebuilding while it bleeds
  s = blood(9, bleed)
  assert(s == P .. "BloodVol:75 | " .. P .. "BloodLosingShock:10.8:" .. P .. "BloodHour | " .. P .. "BloodCells:72", s)
  -- in shock and still losing: the heart gives out, red
  s, lines = blood(10, { vol = 0.58, loss = 0.005, tier = 3 })
  assert(s == P .. "BloodVol:58 | " .. P .. "BloodLosingDeath:30.0:" .. P .. "BloodUnderHour", s)
  assert(lines[2][2][1] == 0.89, "red")
  assert(blood(0, { vol = 0.58, loss = 0.005, tier = 3 }) == P .. "BloodFeel3 | " .. P .. "BloodStillBleeding", "a layperson: in shock")
  -- under a dressing, drinking keeps up
  assert(blood(8, { vol = 0.9, loss = 0.0001, volGain = 0.0002 }) == P .. "BloodVolAbout:90 | " .. P .. "BloodHolding", "holding")
  assert(blood(4, { vol = 0.9, loss = 0.0001, volGain = 0.0002 }) == P .. "BloodLossSlight | " .. P .. "BleedSlow", "slow")
  -- stopped: coming back, or not without water
  local back = { vol = 0.9, volGain = 0.35 / 1440 }
  assert(blood(4, back) == P .. "BloodLossSlight | " .. P .. "BloodRefilling", blood(4, back))
  assert(blood(6, back) == P .. "BloodVolAbout:90 | " .. P .. "BloodRefillAbout:1", blood(6, back))
  assert(blood(9, back) == P .. "BloodVol:90 | " .. P .. "BloodRefillFull:" .. P .. "BloodHours:7", blood(9, back))
  assert(blood(5, { vol = 0.9 }) == P .. "BloodLossSlight | " .. P .. "BloodNoRefill", "thirsty: not refilling")
  -- after: volume back, red cells rebuilding (2% short at 5% a day: about 10 hours)
  local after = { cells = 0.98, cellGain = 0.05 / 1440 }
  assert(blood(1, after) == P .. "BloodFeelFine", "a layperson: fine (not weak yet at 98%)")
  assert(blood(10, after) == P .. "BloodVol:100 | " .. P .. "BloodCellsBack:98:" .. P .. "BloodHours:10", blood(10, after))
  assert(blood(1, { cells = 0.8, weak = 0.25 }) == P .. "BloodFeelWeak", "a layperson: worn down")
  -- on the panel: the blood section first, then the medication, the list down past both
  state = { vol = 0.75, cells = 1, loss = 0, volGain = 0.0002, cellGain = 0, tier = 1, weak = 0, shock = 0.40, death = 0.50 }
  DanTraits_BloodState = function() return state end
  panel, drawn = panelFor(me); panel.doctorLevel = 3; panel:render()
  assert(texts(drawn):find(P .. "BloodHeader | " .. P .. "BloodLoss1 | " .. P .. "BloodRefilling | " .. P .. "MedHeader", 1, true) == 1, texts(drawn))
  assert(drawn[4].y == 84 and panel.listbox._y == 118, "a gap under each section: " .. drawn[4].y .. " " .. panel.listbox._y)
  -- the examiner's level read live, over the panel's
  panel, drawn = panelFor(me); panel.doctorLevel = 0
  panel.getDoctor = function() return { getPerkLevel = function() return 9 end } end
  panel:render()
  assert(drawn[2].s == P .. "BloodVol:75", "live level 9: " .. drawn[2].s)
  -- a patient: still nothing; blood off: only the medication
  panel, drawn = panelFor(other); panel:render(); assert(#drawn == 0, "a patient, no answer from their client yet: nothing")
  -- another player in multiplayer: their client's answer (DanTraits_BloodRelay.lua), at the doctor's level; no medication
  local asked = nil
  function DanTraits_PatientBloodState(doc, pat) asked = { doc, pat } return state end
  local medic = { getPerkLevel = function() return 6 end }
  panel, drawn = panelFor(other); panel.getDoctor = function() return medic end; panel:render()
  assert(texts(drawn) == P .. "BloodHeader | " .. P .. "BloodVolAbout:75 | " .. P .. "BloodRefillAbout:1", texts(drawn))
  assert(asked[1] == medic and asked[2] == other, "asked by the doctor about the patient")
  DanTraits_PatientBloodState = nil
  state = nil
  panel, drawn = panelFor(me); panel:render(); assert(drawn[1].s == P .. "MedHeader", "blood off: medication only")
  DanTraits_BloodState = nil
  getText = plainText
end

H.pass()
