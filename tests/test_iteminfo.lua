-- Offline test for Dan's Vanilla Fixes' item info (client/DansVanillaFixes_ItemInfo.lua)
-- and the tooltip strip it shares with Vitality (client/DanShared_Tooltip.lua,
-- the same file in both mods): read time left, uses left, weapon numbers by
-- skill, clothing cover and comparison.
local H = dofile((arg[0]:match("^(.*)[/\\]") or ".") .. "/harness.lua")
H.events()
H.stubs()
local HERE = arg[0]:match("^(.*)[/\\]") or "."
local ROOT = HERE .. "/../DansVanillaFixes/42/media/lua/"

-- the game -----------------------------------------------------------------------

-- getText: the key and its arguments, so the tests read what went in
getText = function(k, ...)
  local args = { ... }
  if #args == 0 then return k end
  for i = 1, #args do args[i] = tostring(args[i]) end
  return k .. "|" .. table.concat(args, "|")
end
H.now = 0
local MPD = 1440
function getGameTime() return { getMinutesPerDay = function() return MPD end } end
local GOOD, BAD = { 0, 1, 0 }, { 1, 0, 0 }
local function colour(c) return { getR = function() return c[1] end, getG = function() return c[2] end, getB = function() return c[3] end } end
function getCore() return { getGoodHighlitedColor = function() return colour(GOOD) end, getBadHighlitedColor = function() return colour(BAD) end } end
function instanceof(obj, cls) return type(obj) == "table" and obj._class ~= nil and (obj._class == cls or (obj._is and obj._is[cls])) end
CharacterTrait.ILLITERATE = "base:illiterate"
ItemTag = { FLASHLIGHT = "flashlight", USES_BATTERY = "usesbattery" }
SkillBook = { Carpentry = { perk = "Woodwork" } }
WeaponCategory = { AXE = "AXE", BLUNT = "BLUNT", SPEAR = "SPEAR", LONG_BLADE = "LONG_BLADE", SMALL_BLADE = "SMALL_BLADE", SMALL_BLUNT = "SMALL_BLUNT" }
PerkFactory = { getPerk = function(perk) return { getName = function() return "perk:" .. perk end } end }
ISToolTipInv = { render = function() end }
ISContextMenu = {}
local duration = 0
ISReadABook = { new = function(_, player, item) return { getDuration = function() return duration end } end }

local function player(levels, traits)
  local p = { _levels = levels or {}, _traits = traits or {}, _read = {}, _worn = {} }
  function p:getPerkLevel(perk) return self._levels[perk] or 0 end
  function p:hasTrait(t) return self._traits[t] == true end
  function p:getAlreadyReadPages(ft) return self._read[ft] or 0 end
  function p:getWornItem(loc) return self._worn[loc] end
  return p
end

local nextId = 0
local function item(class, fields)
  nextId = nextId + 1
  local it = { _class = class, _id = nextId, _tags = {} }
  for k, v in pairs(fields or {}) do it[k] = v end
  function it:getID() return self._id end
  function it:getFullType() return self._type or "Base.Thing" end
  function it:hasTag(t) return self._tags[t] == true end
  function it:getDisplayName() return self._name or "Thing" end
  return it
end

-- the strip ships in both mods at the same path (deploy.py refuses to run
-- while the two copies differ); with both on, either copy may run first
local VIT = HERE .. "/../DanTraits/42/media/lua/"
dofile(ROOT .. "client/DanShared_Tooltip.lua")
local strip = ISToolTipInv.render
dofile(VIT .. "client/DanShared_Tooltip.lua")
assert(ISToolTipInv.render == strip, "both copies run: still one wrap of the tooltip")
dofile(ROOT .. "client/DansVanillaFixes_ItemInfo.lua")
local I, T = DVF_ItemInfo, DanShared_Tooltip
local function near(a, b, msg) assert(math.abs(a - b) < 1e-6, msg .. ": " .. tostring(a) .. " vs " .. tostring(b)) end

-- 1. read time left ---------------------------------------------------------------

local function skillBook(pages, lvl)
  local b = item("Literature", { _type = "Base.BookCarpentry1" })
  function b:getSkillTrained() return "Carpentry" end
  function b:getNumberOfPages() return pages end
  function b:getLvlSkillTrained() return lvl end
  return b
end
local p = player({ Woodwork = 0 })
local book = skillBook(220, 1)
duration = 220 * 2 * MPD * 2   -- vanilla: the whole book at 2 minutes a page, in the action's units
near(I.readMinutes(p, book), 440, "an unread skill book: the whole book")
p._read["Base.BookCarpentry1"] = 110
near(I.readMinutes(p, book), 220, "half read: half the time")
assert(I.duration(220) == "IGUI_DVF_Info_HoursMinutes|3|40" and I.duration(120) == "IGUI_DVF_Info_Hours|2"
  and I.duration(45) == "IGUI_DVF_Info_Minutes|45", "the time as hours and minutes")
