-- Project Zomboid Vitality Project: Anaemic.
-- An iron score (0..1) drains over about five days and is topped up by what
-- the character eats: fresh meat, fish and game most, greens and eggs a
-- little, an iron pill a lot. Under AN_LOW the deficit shows: endurance
-- recovers slower (through the enduranceRegen hook of the stat delta
-- pipeline), tiredness comes sooner, colds catch easier (the catchCold
-- hook). A
-- vegetarian lives on greens, eggs and pills. The eat hook reads the
-- game's food type, so stews and dishes count by their main ingredient.
-- After blood loss (DanTraits_Blood.lua) red cells rebuild at half speed,
-- slower still short of iron, and rebuilding them spends iron. A wound
-- infection climbs faster too (the infectionGrowth hook).
require "DanTraits"

local hasTrait = DanTraits_HasTrait
local notify = DanTraits_Notify
local traitData = DanTraits_Data

local AN_START          = 0.6     -- a new character's iron
local AN_DRAIN_DAYS     = 5       -- full to empty
local AN_LOW            = 0.4     -- the deficit starts under this
local AN_MEAT           = 0.15    -- per full portion (scaled by calories up to AN_MEAT_KCAL)
local AN_MEAT_KCAL      = 300
local AN_GREENS         = 0.04
local AN_EGG            = 0.05
local AN_PILL           = 0.25
local AN_ENDURANCE_CUT  = 0.4     -- endurance recovery x (1 - this x deficit)
local AN_FATIGUE        = 0.0004  -- per minute at full deficit
local AN_COLD           = 0.5     -- cold catching x (1 + this x deficit)
local AN_TIER           = { 0.5, 0.9 }   -- Feeling faint | Light-headed
local AN_BLOOD_REBUILD  = 0.5     -- red cells rebuild x this, x (1 - deficit)
local AN_INF_GROWTH      = 0.3     -- wound infection climb x (1 + this x deficit)
local AN_BLOOD_IRON     = 2       -- iron spent per unit of red cells rebuilt (a tenth of the blood: a fifth of the iron)

local MEAT_TYPES = { "meat", "fish", "game", "poultry", "seafood", "beef", "pork", "venison", "rabbit", "chicken", "insect" }
local GREENS_TYPES = { "vegetables", "greens", "herb", "beans", "leafy" }
local EGG_TYPES = { "egg" }

local function anData(player)
    local d = traitData(player)
    if d.anIron == nil then d.anIron = AN_START end
    return d
end

local clamp01 = DanTraits_Clamp01

-- 0..1 how short of iron the character is
local function deficitOf(d)
    if not d or d.anIron == nil then return 0 end
    return clamp01((AN_LOW - d.anIron) / AN_LOW)
end
function DanTraits_IronDeficit(player)
    if not player or not hasTrait(player, "anemia") then return 0 end
    return deficitOf(player:getModData().DanTraits)
end

local function matches(name, list)
    for _, word in ipairs(list) do if string.find(name, word, 1, true) then return true end end
    return false
end

local function addIron(player, amount, what)
    if not player or amount <= 0 or not hasTrait(player, "anemia") then return false end
    local d = anData(player)
    d.anIron = clamp01(d.anIron + amount)
    d.anLastIron = what
    return true
end
DanTraits_AddIron = addIron

DanTraits_AddHook("eat", function(_, player, item, fraction)
    if not player or not item or not hasTrait(player, "anemia") then return nil end
    fraction = clamp01(fraction or 1)
    local foodType, name, kcal = "", "", 0
    pcall(function() foodType = string.lower(tostring(item:getFoodType() or "")) end)
    pcall(function() name = string.lower(tostring(item:getType() or "")) end)
    pcall(function() kcal = item:getCalories() or 0 end)
    local key = foodType .. " " .. name
    if matches(key, MEAT_TYPES) then
        addIron(player, AN_MEAT * clamp01(kcal / AN_MEAT_KCAL) * fraction, name)
    elseif matches(key, EGG_TYPES) then
        addIron(player, AN_EGG * fraction, name)
    elseif matches(key, GREENS_TYPES) then
        addIron(player, AN_GREENS * fraction, name)
    end
    return nil
end)

DanTraits_AddHook("pill", function(_, player, kind)
    if string.lower(tostring(kind or "")) == "ironpills" then addIron(player, AN_PILL, "iron pill") end
    return nil
end)

DanTraits_AddHook("bloodCellRebuild", function(rate, player, d)
    if not hasTrait(player, "anemia") then return nil end
    return rate * AN_BLOOD_REBUILD * (1 - deficitOf(d))
end)

DanTraits_AddHook("bloodCellsRebuilt", function(_, player, amount)
    if not hasTrait(player, "anemia") then return nil end
    local d = anData(player)
    d.anIron = clamp01(d.anIron - amount * AN_BLOOD_IRON)
    return nil
end)

local function updateAnemiaMinute(player, d)
    if not hasTrait(player, "anemia") then return end
    d = anData(player)
    d.anIron = clamp01(d.anIron - 1 / (AN_DRAIN_DAYS * 24 * 60))
    local deficit = deficitOf(d)
    d.anDeficit = deficit
    local tier = 0
    for i, threshold in ipairs(AN_TIER) do if deficit >= threshold then tier = i end end
    if tier ~= (d.anTier or 0) then
        if tier > (d.anTier or 0) then notify(player, "UI_DanTraits_Anemia" .. tier) end
        d.anTier = tier
    end
    if deficit <= 0 then return end
    pcall(function()
        local stats = player:getStats()
        local asleep = DanTraits_Asleep(player)
        if not asleep then stats:set(CharacterStat.FATIGUE, math.min(1, (stats:get(CharacterStat.FATIGUE) or 0) + AN_FATIGUE * deficit)) end
    end)
end
DanTraits_updateAnemiaMinute = updateAnemiaMinute

-- slower endurance recovery and easier colds go through the stat delta pipeline
-- (DanTraits_Util.lua): Anemia only says by how much, the pipeline applies it
DanTraits_AddHook("enduranceRegen", function(delta, player, d)
    if not d or d.anIron == nil or not hasTrait(player, "anemia") then return nil end
    return delta * (1 - AN_ENDURANCE_CUT * deficitOf(d))
end)
DanTraits_AddHook("catchCold", function(delta, player, d)
    if not d or d.anIron == nil or not hasTrait(player, "anemia") then return nil end
    return delta * (1 + AN_COLD * deficitOf(d))
end)

-- short of iron the body fights a wound infection slower (DanTraits_Infection.lua)
DanTraits_AddHook("infectionGrowth", function(k, player)
    local deficit = DanTraits_IronDeficit(player)
    if deficit <= 0 then return nil end
    return k * (1 + AN_INF_GROWTH * deficit)
end)

-- the pill bottle: 30 pills, its own action (see client)
function DanTraits_IsIronPills(item)
    local ok, res = pcall(function() return item:getFullType() == "DanTraits.IronPills" end)
    return ok and res == true
end

DanTraits_Every("minute", "Anemia", updateAnemiaMinute, 40)