assert(I.readMinutes(p, skillBook(220, 3)) == nil, "a volume above your level + 1: nothing (vanilla will not let you)")
p._read["Base.BookCarpentry1"] = 220
assert(I.readMinutes(p, book) == nil, "read through: nothing")
p._read["Base.BookCarpentry1"] = 0
p._traits[CharacterTrait.ILLITERATE] = true
assert(I.readMinutes(p, book) == nil, "illiterate: nothing")
p._traits[CharacterTrait.ILLITERATE] = nil
-- a novel the reading overhaul handles: its duration already counts only the pages left
local novel = item("Literature")
function novel:getSkillTrained() return "" end
DanTraits_Reading = { info = function(it) return it == novel and { pages = 300 } or nil end }
duration = 90 * MPD * 2
near(I.readMinutes(p, novel), 90, "a novel: the action's own time left")
local flier = item("Literature")
function flier:getSkillTrained() return "" end
assert(I.readMinutes(p, flier) == nil, "a flier or another mod's literature the overhaul skips: nothing")
-- the line, cached a second per item
H.now = 5000
local l = I.readLine(p, novel)
assert(l[1][1] == "IGUI_DVF_Info_ReadLeft|IGUI_DVF_Info_HoursMinutes|1|30", "the line: " .. l[1][1])
duration = 30 * MPD * 2
H.now = 5500
assert(I.readLine(p, novel)[1][1] == l[1][1], "cached within a second")
H.now = 6100
assert(I.readLine(p, novel)[1][1] == "IGUI_DVF_Info_ReadLeft|IGUI_DVF_Info_Minutes|30", "asked again after it")

-- 2. uses left -----------------------------------------------------------------------

local glue = item("DrainableComboItem", { _type = "Base.Glue" })
function glue:getCurrentUses() return 7 end
function glue:getMaxUses() return 20 end
assert(I.usesLines(p, glue)[1][1] == "IGUI_DVF_Info_UsesLeft|7|20", "uses left")
local bat = item("DrainableComboItem", { _type = "Base.Battery" })
function bat:getCurrentUsesFloat() return 0.637 end
assert(I.usesLines(p, bat)[1][1] == "IGUI_DVF_Info_Charge|64%", "a battery's charge")
local torch = item("DrainableComboItem", { _type = "Base.HandTorch" })
torch._tags.flashlight = true
function torch:getCurrentUsesFloat() return 0.5 end
assert(I.usesLines(p, torch)[1][1] == "IGUI_DVF_Info_Charge|50%", "a torch runs on one too")
assert(I.usesLines(p, item("Food")) == nil, "not a drainable: nothing")

-- 3. weapons -------------------------------------------------------------------------

local function weapon(cat, fields)
  local w = item("HandWeapon", fields)
  w._cat = cat
  function w:isRanged() return cat == nil end
  function w:getScriptItem() return { containsWeaponCategory = function(_, c) return c == w._cat end } end
  function w:getMinDamage() return 0.8 end
  function w:getMaxDamage() return 2 end
  function w:getCriticalChance() return 20 end
  function w:getBaseSpeed() return 1 end
  function w:getMaxRange() return 1.25 end
  function w:getPushBackMod() return 0.3 end
  function w:getEnduranceMod() return 1.5 end
  function w:getCondition() return 7 end
  function w:getConditionMax() return 10 end
  function w:getConditionLowerChance() return 10 end
  function w:getHitChance() return 40 end
  function w:getSoundRadius() return 50 end
  return w
end
local axe = weapon("AXE")
local green = player({ Axe = 0 })
local lines = I.weaponLines(green, axe)
assert(#lines == 2 and lines[1][1] == "IGUI_DVF_Info_Skill|perk:Axe|0" and lines[2][1] == "IGUI_DVF_Info_LearnMore", "level 0: the skill and a nudge")
local mid = player({ Axe = 2 })
lines = I.weaponLines(mid, axe)
assert(#lines == 3 and lines[2][1] == "IGUI_DVF_Info_Damage|0.8|2" and lines[3][1] == "IGUI_DVF_Info_Crit|26%", "level 2: damage and crit (an axe gets 3 a level from 0)")
local bat2 = weapon("BLUNT")
assert(I.weaponLines(player({ Blunt = 2 }), bat2)[3][1] == "IGUI_DVF_Info_Crit|23%", "other weapons from level 1")
local vet = player({ Axe = 4, Maintenance = 2 })
lines = I.weaponLines(vet, axe)
assert(lines[4][1] == "IGUI_DVF_Info_Speed|1|1.25" and lines[5][1] == "IGUI_DVF_Info_Knockback|0.3|1.5", "level 4: speed, reach, knockback, endurance")
assert(lines[6][1] == "IGUI_DVF_Info_Condition|7|10" and lines[7][1] == "IGUI_DVF_Info_Wear|14", "Maintenance 2: condition and wear (10 + 2 x floor((2 + 2) / 2))")
SandboxVars = { DansVanillaFixes = { ItemInfoWeaponSkill = false } }
lines = I.weaponLines(green, axe)
assert(#lines == 7, "option off: everything from the start")
SandboxVars = nil
local gun = weapon(nil)
lines = I.weaponLines(player({ Aiming = 4 }), gun)
assert(lines[1][1] == "IGUI_DVF_Info_Skill|perk:Aiming|4" and lines[3][1] == "IGUI_DVF_Info_Crit|20%"
  and lines[4][1] == "IGUI_DVF_Info_Accuracy|40%" and lines[5][1] == "IGUI_DVF_Info_RangeNoise|1.3|50", "a firearm by Aiming")
assert(I.weaponLines(p, weapon("NOPE")) == nil, "a weapon with no skill (a frying pan's none): nothing")

-- 4. clothing ------------------------------------------------------------------------

local function list(t) return { size = function() return #t end, get = function(_, i) return t[i + 1] end } end
local function part(n) return { getDisplayName = function() return n end } end
local function garment(stats, parts)
  local g = item("Clothing", { _name = stats.name })
  function g:getBodyLocation() return "Tshirt" end
  function g:getCoveredParts() return list(parts or {}) end
  function g:getInsulation() return stats.ins end
  function g:getWindresistance() return stats.wind end
  function g:getWaterResistance() return stats.water end
  function g:getRunSpeedModifier() return stats.run end
  function g:getCombatSpeedModifier() return stats.combat end
  return g
end
local parts = {}
for _, n in ipairs({ "Torso", "Back", "Upper Left Arm", "Upper Right Arm", "Left Forearm", "Right Forearm" }) do parts[#parts + 1] = part(n) end
local hoodie = garment({ name = "Hoodie", ins = 0.6, wind = 0.3, water = 0.1, run = 1, combat = 0.98 }, parts)
lines = I.clothingLines(p, hoodie)
assert(#lines == 2 and lines[1][1] == "IGUI_DVF_Info_Covers|Torso, Back, Upper Left Arm, Upper Right Arm" and lines[2][1] == "  Left Forearm, Right Forearm",
  "the parts covered, four a line")
local tee = garment({ name = "T-Shirt", ins = 0.4, wind = 0.4, water = 0.1, run = 1, combat = 1 })
p._worn.Tshirt = tee
lines = I.clothingLines(p, hoodie)
assert(lines[3][1] == "IGUI_DVF_Info_Versus|T-Shirt", "compared with what is worn there")
assert(lines[4][1] == "IGUI_DVF_Info_Insulation|+20" and lines[4][3] == 1, "warmer: green")
assert(lines[5][1] == "IGUI_DVF_Info_Wind|-10" and lines[5][2] == 1, "less wind resistance: red")
assert(lines[6][1] == "IGUI_DVF_Info_CombatSpeed|-2%" and #lines == 6, "the same water and running speed left out")
p._worn.Tshirt = hoodie
assert(#I.clothingLines(p, hoodie) == 2, "the one you wear: no comparison")
p._worn.Tshirt = nil

-- 5. the strip -----------------------------------------------------------------------

assert(I.lines(p, glue)[1][1] == "IGUI_DVF_Info_UsesLeft|7|20", "the source")
SandboxVars = { DansVanillaFixes = { ItemInfoTooltips = false } }
assert(I.lines(p, glue) == nil, "Item Info in Tooltips off: nothing")
SandboxVars = nil
T.add("later", 30, function() return { { "after", 1, 1, 1 } } end)
T.add("earlier", 20, function() return { { "before", 1, 1, 1 } } end)
lines = T.lines(p, glue)
assert(lines[1][1] == "before" and lines[2][1] == "IGUI_DVF_Info_UsesLeft|7|20" and lines[3][1] == "after", "sources in order")
T.add("earlier", 20, function() error("broken") end)
lines = T.lines(p, glue)
assert(#lines == 2, "a broken source is skipped, the rest still show")
local drawn = {}
local tip = { item = glue, width = 100, height = 50, tooltip = { getCharacter = function() return p end },
  backgroundColor = { r = 0, g = 0, b = 0, a = 1 }, borderColor = { r = 1, g = 1, b = 1, a = 1 },
  drawRect = function() end, drawRectBorder = function() end, drawText = function(_, t, x, y) drawn[#drawn + 1] = { t, y } end }
function getTextManager() return { MeasureStringX = function(_, _, s) return #s * 6 end, getFontHeight = function() return 12 end } end
UIFont = { Small = "small" }
ISToolTipInv.render(tip)
assert(#drawn == 2 and drawn[1][2] > 50 and drawn[2][2] > drawn[1][2], "one strip under the tooltip, a line each")

H.pass("test_iteminfo")
